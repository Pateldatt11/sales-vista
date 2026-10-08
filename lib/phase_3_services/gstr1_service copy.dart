import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:universal_html/html.dart' as html;

class Gstr1Service {
  static const String _stateHeatmapSvgAsset = 'assets/maps/india_state_heatmap_tagged.svg';
  static const String _gstReferenceSvgAsset = 'assets/maps/india_gst_state_code_map_vectorized.svg';
  static final DateFormat _date = DateFormat('yyyy-MM-dd');
  static final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  /// Exports a GSTR-1 working register for accountant review.
  ///
  /// Supported formats:
  /// - csv: plain GST line-item data + HSN summary + totals.
  /// - xlsx: readable workbook with auto-width sheets and chart data.
  /// - pdf: printable summary with GST sections, tax split and HSN summary.
  ///
  /// Note: this is an audit/working register. Direct GST portal filing still
  /// requires review and, where needed, the official GST portal/offline-tool JSON schema.
  static Future<String> exportMonthlyGstr1({
    required int month,
    required int year,
    required String companyStateCode,
    String format = 'csv',
  }) async {
    final data = _buildData(
      month: month,
      year: year,
      companyStateCode: companyStateCode,
    );

    final safeMonth = month.toString().padLeft(2, '0');
    final baseName = 'GSTR1_${year}_$safeMonth';

    switch (format.toLowerCase()) {
      case 'xlsx':
        return _exportXlsx(data, '$baseName.xlsx');
      case 'pdf':
        return _exportPdf(data, '$baseName.pdf');
      case 'csv':
      default:
        return _exportCsv(data, '$baseName.csv');
    }
  }

  static _Gstr1ExportData _buildData({
    required int month,
    required int year,
    required String companyStateCode,
  }) {
    final invoiceBox = Hive.box<InvoiceModel>('invoice_box');
    final invoices = invoiceBox.values
        .where((invoice) => invoice.date.month == month && invoice.date.year == year)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final returns = _loadReturnRecords(month: month, year: year);

    for (final invoice in invoices) {
      invoice.calculateTax(companyStateCode);
    }

    final invoiceRows = <List<Object?>>[];
    final hsnMap = <String, _HsnSummary>{};
    final sectionMap = <String, _SectionSummary>{};

    for (final invoice in invoices) {
      final isInterState = invoice.igst > 0;
      final section = _sectionFor(invoice);
      sectionMap.putIfAbsent(section, () => _SectionSummary());
      sectionMap[section]!.invoiceIds.add(invoice.id);
      sectionMap[section]!.invoiceValue += invoice.grandTotal;

      for (final item in invoice.items) {
        final taxAmount = invoice.isGstEnabled ? item.gstAmount : 0.0;
        final igst = isInterState ? taxAmount : 0.0;
        final cgst = isInterState ? 0.0 : taxAmount / 2;
        final sgst = isInterState ? 0.0 : taxAmount / 2;
        final taxable = item.taxableValue;
        final lineTotal = taxable + taxAmount;
        final hsn = item.hsn.trim().isEmpty ? 'NA' : item.hsn.trim();

        invoiceRows.add([
          section,
          invoice.buyerGstin ?? '',
          invoice.id,
          _date.format(invoice.date),
          invoice.grandTotal,
          invoice.placeOfSupply ?? companyStateCode,
          invoice.customerName,
          item.productName,
          hsn,
          item.quantity,
          item.unitPrice,
          taxable,
          item.gstPercent,
          igst,
          cgst,
          sgst,
          lineTotal,
        ]);

        hsnMap.putIfAbsent(hsn, () => _HsnSummary(hsn));
        hsnMap[hsn]!.addItem(item, igst: igst, cgst: cgst, sgst: sgst);

        sectionMap[section]!.taxableValue += taxable;
        sectionMap[section]!.igst += igst;
        sectionMap[section]!.cgst += cgst;
        sectionMap[section]!.sgst += sgst;
      }
    }

    final hsnRows = hsnMap.values.toList()
      ..sort((a, b) => a.hsn.compareTo(b.hsn));
    final sectionRows = sectionMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalTaxable = invoiceRows.fold<double>(0, (sum, row) => sum + _asDouble(row[11]));
    final totalIgst = invoiceRows.fold<double>(0, (sum, row) => sum + _asDouble(row[13]));
    final totalCgst = invoiceRows.fold<double>(0, (sum, row) => sum + _asDouble(row[14]));
    final totalSgst = invoiceRows.fold<double>(0, (sum, row) => sum + _asDouble(row[15]));
    final totalInvoiceValue = invoices.fold<double>(0, (sum, invoice) => sum + invoice.grandTotal);

    final summaryRows = <List<Object?>>[
      ['Period', '${year}-${month.toString().padLeft(2, '0')}'],
      ['Company State Code', companyStateCode],
      ['Total Invoices', invoices.length],
      ['Invoice Line Items', invoiceRows.length],
      ['B2B Invoices', invoices.where((invoice) => invoice.invoiceType == 'B2B').length],
      ['B2C Invoices', invoices.where((invoice) => invoice.invoiceType == 'B2C').length],
      ['Taxable Value', totalTaxable],
      ['IGST', totalIgst],
      ['CGST', totalCgst],
      ['SGST', totalSgst],
      ['Total GST', totalIgst + totalCgst + totalSgst],
      ['Invoice Value', totalInvoiceValue],
    ];

    return _Gstr1ExportData(
      month: month,
      year: year,
      companyStateCode: companyStateCode,
      invoices: invoices,
      returns: returns,
      invoiceRows: invoiceRows,
      hsnSummaries: hsnRows,
      sectionSummaries: sectionRows,
      summaryRows: summaryRows,
    );
  }

  static String _sectionFor(InvoiceModel invoice) {
    if (invoice.invoiceType == 'B2B') return 'B2B';
    final isLargeB2C = invoice.grandTotal > 100000 && invoice.igst > 0;
    return isLargeB2C ? 'B2CL' : 'B2CS';
  }


  static List<ReturnOrderRecord> _loadReturnRecords({
    required int month,
    required int year,
  }) {
    try {
      return PosRepository()
          .returnRecords()
          .where((record) => record.date.month == month && record.date.year == year)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      // Return records are optional for GSTR-1. If the box is not opened during
      // early startup or tests, keep export working and show zero credit notes.
      return <ReturnOrderRecord>[];
    }
  }

  static String _safeBoxValue(String boxName, String key, String fallback) {
    try {
      if (!Hive.isBoxOpen(boxName)) return fallback;
      final value = Hive.box(boxName).get(key, defaultValue: fallback);
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    } catch (_) {
      return fallback;
    }
  }

  static List<_Gstr1GovernmentTable> _buildGstr1GovernmentTables(_Gstr1ExportData data) {
    final companyName = _safeBoxValue('companyBox', 'companyName', 'SalesVista');
    final companyGstin = _safeBoxValue('companyBox', 'companyGst', 'Not configured');
    final turnover = data.totalInvoiceValue;
    final b2bRows = _buildB2bGovernmentRows(data);
    final b2clRows = _buildB2clGovernmentRows(data);
    final b2csRows = _buildB2csGovernmentRows(data);
    final creditDebitRows = _buildCreditDebitNoteRows(data);
    final hsnRows = _buildGovernmentHsnRows(data);
    final documentRows = _buildGovernmentDocumentRows(data);

    return <_Gstr1GovernmentTable>[
      _Gstr1GovernmentTable(
        code: 'Table 1',
        title: 'GSTIN of the supplier',
        note: 'Company GSTIN is read from companyBox.companyGst when available.',
        headers: const ['Field', 'Value'],
        rows: <List<Object?>>[
          <Object?>['GSTIN', companyGstin],
          <Object?>['Return period', data.periodLabel],
          <Object?>['Supplier state code', data.companyStateCode],
        ],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 2',
        title: 'Legal name and trade name',
        note: 'Company name is read from companyBox.companyName when available.',
        headers: const ['Field', 'Value'],
        rows: <List<Object?>>[
          <Object?>['Legal name', companyName],
          <Object?>['Trade name', companyName],
        ],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 3',
        title: 'Aggregate turnover',
        note: 'App data can calculate selected-period turnover. Previous-FY statutory turnover should be verified with the accountant before filing.',
        headers: const ['Field', 'Value'],
        rows: <List<Object?>>[
          <Object?>['Selected period outward supply value', turnover],
          <Object?>['Previous financial year aggregate turnover', 'Manual review required'],
          <Object?>['Current financial year turnover up to selected period', 'Manual review required'],
        ],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 4',
        title: 'Taxable outward supplies to registered persons including reverse charge, SEZ and deemed exports',
        note: 'SalesVista currently maps registered customer GSTIN invoices to regular B2B. Reverse charge, SEZ and deemed-export flags are kept as review columns.',
        headers: const ['GSTIN/UIN', 'Receiver Name', 'Invoice No', 'Invoice Date', 'Invoice Value', 'POS', 'Reverse Charge', 'Supply Type', 'GST Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess'],
        rows: b2bRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 5',
        title: 'Taxable outward inter-state supplies to unregistered persons above Rs. 1 lakh',
        note: 'For current periods, inter-state B2C invoices above Rs. 1 lakh are treated as B2CL.',
        headers: const ['POS', 'Invoice No', 'Invoice Date', 'Invoice Value', 'GST Rate', 'Taxable Value', 'IGST', 'Cess', 'E-Commerce GSTIN'],
        rows: b2clRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 6',
        title: 'Zero-rated supplies and deemed exports',
        note: 'Export, SEZ and deemed-export fields are not captured in the current POS invoice model. Keep this table for manual review when needed.',
        headers: const ['Supply Type', 'Invoice No', 'Invoice Date', 'Invoice Value', 'Port Code', 'Shipping Bill No', 'Shipping Bill Date', 'GST Rate', 'Taxable Value', 'IGST', 'Cess'],
        rows: const <List<Object?>>[],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 7',
        title: 'Taxable supplies to unregistered persons other than Table 5',
        note: 'B2C-small is grouped by supply type, place of supply and GST rate.',
        headers: const ['Type', 'Supply Type', 'POS', 'GST Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess', 'E-Commerce GSTIN'],
        rows: b2csRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 8',
        title: 'Nil rated, exempted and non-GST outward supplies',
        note: 'The current invoice model does not separately classify nil/exempt/non-GST supplies. Zero GST rows should be reviewed manually.',
        headers: const ['Description', 'Nil Rated', 'Exempted', 'Non-GST'],
        rows: <List<Object?>>[
          <Object?>['Inter-State supplies to registered persons', 0, 0, 0],
          <Object?>['Intra-State supplies to registered persons', 0, 0, 0],
          <Object?>['Inter-State supplies to unregistered persons', 0, 0, 0],
          <Object?>['Intra-State supplies to unregistered persons', 0, 0, 0],
        ],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 9',
        title: 'Amendments and credit/debit notes',
        note: 'Return orders are exported as credit-note working rows. Amendment rows need original GST portal return-period references before filing.',
        headers: const ['Recipient Type', 'GSTIN/UIN', 'Document Type', 'Document No', 'Document Date', 'Original Invoice No', 'Original Invoice Date', 'Document Value', 'POS', 'GST Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess', 'Reason'],
        rows: creditDebitRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 10',
        title: 'Amended B2C other supplies',
        note: 'No separate amendment workflow is stored in the current POS model. Use this table as a review placeholder.',
        headers: const ['Original Period', 'Original POS', 'Revised POS', 'GST Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess'],
        rows: const <List<Object?>>[],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 11',
        title: 'Tax liability on advances received and adjustment of advances',
        note: 'The POS invoice flow records completed invoices. Advance receipt/adjustment accounting is not separately captured yet.',
        headers: const ['Part', 'POS', 'GST Rate', 'Gross Advance/Adjusted Amount', 'Cess'],
        rows: const <List<Object?>>[],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 12',
        title: 'HSN-wise summary of outward supplies',
        note: 'From May 2025 the portal shows Table 12 as B2B and B2C tabs; this export includes the supply category column.',
        headers: const ['Supply Category', 'HSN', 'Description', 'UQC', 'Total Quantity', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess', 'Total Value'],
        rows: hsnRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 13',
        title: 'Documents issued during the tax period',
        note: 'Invoice and return/credit-note counts are generated from SalesVista records. Cancelled/void documents must be reviewed if used outside this app.',
        headers: const ['Nature of Document', 'From', 'To', 'Total Number', 'Cancelled', 'Net Issued'],
        rows: documentRows,
      ),
      _Gstr1GovernmentTable(
        code: 'Table 14',
        title: 'Supplies made through e-commerce operators',
        note: 'E-commerce operator GSTIN and Section 52/9(5) liability fields are not stored in the current POS invoice model.',
        headers: const ['Part', 'E-Commerce GSTIN', 'Gross Supplies', 'Supplies Returned', 'Net Supplies', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess'],
        rows: const <List<Object?>>[],
      ),
      _Gstr1GovernmentTable(
        code: 'Table 15',
        title: 'Supplies u/s 9(5) reported by e-commerce operator',
        note: 'Used only when the taxpayer is an ECO liable to pay tax u/s 9(5). No such source data exists in the current POS model.',
        headers: const ['Section', 'Supplier GSTIN', 'Recipient GSTIN/POS', 'Document No', 'Document Date', 'GST Rate', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Cess'],
        rows: const <List<Object?>>[],
      ),
    ];
  }

  static List<List<Object?>> _buildB2bGovernmentRows(_Gstr1ExportData data) {
    return data.invoiceRows
        .where((row) => row.isNotEmpty && row[0] == 'B2B')
        .map<List<Object?>>((row) => <Object?>[
              row[1],
              row[6],
              row[2],
              row[3],
              row[4],
              row[5],
              'N',
              'Regular B2B',
              row[12],
              row[11],
              row[13],
              row[14],
              row[15],
              0,
            ])
        .toList();
  }

  static List<List<Object?>> _buildB2clGovernmentRows(_Gstr1ExportData data) {
    return data.invoiceRows
        .where((row) => row.isNotEmpty && row[0] == 'B2CL')
        .map<List<Object?>>((row) => <Object?>[
              row[5],
              row[2],
              row[3],
              row[4],
              row[12],
              row[11],
              row[13],
              0,
              '',
            ])
        .toList();
  }

  static List<List<Object?>> _buildB2csGovernmentRows(_Gstr1ExportData data) {
    final aggregates = <String, _GovernmentTaxBucket>{};
    for (final row in data.invoiceRows.where((row) => row.isNotEmpty && row[0] == 'B2CS')) {
      final pos = _normalizeStateCode(row[5]?.toString() ?? data.companyStateCode);
      final rate = _asDouble(row[12]);
      final supplyType = pos == data.companyStateCode ? 'Intra-State' : 'Inter-State';
      final key = '$supplyType|$pos|$rate';
      final bucket = aggregates.putIfAbsent(key, () => _GovernmentTaxBucket(pos: pos, rate: rate, supplyType: supplyType));
      bucket.taxable += _asDouble(row[11]);
      bucket.igst += _asDouble(row[13]);
      bucket.cgst += _asDouble(row[14]);
      bucket.sgst += _asDouble(row[15]);
    }

    final buckets = aggregates.values.toList()
      ..sort((a, b) {
        final byPos = a.pos.compareTo(b.pos);
        if (byPos != 0) return byPos;
        return a.rate.compareTo(b.rate);
      });

    return buckets
        .map<List<Object?>>((bucket) => <Object?>[
              'OE',
              bucket.supplyType,
              bucket.pos,
              bucket.rate,
              bucket.taxable,
              bucket.igst,
              bucket.cgst,
              bucket.sgst,
              0,
              '',
            ])
        .toList();
  }

  static List<List<Object?>> _buildCreditDebitNoteRows(_Gstr1ExportData data) {
    final invoicesById = <String, InvoiceModel>{for (final invoice in data.invoices) invoice.id: invoice};
    final rows = <List<Object?>>[];

    for (final record in data.returns) {
      final invoice = invoicesById[record.invoiceId];
      final gstin = invoice?.buyerGstin?.trim() ?? '';
      final pos = _normalizeStateCode(invoice?.placeOfSupply ?? data.companyStateCode);
      final isInterState = pos != data.companyStateCode;
      final taxAmount = record.gstAmount;
      final igst = isInterState ? taxAmount : 0.0;
      final cgst = isInterState ? 0.0 : taxAmount / 2;
      final sgst = isInterState ? 0.0 : taxAmount / 2;

      rows.add(<Object?>[
        gstin.isEmpty ? 'Unregistered' : 'Registered',
        gstin,
        'Credit Note',
        record.id,
        _date.format(record.date),
        record.invoiceId,
        record.originalDate == null ? '' : _date.format(record.originalDate!),
        record.returnAmount,
        pos,
        record.gstPercent,
        record.taxableValue,
        igst,
        cgst,
        sgst,
        0,
        record.reason,
      ]);
    }

    return rows;
  }

  static List<List<Object?>> _buildGovernmentHsnRows(_Gstr1ExportData data) {
    final buckets = <String, _GovernmentHsnBucket>{};

    for (final invoice in data.invoices) {
      final category = invoice.invoiceType == 'B2B' ? 'B2B' : 'B2C';
      final isInterState = invoice.igst > 0;
      for (final item in invoice.items) {
        final hsn = item.hsn.trim().isEmpty ? 'NA' : item.hsn.trim();
        final key = '$category|$hsn|${item.gstPercent}';
        final bucket = buckets.putIfAbsent(
          key,
          () => _GovernmentHsnBucket(category: category, hsn: hsn, rate: item.gstPercent),
        );
        final taxable = item.taxableValue;
        final tax = invoice.isGstEnabled ? item.gstAmount : 0.0;
        bucket.descriptions.add(item.productName);
        bucket.quantity += item.quantity;
        bucket.taxable += taxable;
        bucket.igst += isInterState ? tax : 0.0;
        bucket.cgst += isInterState ? 0.0 : tax / 2;
        bucket.sgst += isInterState ? 0.0 : tax / 2;
      }
    }

    final sorted = buckets.values.toList()
      ..sort((a, b) {
        final byCategory = a.category.compareTo(b.category);
        if (byCategory != 0) return byCategory;
        return a.hsn.compareTo(b.hsn);
      });

    return sorted
        .map<List<Object?>>((bucket) => <Object?>[
              bucket.category,
              bucket.hsn,
              bucket.descriptions.take(4).join(' | '),
              'NOS',
              bucket.quantity,
              bucket.taxable,
              bucket.igst,
              bucket.cgst,
              bucket.sgst,
              0,
              bucket.taxable + bucket.igst + bucket.cgst + bucket.sgst,
            ])
        .toList();
  }

  static List<List<Object?>> _buildGovernmentDocumentRows(_Gstr1ExportData data) {
    final rows = <List<Object?>>[];
    final invoices = data.invoices.map((invoice) => invoice.id).where((id) => id.trim().isNotEmpty).toList()..sort();
    final returns = data.returns.map((record) => record.id).where((id) => id.trim().isNotEmpty).toList()..sort();

    rows.add(<Object?>[
      'Invoices for outward supply',
      invoices.isEmpty ? '' : invoices.first,
      invoices.isEmpty ? '' : invoices.last,
      invoices.length,
      0,
      invoices.length,
    ]);

    rows.add(<Object?>[
      'Credit notes',
      returns.isEmpty ? '' : returns.first,
      returns.isEmpty ? '' : returns.last,
      returns.length,
      0,
      returns.length,
    ]);

    return rows;
  }

  static List<List<Object?>> _buildGovernmentTableCsvRows(_Gstr1ExportData data) {
    final rows = <List<Object?>>[];
    for (final table in _buildGstr1GovernmentTables(data)) {
      rows.add(<Object?>[table.code, table.title]);
      rows.add(<Object?>['Note', table.note]);
      rows.add(List<Object?>.from(table.headers, growable: true));
      if (table.rows.isEmpty) {
        rows.add(_emptyGovernmentRow(table.headers.length));
      } else {
        rows.addAll(table.rows.map((row) => List<Object?>.from(row, growable: true)));
      }
      rows.addAll(_csvGapRows(3));
    }
    return rows;
  }

  static List<List<Object?>> _buildGovernmentTableSummaryRows(_Gstr1ExportData data) {
    return _buildGstr1GovernmentTables(data).map<List<Object?>>((table) {
      final numericIndex = _numericColumnIndex(table.headers, const ['Taxable Value', 'Gross Supplies', 'Net Supplies']);
      final igstIndex = table.headers.indexOf('IGST');
      final cgstIndex = table.headers.indexOf('CGST');
      final sgstIndex = table.headers.indexOf('SGST');
      final tax = table.rows.fold<double>(0, (sum, row) {
        return sum + _valueAt(row, igstIndex) + _valueAt(row, cgstIndex) + _valueAt(row, sgstIndex);
      });
      final taxable = numericIndex < 0 ? 0.0 : table.rows.fold<double>(0, (sum, row) => sum + _valueAt(row, numericIndex));
      return <Object?>[
        table.code,
        table.title,
        table.rows.length,
        taxable,
        tax,
        table.rows.isEmpty ? 'No app data / manual review' : 'Ready for review',
      ];
    }).toList();
  }

  static List<pw.Widget> _buildGovernmentPdfDetailWidgets(_Gstr1ExportData data, pw.Font font) {
    final widgets = <pw.Widget>[];
    for (final table in _buildGstr1GovernmentTables(data)) {
      final detailRows = table.rows.isEmpty ? <List<Object?>>[_emptyGovernmentRow(table.headers.length)] : table.rows.take(18).toList();
      widgets.add(pw.Text('${table.code} - ${table.title}', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)));
      widgets.add(pw.SizedBox(height: 2));
      widgets.add(pw.Text(table.note, style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(_pdfTable(headers: table.headers, rows: detailRows, font: font));
      if (table.rows.length > detailRows.length) {
        widgets.add(pw.Text('Showing first ${detailRows.length} rows of ${table.rows.length}. Full rows are available in CSV/XLSX exports.', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)));
      }
      widgets.add(pw.SizedBox(height: 8));
    }
    return widgets;
  }

  static int _numericColumnIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(candidate);
      if (index >= 0) return index;
    }
    return -1;
  }

  static double _valueAt(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return 0.0;
    return _asDouble(row[index]);
  }

  static List<Object?> _emptyGovernmentRow(int length) {
    if (length <= 0) return <Object?>['No records'];
    return <Object?>['No records / manual review required', ...List<Object?>.filled(length - 1, '')];
  }

  static Future<String> _exportCsv(_Gstr1ExportData data, String fileName) async {
    final rows = _buildVerticalGstr1CsvRows(data);

    // Keep CSV in the same vertical working-register layout as the accountant
    // reference file: Summary, Section Summary, Invoice Lines, HSN Summary,
    // and State Service Coverage in one CSV. UTF-8 BOM + CRLF keeps it clean
    // when opened directly in Microsoft Excel on Windows.
    final csvBody = const ListToCsvConverter().convert(rows);
    final excelCsv = '\uFEFF${csvBody.replaceAll(RegExp(r'\r?\n'), '\r\n')}';

    return _saveBytes(
      utf8.encode(excelCsv),
      fileName,
      'text/csv;charset=utf-8',
    );
  }

  static List<List<Object?>> _buildVerticalGstr1CsvRows(_Gstr1ExportData data) {
    return <List<Object?>>[
      <Object?>['GSTR-1 Working Register'],
      <Object?>['Period', data.periodLabel],
      <Object?>['Company State Code', data.companyStateCode],
      ..._csvGapRows(3),
      <Object?>['Summary'],
      <Object?>['Metric', 'Value'],
      ...data.summaryRows.map((row) => List<Object?>.from(row, growable: true)),
      ..._csvGapRows(3),
      <Object?>['GSTR-1 Government 15 Tables'],
      ..._buildGovernmentTableCsvRows(data),
      ..._csvGapRows(3),
      <Object?>['Section Summary'],
      <Object?>['Section', 'Invoice Count', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Total GST', 'Invoice Value'],
      ...data.sectionSummaries.map((entry) => entry.value.toRow(entry.key)),
      ..._csvGapRows(3),
      <Object?>['Invoice Line Items'],
      List<Object?>.from(_invoiceHeaders, growable: true),
      ...data.invoiceRows.map((row) => List<Object?>.from(row, growable: true)),
      ..._csvGapRows(3),
      <Object?>['HSN Summary'],
      List<Object?>.from(_hsnHeaders, growable: true),
      ...data.hsnSummaries.map((hsn) => hsn.toRow()),
      ..._csvGapRows(3),
      <Object?>['State Service Coverage'],
      List<Object?>.from(_stateCoverageHeaders, growable: true),
      ..._buildStateCoverage(data).map((state) => state.toRow()),
    ];
  }

  static Iterable<List<Object?>> _csvGapRows(int count) sync* {
    // CSV cannot store real Excel formatting, but blank rows survive when the
    // file is opened in Excel. Keep three rows between report sections so the
    // vertical working register is easier to read.
    for (var i = 0; i < count; i++) {
      yield <Object?>[''];
    }
  }

  static List<List<Object?>> _buildExcelFriendlyCsvRows(_Gstr1ExportData data) {
    final coverageByCode = <String, _StateCoverage>{
      for (final state in _buildStateCoverage(data)) state.code: state,
    };

    final rows = <List<Object?>>[
      List<Object?>.from(_excelCsvHeaders, growable: true),
    ];

    for (final row in data.invoiceRows) {
      final stateCode = _normalizeStateCode(row[5]?.toString() ?? data.companyStateCode);
      final state = coverageByCode[stateCode];

      rows.add(<Object?>[
        data.periodLabel,
        data.companyStateCode,
        data.invoices.length,
        data.invoiceRows.length,
        data.totalTaxable,
        data.totalIgst,
        data.totalCgst,
        data.totalSgst,
        data.totalTax,
        data.totalInvoiceValue,
        ...row,
        stateCode,
        state?.state ?? '',
        state?.salesAmount ?? 0,
        state?.invoiceCount ?? 0,
        state?.quantity ?? 0,
        state?.tier ?? 'None',
        (state?.salesAmount ?? 0) > 0 ? 'Yes' : 'No',
      ]);
    }

    // If the month has no invoices, still create a valid Excel table with one
    // blank data row so the exported CSV is not a multi-section document.
    if (rows.length == 1) {
      rows.add(<Object?>[
        data.periodLabel,
        data.companyStateCode,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        '',
        '',
        '',
        '',
        0,
        '',
        '',
        '',
        '',
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        '',
        '',
        0,
        0,
        0,
        'None',
        'No',
      ]);
    }

    return rows;
  }

  static Future<String> _exportXlsx(_Gstr1ExportData data, String fileName) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Summary');
    }

    final summary = excel['Summary'];
    _appendXlsxRow(summary, ['GSTR-1 Working Register']);
    _appendXlsxRow(summary, ['Period', data.periodLabel]);
    _appendXlsxRow(summary, ['Company State Code', data.companyStateCode]);
    _appendXlsxRow(summary, const <Object?>[]);
    _appendXlsxRow(summary, ['Metric', 'Value']);
    for (final row in data.summaryRows) {
      _appendXlsxRow(summary, row);
    }
    _appendXlsxRow(summary, const <Object?>[]);
    _appendXlsxRow(summary, ['Section', 'Invoice Count', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Total GST', 'Invoice Value']);
    for (final entry in data.sectionSummaries) {
      _appendXlsxRow(summary, entry.value.toRow(entry.key));
    }
    _applySheetLayout(summary, 8);

    final invoices = excel['Invoice Lines'];
    _appendXlsxRow(invoices, _invoiceHeaders);
    for (final row in data.invoiceRows) {
      _appendXlsxRow(invoices, row);
    }
    _applySheetLayout(invoices, _invoiceHeaders.length);

    final hsn = excel['HSN Summary'];
    _appendXlsxRow(hsn, _hsnHeaders);
    for (final row in data.hsnSummaries.map((h) => h.toRow())) {
      _appendXlsxRow(hsn, row);
    }
    _applySheetLayout(hsn, _hsnHeaders.length);

    final charts = excel['Charts'];
    _appendXlsxRow(charts, ['GSTR-1 Chart Data']);
    _appendXlsxRow(charts, ['Tax Split']);
    _appendXlsxRow(charts, ['Tax Type', 'Amount', 'Visual Bar']);
    final taxPoints = [
      ['IGST', data.totalIgst],
      ['CGST', data.totalCgst],
      ['SGST', data.totalSgst],
    ];
    final maxTax = taxPoints.fold<double>(0, (max, point) => _asDouble(point[1]) > max ? _asDouble(point[1]) : max);
    for (final point in taxPoints) {
      _appendXlsxRow(charts, [point[0], point[1], _bar(_asDouble(point[1]), maxTax)]);
    }
    _appendXlsxRow(charts, const <Object?>[]);
    _appendXlsxRow(charts, ['Section Mix']);
    _appendXlsxRow(charts, ['Section', 'Invoice Count', 'Visual Bar']);
    final maxCount = data.sectionSummaries.fold<int>(0, (max, entry) => entry.value.invoiceIds.length > max ? entry.value.invoiceIds.length : max).toDouble();
    for (final entry in data.sectionSummaries) {
      _appendXlsxRow(charts, [entry.key, entry.value.invoiceIds.length, _bar(entry.value.invoiceIds.length.toDouble(), maxCount)]);
    }
    _applySheetLayout(charts, 3);

    // Government-style 15-table GSTR-1 register for accountant review.
    _appendGstr1GovernmentTablesSheet(excel, data);

    // Same complete multi-section register as the detailed CSV report,
    // but in a proper XLSX sheet so Excel users get all sections in one place.
    _appendGstr1FullRegisterSheet(excel, data);

    // Flat one-table data sheet matching the Excel-friendly CSV export.
    _appendExcelFriendlyDataSheet(excel, data);

    _appendStateCoverageSheet(excel, data);

    final encodedBytes = excel.encode();
    if (encodedBytes == null) {
      throw StateError('Could not create XLSX file');
    }

    // Use a non-null, growable copy so Dart analysis and XLSX patching both stay safe.
    var bytes = List<int>.from(encodedBytes, growable: true);

    // Deep debug fix: do not patch SVG drawings directly into the XLSX package
    // during export. Some Excel/mobile/web viewers reject workbook packages that
    // contain hand-written SVG drawing relationships, and browser downloads can
    // silently fail. The XLSX now stays library-generated and stable. The State
    // Coverage Map sheet still contains the blue heatmap as formatted cells plus
    // the full state-wise table and Excel filled-map-ready data. The real SVG
    // geographic map remains in the PDF export where it is reliable.
    _assertValidXlsxBytes(bytes);

    return _saveBytes(
      bytes,
      fileName,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }



  static List<int> _embedStateCoverageSvgsInXlsx(
    List<int> xlsxBytes,
    String coloredSvg,
    String? gstReferenceSvg,
  ) {
    final sourceArchive = ZipDecoder().decodeBytes(xlsxBytes, verify: false);
    final files = <String, List<int>>{};

    for (final file in sourceArchive.files) {
      if (!file.isFile) continue;

      final content = file.content;
      if (content is List<int>) {
        files[file.name] = List<int>.from(content);
      } else {
        files[file.name] = utf8.encode(content.toString());
      }
    }

    final workbookXml = _readXlsxText(files, 'xl/workbook.xml');
    final sheetRelId = _sheetRelationshipId(workbookXml, 'State Coverage Map');
    if (sheetRelId == null) return xlsxBytes;

    final workbookRelsXml = _readXlsxText(files, 'xl/_rels/workbook.xml.rels');
    final sheetTarget = _relationshipTarget(workbookRelsXml, sheetRelId);
    if (sheetTarget == null) return xlsxBytes;

    final normalizedTarget = sheetTarget.replaceFirst(RegExp(r'^/'), '');
    final sheetPath = normalizedTarget.startsWith('xl/') ? normalizedTarget : 'xl/$normalizedTarget';
    if (!files.containsKey(sheetPath)) return xlsxBytes;

    final sheetRelsPath = _sheetRelsPath(sheetPath);
    final drawingPath = 'xl/drawings/gstr1_state_coverage_map.xml';
    final drawingRelsPath = 'xl/drawings/_rels/gstr1_state_coverage_map.xml.rels';
    final mediaPath = 'xl/media/gstr1_state_coverage_map.svg';
    final referenceMediaPath = 'xl/media/gstr1_gst_state_code_reference.svg';
    final hasReferenceSvg = gstReferenceSvg != null && gstReferenceSvg.trim().isNotEmpty;

    var sheetRelsXml = files.containsKey(sheetRelsPath)
        ? _readXlsxText(files, sheetRelsPath)
        : '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';

    final drawingRelId = _nextRelationshipId(sheetRelsXml);
    sheetRelsXml = sheetRelsXml.replaceFirst(
      '</Relationships>',
      '<Relationship Id="$drawingRelId" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" '
          'Target="../drawings/gstr1_state_coverage_map.xml"/>'
          '</Relationships>',
    );
    files[sheetRelsPath] = utf8.encode(sheetRelsXml);

    var sheetXml = _readXlsxText(files, sheetPath);
    if (!sheetXml.contains('xmlns:r=')) {
      sheetXml = sheetXml.replaceFirst(
        '<worksheet ',
        '<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ',
      );
    }
    if (!sheetXml.contains('<drawing ')) {
      sheetXml = sheetXml.replaceFirst('</worksheet>', '<drawing r:id="$drawingRelId"/></worksheet>');
    }
    files[sheetPath] = utf8.encode(sheetXml);

    files[drawingPath] = utf8.encode(_stateCoverageDrawingXml(includeGstReference: hasReferenceSvg));
    files[drawingRelsPath] = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="../media/gstr1_state_coverage_map.svg"/>'
      '${hasReferenceSvg ? '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/gstr1_gst_state_code_reference.svg"/>' : ''}'
      '</Relationships>',
    );
    files[mediaPath] = utf8.encode(coloredSvg);
    if (hasReferenceSvg) {
      files[referenceMediaPath] = utf8.encode(gstReferenceSvg!);
    }

    var contentTypesXml = _readXlsxText(files, '[Content_Types].xml');
    if (!contentTypesXml.contains('Extension="svg"')) {
      contentTypesXml = contentTypesXml.replaceFirst(
        '</Types>',
        '<Default Extension="svg" ContentType="image/svg+xml"/></Types>',
      );
    }
    if (!contentTypesXml.contains('PartName="/xl/drawings/gstr1_state_coverage_map.xml"')) {
      contentTypesXml = contentTypesXml.replaceFirst(
        '</Types>',
        '<Override PartName="/xl/drawings/gstr1_state_coverage_map.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>'
            '</Types>',
      );
    }
    files['[Content_Types].xml'] = utf8.encode(contentTypesXml);

    final patchedArchive = Archive();
    for (final entry in files.entries) {
      patchedArchive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    return ZipEncoder().encode(patchedArchive) ?? xlsxBytes;
  }

  static String _readXlsxText(Map<String, List<int>> files, String path) {
    return utf8.decode(files[path] ?? const <int>[]);
  }

  static String? _sheetRelationshipId(String workbookXml, String sheetName) {
    final escapedName = RegExp.escape(sheetName);
    final match = RegExp(
      '<sheet[^>]*name="$escapedName"[^>]*r:id="([^"]+)"[^>]*/?>',
      caseSensitive: false,
    ).firstMatch(workbookXml);
    return match?.group(1);
  }

  static String? _relationshipTarget(String relationshipsXml, String relId) {
    final match = RegExp(
      '<Relationship[^>]*Id="${RegExp.escape(relId)}"[^>]*Target="([^"]+)"[^>]*/?>',
      caseSensitive: false,
    ).firstMatch(relationshipsXml);
    return match?.group(1);
  }

  static String _sheetRelsPath(String sheetPath) {
    final slash = sheetPath.lastIndexOf('/');
    final directory = sheetPath.substring(0, slash);
    final fileName = sheetPath.substring(slash + 1);
    return '$directory/_rels/$fileName.rels';
  }

  static String _nextRelationshipId(String relationshipsXml) {
    var maxId = 0;
    for (final match in RegExp(r'Id="rId(\d+)"').allMatches(relationshipsXml)) {
      final id = int.tryParse(match.group(1) ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    return 'rId${maxId + 1}';
  }

  static String _stateCoverageDrawingXml({required bool includeGstReference}) {
    final referenceAnchor = includeGstReference
        ? '''
  <xdr:twoCellAnchor editAs="oneCell">
    <xdr:from>
      <xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff>
      <xdr:row>34</xdr:row><xdr:rowOff>0</xdr:rowOff>
    </xdr:from>
    <xdr:to>
      <xdr:col>10</xdr:col><xdr:colOff>0</xdr:colOff>
      <xdr:row>58</xdr:row><xdr:rowOff>0</xdr:rowOff>
    </xdr:to>
    <xdr:pic>
      <xdr:nvPicPr>
        <xdr:cNvPr id="3" name="GST State Code Reference Map" descr="India GST state code reference map"/>
        <xdr:cNvPicPr/>
      </xdr:nvPicPr>
      <xdr:blipFill>
        <a:blip r:embed="rId2"/>
        <a:stretch><a:fillRect/></a:stretch>
      </xdr:blipFill>
      <xdr:spPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="5486400" cy="4114800"/>
        </a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </xdr:spPr>
    </xdr:pic>
    <xdr:clientData/>
  </xdr:twoCellAnchor>'''
        : '';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <xdr:twoCellAnchor editAs="oneCell">
    <xdr:from>
      <xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff>
      <xdr:row>9</xdr:row><xdr:rowOff>0</xdr:rowOff>
    </xdr:from>
    <xdr:to>
      <xdr:col>10</xdr:col><xdr:colOff>0</xdr:colOff>
      <xdr:row>31</xdr:row><xdr:rowOff>0</xdr:rowOff>
    </xdr:to>
    <xdr:pic>
      <xdr:nvPicPr>
        <xdr:cNvPr id="2" name="India State Coverage Heatmap" descr="State-wise sales coverage map"/>
        <xdr:cNvPicPr/>
      </xdr:nvPicPr>
      <xdr:blipFill>
        <a:blip r:embed="rId1"/>
        <a:stretch><a:fillRect/></a:stretch>
      </xdr:blipFill>
      <xdr:spPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="5486400" cy="3657600"/>
        </a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </xdr:spPr>
    </xdr:pic>
    <xdr:clientData/>
  </xdr:twoCellAnchor>
$referenceAnchor
</xdr:wsDr>''';
  }

  static void _appendXlsxRow(Sheet sheet, Iterable<Object?> row) {
    // The excel package mutates rows internally while writing cells. Passing a
    // const/static list (for example _invoiceHeaders) can throw:
    // "Unsupported operation: Cannot remove from an unmodifiable list".
    // Always pass a fresh growable copy to keep XLSX export stable.
    sheet.appendRow(List<Object?>.from(row, growable: true));
  }



  static void _appendGstr1GovernmentTablesSheet(Excel excel, _Gstr1ExportData data) {
    final sheet = excel['Govt GSTR1 15 Tables'];
    var rowIndex = 0;
    const gapRows = 3;
    var maxColumnCount = 6;

    rowIndex = _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'GSTR-1 Government 15 Tables Summary',
      rows: <List<Object?>>[
        <Object?>['Table', 'Description', 'Records', 'Taxable', 'Tax', 'Status'],
        ..._buildGovernmentTableSummaryRows(data),
      ],
      minColumnCount: 6,
    );
    rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: 6);

    for (final table in _buildGstr1GovernmentTables(data)) {
      final columnCount = table.headers.length > 2 ? table.headers.length : 2;
      if (columnCount > maxColumnCount) maxColumnCount = columnCount;
      final detailRows = <List<Object?>>[
        <Object?>['Note', table.note],
        List<Object?>.from(table.headers, growable: true),
        ...(table.rows.isEmpty
            ? <List<Object?>>[_emptyGovernmentRow(table.headers.length)]
            : table.rows.map((row) => List<Object?>.from(row, growable: true))),
      ];

      rowIndex = _appendRegisterSection(
        sheet: sheet,
        rowIndex: rowIndex,
        title: '${table.code} - ${table.title}',
        rows: detailRows,
        minColumnCount: columnCount,
      );
      rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: columnCount);
    }

    _autoFitSheetColumns(sheet, maxColumnCount, minWidth: 11, maxWidth: 46);
  }

  static void _appendGstr1FullRegisterSheet(Excel excel, _Gstr1ExportData data) {
    final sheet = excel['GSTR1 Full Register'];
    var rowIndex = 0;
    const gapRows = 3;
    final maxColumnCount = _invoiceHeaders.length;

    rowIndex = _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'Summary',
      rows: <List<Object?>>[
        <Object?>['Metric', 'Value'],
        ...data.summaryRows,
      ],
      minColumnCount: 2,
    );
    rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: 2);

    rowIndex = _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'Section Summary',
      rows: <List<Object?>>[
        <Object?>['Section', 'Invoice Count', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Total GST', 'Invoice Value'],
        ...data.sectionSummaries.map((entry) => entry.value.toRow(entry.key)),
      ],
      minColumnCount: 8,
    );
    rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: 8);

    rowIndex = _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'Invoice Line Items',
      rows: <List<Object?>>[
        List<Object?>.from(_invoiceHeaders, growable: true),
        ...data.invoiceRows,
      ],
      minColumnCount: _invoiceHeaders.length,
    );
    rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: _invoiceHeaders.length);

    rowIndex = _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'HSN Summary',
      rows: <List<Object?>>[
        List<Object?>.from(_hsnHeaders, growable: true),
        ...data.hsnSummaries.map((h) => h.toRow()),
      ],
      minColumnCount: _hsnHeaders.length,
    );
    rowIndex = _appendRegisterGapRows(sheet: sheet, rowIndex: rowIndex, rows: gapRows, columnCount: _hsnHeaders.length);

    _appendRegisterSection(
      sheet: sheet,
      rowIndex: rowIndex,
      title: 'State Service Coverage',
      rows: <List<Object?>>[
        List<Object?>.from(_stateCoverageHeaders, growable: true),
        ..._buildStateCoverage(data).map((state) => state.toRow()),
      ],
      minColumnCount: _stateCoverageHeaders.length,
    );

    // Keep table styles intact and only auto-fit the columns. Do not call
    // _applySheetLayout here because it would overwrite the section/table styles.
    _autoFitSheetColumns(sheet, maxColumnCount, minWidth: 11, maxWidth: 42);
  }

  static void _appendExcelFriendlyDataSheet(Excel excel, _Gstr1ExportData data) {
    final sheet = excel['Excel Data'];
    final rows = _buildExcelFriendlyCsvRows(data);
    for (final row in rows) {
      _appendXlsxRow(sheet, row);
    }
    _applySheetLayout(sheet, _excelCsvHeaders.length);
  }

  static int _appendRegisterSection({
    required Sheet sheet,
    required int rowIndex,
    required String title,
    required List<List<Object?>> rows,
    required int minColumnCount,
  }) {
    final titleStyle = CellStyle(
      bold: true,
      fontColorHex: 'FFFFFFFF',
      backgroundColorHex: 'FF0F172A',
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: 'FFFFFFFF',
      backgroundColorHex: 'FF1E3A8A',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final bodyStyle = CellStyle(
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Top,
    );

    final alternateBodyStyle = CellStyle(
      backgroundColorHex: 'FFF8FAFC',
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Top,
    );

    final sectionColumnCount = rows.fold<int>(
      minColumnCount,
      (max, row) => row.length > max ? row.length : max,
    );

    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = title;
    titleCell.cellStyle = titleStyle;
    for (var c = 1; c < sectionColumnCount; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
      cell.value = '';
      cell.cellStyle = titleStyle;
    }
    rowIndex++;

    for (var r = 0; r < rows.length; r++) {
      final sourceRow = rows[r];
      final isHeaderRow = r == 0;
      final rowStyle = isHeaderRow ? headerStyle : (r.isEven ? alternateBodyStyle : bodyStyle);

      for (var c = 0; c < sectionColumnCount; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
        cell.value = c < sourceRow.length ? sourceRow[c] : '';
        cell.cellStyle = rowStyle;
      }
      rowIndex++;
    }

    return rowIndex;
  }

  static int _appendRegisterGapRows({
    required Sheet sheet,
    required int rowIndex,
    required int rows,
    required int columnCount,
  }) {
    final gapStyle = CellStyle(backgroundColorHex: 'FFFFFFFF');
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columnCount; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex + r));
        cell.value = '';
        cell.cellStyle = gapStyle;
      }
    }
    return rowIndex + rows;
  }

  static void _appendStateCoverageSheet(Excel excel, _Gstr1ExportData data) {
    final coverage = _buildStateCoverage(data);
    final byCode = {for (final state in coverage) state.code: state};
    final sheet = excel['State Coverage Map'];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'India State Service Coverage';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Period ${data.periodLabel}';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 'Color rule: dark blue = high sales, blue = medium sales, sky blue = low sales, grey = no service/sale in selected period.';

    final legend = <List<Object?>>[
      ['High Sale', 'Dark Blue'],
      ['Medium Sale', 'Blue'],
      ['Low Sale', 'Sky Blue'],
      ['No Sale', 'Grey'],
    ];
    for (var i = 0; i < legend.length; i++) {
      final row = 4 + i;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = legend[i][0];
      final legendCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      legendCell.value = legend[i][1];
      legendCell.cellStyle = _coverageCellStyle(i == 0 ? 'High' : i == 1 ? 'Medium' : i == 2 ? 'Low' : 'None');
    }

    const startRow = 9;
    const startCol = 0;
    for (var r = 0; r < _stateTileRows.length; r++) {
      for (var c = 0; c < _stateTileRows[r].length; c++) {
        final code = _stateTileRows[r][c];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + c, rowIndex: startRow + r));
        if (code == null) {
          cell.value = '';
          continue;
        }
        final state = byCode[code]!;
        cell.value = '${_stateAbbreviations[code] ?? code}\n${state.salesAmount <= 0 ? 'No sale' : _compactMoney(state.salesAmount)}';
        cell.cellStyle = _coverageCellStyle(state.tier);
      }
    }

    const tableStartCol = 11;
    const tableStartRow = 0;
    for (var c = 0; c < _stateCoverageHeaders.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: tableStartCol + c, rowIndex: tableStartRow));
      cell.value = _stateCoverageHeaders[c];
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: 'FFFFFFFF',
        backgroundColorHex: 'FF1E3A8A',
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }
    for (var r = 0; r < coverage.length; r++) {
      final row = coverage[r].toRow();
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: tableStartCol + c, rowIndex: tableStartRow + 1 + r));
        cell.value = row[c];
        cell.cellStyle = c == 6 ? _coverageCellStyle(coverage[r].tier) : CellStyle(textWrapping: TextWrapping.WrapText);
      }
    }

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 32)).value = 'Stable XLSX mode: blue heatmap is shown as formatted cells. Use PDF export for the real geographic SVG map.';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 33)).value = 'XLSX avoids direct SVG embedding to prevent browser/Excel download failures.';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: coverage.length + 4)).value = 'Excel native filled-map data';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: coverage.length + 5)).value = 'To create an Excel Filled Map manually: select State + Sales Amount + Country from this table, then Insert > Maps > Filled Map.';

    for (var c = 0; c < 20; c++) {
      sheet.setColWidth(c, c < 10 ? 13 : 18);
    }
  }

  static pw.Widget _pdfStateCoverageTileMap(_Gstr1ExportData data, pw.Font font) {
    final coverage = _buildStateCoverage(data);
    final byCode = {for (final state in coverage) state.code: state};
    final servedStates = coverage.where((state) => state.salesAmount > 0).length;
    final topState = coverage.where((state) => state.salesAmount > 0).toList()
      ..sort((a, b) => b.salesAmount.compareTo(a.salesAmount));

    final servedList = coverage.where((state) => state.salesAmount > 0).toList()
      ..sort((a, b) => b.salesAmount.compareTo(a.salesAmount));
    final servedRows = servedList
        .take(10)
        .map<List<Object?>>((state) => [state.state, state.invoiceCount, state.salesAmount, state.quantity, state.tier])
        .toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('India state service coverage map', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 3),
          pw.Text('Served states: $servedStates/${coverage.length}${topState.isEmpty ? '' : ' • Top state: ${topState.first.state}'}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                children: _stateTileRows.map((tileRow) {
                  return pw.Row(
                    children: tileRow.map((code) {
                      if (code == null) return pw.SizedBox(width: 42, height: 28);
                      final state = byCode[code]!;
                      final bg = _pdfCoverageColor(state.tier);
                      final textColor = state.tier == 'Low' || state.tier == 'None' ? PdfColors.grey800 : PdfColors.white;
                      return pw.Container(
                        width: 42,
                        height: 28,
                        margin: const pw.EdgeInsets.all(1.2),
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: bg,
                          borderRadius: pw.BorderRadius.circular(3),
                          border: pw.Border.all(color: PdfColors.white, width: 0.4),
                        ),
                        child: pw.Text(
                          _stateAbbreviations[code] ?? code,
                          style: pw.TextStyle(font: font, fontSize: 6.3, fontWeight: pw.FontWeight.bold, color: textColor),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
              pw.SizedBox(width: 14),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLegendItem('High sale', PdfColor.fromHex('#1E3A8A'), font, PdfColors.white),
                  _pdfLegendItem('Medium sale', PdfColor.fromHex('#2563EB'), font, PdfColors.white),
                  _pdfLegendItem('Low sale', PdfColor.fromHex('#BAE6FD'), font, PdfColors.grey800),
                  _pdfLegendItem('No sale', PdfColor.fromHex('#E5E7EB'), font, PdfColors.grey800),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _pdfTable(
            headers: const ['State', 'Invoices', 'Sales', 'Qty', 'Tier'],
            rows: servedRows.isEmpty ? <List<Object?>>[['No served states in this period', 0, 0, 0, 'None']] : servedRows,
            font: font,
          ),
        ],
      ),
    );
  }

  static Future<pw.Widget> _pdfGstStateCodeReferenceMap(pw.Font font) async {
    try {
      final rawSvg = await rootBundle.loadString(_gstReferenceSvgAsset);
      final svg = _prepareGstReferenceSvg(rawSvg);

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'GST state-code reference map',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Static vector reference selected from the uploaded SVG files. Use this to match GST state codes with state names while reviewing the GSTR-1 report.',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: 500,
              height: 360,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.SvgImage(
                svg: svg,
                fit: pw.BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return pw.SizedBox();
    }
  }

  static Future<pw.Widget> _pdfStateCoverageMap(
    _Gstr1ExportData data,
    pw.Font font,
  ) async {
    final coverage = _buildStateCoverage(data);
    final servedStates = coverage.where((state) => state.salesAmount > 0).length;

    final topStateList = coverage.where((state) => state.salesAmount > 0).toList()
      ..sort((a, b) => b.salesAmount.compareTo(a.salesAmount));

    final servedRows = topStateList
        .take(10)
        .map<List<Object?>>(
          (state) => [
            state.state,
            state.invoiceCount,
            state.salesAmount,
            state.quantity,
            state.tier,
          ],
        )
        .toList();

    try {
      final coloredSvg = _buildColoredIndiaSvg(
        await rootBundle.loadString(_stateHeatmapSvgAsset),
        coverage,
      );

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'India state service coverage heatmap',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Served states: $servedStates/${coverage.length}'
              '${topStateList.isEmpty ? '' : ' • Top state: ${topStateList.first.state}'}',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 500,
                  height: 330,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.SvgImage(
                    svg: coloredSvg,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sales intensity',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    _pdfLegendItem('High sale', PdfColor.fromHex('#1E3A8A'), font, PdfColors.white),
                    _pdfLegendItem('Medium sale', PdfColor.fromHex('#2563EB'), font, PdfColors.white),
                    _pdfLegendItem('Low sale', PdfColor.fromHex('#BAE6FD'), font, PdfColors.grey800),
                    _pdfLegendItem('No sale', PdfColor.fromHex('#E5E7EB'), font, PdfColors.grey800),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _pdfTable(
              headers: const ['State', 'Invoices', 'Sales', 'Qty', 'Tier'],
              rows: servedRows.isEmpty
                  ? <List<Object?>>[
                      ['No served states in this period', 0, 0, 0, 'None'],
                    ]
                  : servedRows,
              font: font,
            ),
          ],
        ),
      );
    } catch (_) {
      // If the selected SVG asset is missing or the PDF SVG renderer cannot parse it,
      // keep export working with the older tile/grid fallback map.
      return _pdfStateCoverageTileMap(data, font);
    }
  }

  static String _prepareGstReferenceSvg(String rawSvg) {
    var svg = rawSvg;
    svg = svg.replaceAll(RegExp(r'<\?xml[^>]*>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<!DOCTYPE[\s\S]*?\]>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<title[\s\S]*?</title>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<desc[\s\S]*?</desc>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<foreignObject[\s\S]*?</foreignObject>', caseSensitive: false), '');
    return svg;
  }

  static String _buildColoredIndiaSvg(
    String rawSvg,
    List<_StateCoverage> coverage,
  ) {
    var svg = _prepareIndiaSvgForDynamicFill(rawSvg);

    for (final state in coverage) {
      final svgId = _stateSvgIds[state.code];
      if (svgId == null) continue;

      svg = _paintSvgStateById(
        svg: svg,
        id: svgId,
        fill: _coverageSvgHex(state.tier),
      );
    }

    return svg;
  }

  static String _prepareIndiaSvgForDynamicFill(String rawSvg) {
    var svg = rawSvg;

    // Some PDF/XLSX SVG renderers are stricter than browsers. Remove
    // XML/DTD/Illustrator-only blocks before dynamic coloring.
    svg = svg.replaceAll(RegExp(r'<\?xml[^>]*>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<!DOCTYPE[\s\S]*?\]>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<title[\s\S]*?</title>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<desc[\s\S]*?</desc>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<text[\s\S]*?</text>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'<tspan[\s\S]*?</tspan>', caseSensitive: false), '');
    svg = svg.replaceAll('paintmaps.com', '');
    svg = svg.replaceAll(RegExp(r'<foreignObject[\s\S]*?</foreignObject>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'</?switch[^>]*>', caseSensitive: false), '');
    svg = svg.replaceAll(RegExp(r'\s+[A-Za-z]+:[A-Za-z0-9_-]+="[^"]*"'), '');

    // Paint every map shape grey first, then repaint served states by tier.
    svg = svg.replaceAllMapped(
      RegExp(r'<(path|polygon)([^>]*?)>', caseSensitive: false),
      (match) {
        var tag = match.group(0)!;
        tag = _removeSvgPaint(tag);

        final attrs = [
          'fill="#E5E7EB"',
          'stroke="#CBD5E1"',
          'stroke-width="0.7"',
          'stroke-linejoin="round"',
        ].join(' ');

        return _insertSvgAttrs(tag, attrs);
      },
    );

    return svg;
  }

  static String _paintSvgStateById({
    required String svg,
    required String id,
    required String fill,
  }) {
    final pattern = RegExp(
      r'<(path|polygon)([^>]*\bid="' + RegExp.escape(id) + r'"[^>]*)>',
      caseSensitive: false,
    );

    return svg.replaceAllMapped(pattern, (match) {
      var tag = match.group(0)!;
      tag = _removeSvgPaint(tag);

      final attrs = [
        'fill="$fill"',
        'stroke="#FFFFFF"',
        'stroke-width="0.8"',
        'stroke-linejoin="round"',
      ].join(' ');

      return _insertSvgAttrs(tag, attrs);
    });
  }

  static String _removeSvgPaint(String tag) {
    var output = tag;

    output = output.replaceAll(
      RegExp(r'\sfill="[^"]*"', caseSensitive: false),
      '',
    );

    output = output.replaceAll(
      RegExp(r'\sstroke="[^"]*"', caseSensitive: false),
      '',
    );

    output = output.replaceAll(
      RegExp(r'\sstroke-width="[^"]*"', caseSensitive: false),
      '',
    );

    output = output.replaceAll(
      RegExp(r'\sstroke-linejoin="[^"]*"', caseSensitive: false),
      '',
    );

    // Remove path classes such as st0 because stylesheet fill rules can
    // override presentation fill attributes in some SVG renderers.
    output = output.replaceAll(
      RegExp(r'\sclass="[^"]*"', caseSensitive: false),
      '',
    );

    output = output.replaceAllMapped(
      RegExp(r'\sstyle="([^"]*)"', caseSensitive: false),
      (match) {
        final style = match.group(1) ?? '';
        final cleanedParts = style
            .split(';')
            .map((part) => part.trim())
            .where((part) {
              final lower = part.toLowerCase();
              return part.isNotEmpty &&
                  !lower.startsWith('fill:') &&
                  !lower.startsWith('stroke:') &&
                  !lower.startsWith('stroke-width:');
            })
            .toList();

        if (cleanedParts.isEmpty) return '';
        return ' style="${cleanedParts.join(';')}"';
      },
    );

    return output;
  }

  static String _insertSvgAttrs(String tag, String attrs) {
    if (tag.endsWith('/>')) {
      return '${tag.substring(0, tag.length - 2)} $attrs />';
    }

    if (tag.endsWith('>')) {
      return '${tag.substring(0, tag.length - 1)} $attrs>';
    }

    return '$tag $attrs';
  }

  static String _coverageSvgHex(String tier) {
    final argb = _coverageHex(tier);

    // _coverageHex returns ARGB like FF1E3A8A. SVG needs RGB like #1E3A8A.
    if (argb.length == 8) {
      return '#${argb.substring(2)}';
    }

    return '#E5E7EB';
  }

  static pw.Widget _pdfLegendItem(String label, PdfColor color, pw.Font font, PdfColor textColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Container(width: 16, height: 9, color: color),
          pw.SizedBox(width: 5),
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 7, color: textColor == PdfColors.white ? PdfColors.grey800 : textColor)),
        ],
      ),
    );
  }

  static List<_StateCoverage> _buildStateCoverage(_Gstr1ExportData data) {
    final accumulators = <String, _StateAccumulator>{};
    for (final invoice in data.invoices) {
      final code = _normalizeStateCode(invoice.placeOfSupply ?? data.companyStateCode);
      if (!_stateNames.containsKey(code)) continue;
      final acc = accumulators.putIfAbsent(code, () => _StateAccumulator(code));
      acc.invoiceIds.add(invoice.id);
      acc.salesAmount += invoice.grandTotal;
      acc.quantity += invoice.totalQuantity;
    }

    final maxSales = accumulators.values.fold<double>(0, (max, acc) => acc.salesAmount > max ? acc.salesAmount : max);
    return _stateNames.entries.map((entry) {
      final acc = accumulators[entry.key];
      final sales = acc?.salesAmount ?? 0.0;
      return _StateCoverage(
        code: entry.key,
        state: entry.value,
        invoiceCount: acc?.invoiceIds.length ?? 0,
        salesAmount: sales,
        quantity: acc?.quantity ?? 0.0,
        tier: _blueTier(sales, maxSales),
      );
    }).toList(growable: false);
  }

  static String _normalizeStateCode(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    final digitMatch = RegExp(r'\d+').firstMatch(value);
    if (digitMatch != null) {
      final digits = digitMatch.group(0)!;
      return digits.length == 1 ? digits.padLeft(2, '0') : digits.substring(0, 2);
    }
    final lowered = value.toLowerCase();
    for (final entry in _stateNames.entries) {
      if (entry.value.toLowerCase() == lowered) return entry.key;
    }
    return _stateAbbreviationToCode[lowered.toUpperCase()] ?? value;
  }

  static String _blueTier(double sales, double maxSales) {
    if (sales <= 0 || maxSales <= 0) return 'None';
    final ratio = sales / maxSales;
    if (ratio >= 0.67) return 'High';
    if (ratio >= 0.34) return 'Medium';
    return 'Low';
  }

  static CellStyle _coverageCellStyle(String tier) {
    final isDark = tier == 'High' || tier == 'Medium';
    return CellStyle(
      bold: true,
      textWrapping: TextWrapping.WrapText,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: isDark ? 'FFFFFFFF' : 'FF0F172A',
      backgroundColorHex: _coverageHex(tier),
    );
  }

  static String _coverageHex(String tier) {
    switch (tier) {
      case 'High':
        return 'FF1E3A8A';
      case 'Medium':
        return 'FF2563EB';
      case 'Low':
        return 'FFBAE6FD';
      default:
        return 'FFE5E7EB';
    }
  }

  static PdfColor _pdfCoverageColor(String tier) {
    switch (tier) {
      case 'High':
        return PdfColor.fromHex('#1E3A8A');
      case 'Medium':
        return PdfColor.fromHex('#2563EB');
      case 'Low':
        return PdfColor.fromHex('#BAE6FD');
      default:
        return PdfColor.fromHex('#E5E7EB');
    }
  }

  static String _compactMoney(double amount) {
    if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  static Future<String> _exportPdf(_Gstr1ExportData data, String fileName) async {
    final font = pw.Font.helvetica();
    final pdf = pw.Document();
    final stateCoverageMap = await _pdfStateCoverageMap(data, font);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GSTR-1 Working Register', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 3),
                pw.Text('Period ${data.periodLabel} • Company state code ${data.companyStateCode}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Text('Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          _pdfSummaryCards(data, font),
          pw.SizedBox(height: 10),
          _pdfTaxChart(data, font),
          pw.SizedBox(height: 10),
          stateCoverageMap,
          pw.SizedBox(height: 10),
          pw.Text('GSTR-1 Government 15 Tables', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: const ['Table', 'Description', 'Records', 'Taxable', 'Tax', 'Status'],
            rows: _buildGovernmentTableSummaryRows(data),
            font: font,
          ),
          pw.SizedBox(height: 12),
          ..._buildGovernmentPdfDetailWidgets(data, font),
          pw.SizedBox(height: 10),
          pw.Text('Section Summary', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: const ['Section', 'Invoices', 'Taxable', 'IGST', 'CGST', 'SGST', 'GST', 'Invoice Value'],
            rows: data.sectionSummaries.map((entry) => entry.value.toRow(entry.key)).toList(),
            font: font,
          ),
          pw.SizedBox(height: 12),
          pw.Text('HSN Summary', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: _hsnHeaders,
            rows: data.hsnSummaries.map((h) => h.toRow()).toList(),
            font: font,
          ),
          pw.SizedBox(height: 12),
          pw.Text('Invoice Line Items', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: const ['Sec', 'GSTIN', 'Inv No', 'Date', 'Inv Value', 'POS', 'Customer', 'Product', 'HSN', 'Qty', 'Taxable', 'GST %', 'IGST', 'CGST', 'SGST'],
            rows: data.invoiceRows.map((row) => [
              row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[11], row[12], row[13], row[14], row[15],
            ]).toList(),
            font: font,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    if (kIsWeb) {
      return _saveBytes(bytes, fileName, 'application/pdf');
    }
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return 'PDF generated: $fileName';
  }

  static pw.Widget _pdfSummaryCards(_Gstr1ExportData data, pw.Font font) {
    final cards = <String, String>{
      'Invoices': data.invoices.length.toString(),
      'Taxable': _money.format(data.totalTaxable),
      'Total GST': _money.format(data.totalTax),
      'Invoice Value': _money.format(data.totalInvoiceValue),
    };
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cards.entries.map((entry) {
        return pw.Container(
          width: 168,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(entry.key, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(entry.value, style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _pdfTaxChart(_Gstr1ExportData data, pw.Font font) {
    final points = <MapEntry<String, double>>[
      MapEntry('IGST', data.totalIgst),
      MapEntry('CGST', data.totalCgst),
      MapEntry('SGST', data.totalSgst),
    ];
    final maxValue = points.fold<double>(0, (max, point) => point.value > max ? point.value : max);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Generated GST tax split chart', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 8),
          ...points.map((point) {
            final ratio = maxValue <= 0 ? 0.0 : (point.value / maxValue).clamp(0.0, 1.0).toDouble();
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 70, child: pw.Text(point.key, style: pw.TextStyle(font: font, fontSize: 8))),
                  pw.SizedBox(
                    width: 220,
                    child: pw.Stack(
                      children: [
                        pw.Container(width: 220, height: 9, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(5))),
                        pw.Container(width: 220 * ratio, height: 9, decoration: pw.BoxDecoration(color: PdfColors.indigo600, borderRadius: pw.BorderRadius.circular(5))),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 95, child: pw.Text(_money.format(point.value), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<Object?>> rows,
    required pw.Font font,
  }) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: rows.map((row) => row.map(_pdfCell).toList()).toList(),
      headerStyle: pw.TextStyle(font: font, fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: pw.TextStyle(font: font, fontSize: 6),
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    );
  }

  static List<List<Object?>> _sectionHeadersAndRows(_Gstr1ExportData data) {
    return [
      const ['Section', 'Invoice Count', 'Taxable Value', 'IGST', 'CGST', 'SGST', 'Total GST', 'Invoice Value'],
      ...data.sectionSummaries.map((entry) => entry.value.toRow(entry.key)),
    ];
  }

  static void _applySheetLayout(Sheet sheet, int columnCount) {
    final headerStyle = CellStyle(bold: true, textWrapping: TextWrapping.WrapText);
    final bodyStyle = CellStyle(textWrapping: TextWrapping.WrapText);

    _autoFitSheetColumns(sheet, columnCount);

    final maxRows = sheet.maxRows;
    for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
      for (var rowIndex = 0; rowIndex < maxRows; rowIndex++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = rowIndex == 0 || rowIndex == 4 ? headerStyle : bodyStyle;
      }
    }
  }

  static void _autoFitSheetColumns(
    Sheet sheet,
    int columnCount, {
    double minWidth = 11,
    double maxWidth = 34,
  }) {
    final maxRows = sheet.maxRows;
    for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
      var maxLength = 10;
      for (var rowIndex = 0; rowIndex < maxRows; rowIndex++) {
        final value = sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value;
        final valueText = value?.toString() ?? '';
        final length = valueText.split('\n').fold<int>(0, (max, part) => part.length > max ? part.length : max);
        if (length > maxLength) maxLength = length;
      }
      sheet.setColWidth(columnIndex, (maxLength + 2).clamp(minWidth, maxWidth).toDouble());
    }
  }

  static String _bar(double value, double maxValue) {
    if (value <= 0 || maxValue <= 0) return '';
    final blocks = ((value / maxValue) * 28).clamp(1, 28).round();
    return List.filled(blocks, '█').join();
  }

  static Future<String> _saveBytes(List<int> bytes, String fileName, String mimeType) async {
    if (bytes.isEmpty) {
      throw StateError('Export failed: $fileName is empty.');
    }

    if (fileName.toLowerCase().endsWith('.xlsx')) {
      _assertValidXlsxBytes(bytes);
    }

    if (kIsWeb) {
      final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..target = '_self'
        ..style.display = 'none';

      final body = html.document.body;
      if (body == null) {
        html.Url.revokeObjectUrl(url);
        throw StateError('Download failed: browser document body is not ready.');
      }

      body.append(anchor);
      anchor.click();
      anchor.remove();

      // Do not revoke immediately. Chrome/Edge can cancel larger XLSX downloads
      // if the object URL is revoked too quickly after the synthetic click.
      Future<void>.delayed(const Duration(seconds: 5), () {
        html.Url.revokeObjectUrl(url);
      });

      return 'Download started: $fileName';
    }

    Directory directory;
    try {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return 'Saved ${file.path}';
  }

  static void _assertValidXlsxBytes(List<int> bytes) {
    if (bytes.length < 8 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw StateError('XLSX export failed: generated file is not a valid ZIP/XLSX package.');
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final names = archive.files.map((file) => file.name).toSet();
      final requiredParts = <String>{
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
      };

      for (final part in requiredParts) {
        if (!names.contains(part)) {
          throw StateError('XLSX export failed: missing $part.');
        }
      }
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('XLSX export failed: generated workbook package is invalid. $error');
    }
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static String _pdfCell(Object? value) {
    if (value is num) return value.toStringAsFixed(2);
    return value?.toString() ?? '';
  }

  static const List<String> _invoiceHeaders = [
    'Section',
    'GSTIN',
    'Invoice No',
    'Invoice Date',
    'Invoice Value',
    'Place Of Supply',
    'Customer',
    'Product',
    'HSN',
    'Qty',
    'Rate',
    'Taxable Value',
    'GST %',
    'IGST',
    'CGST',
    'SGST',
    'Line Total',
  ];


  static const List<String> _excelCsvHeaders = [
    'Report Period',
    'Company State Code',
    'Total Invoices In Period',
    'Total Line Items In Period',
    'Period Taxable Value',
    'Period IGST',
    'Period CGST',
    'Period SGST',
    'Period Total GST',
    'Period Invoice Value',
    ..._invoiceHeaders,
    'GST State Code',
    'State/UT',
    'State Sales Amount',
    'State Invoice Count',
    'State Qty Sold',
    'State Coverage Tier',
    'State Served',
  ];

  static const List<String> _hsnHeaders = [
    'HSN',
    'Product Summary',
    'Qty',
    'Taxable Value',
    'IGST',
    'CGST',
    'SGST',
    'Total GST',
    'Total Value',
  ];
}


const List<String> _stateCoverageHeaders = [
  'GST State Code',
  'State/UT',
  'Country',
  'Invoice Count',
  'Sales Amount',
  'Qty Sold',
  'Coverage Tier',
  'Served',
];

const Map<String, String> _stateNames = {
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '25': 'Daman and Diu',
  '26': 'Dadra and Nagar Haveli',
  '27': 'Maharashtra',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
};

const Map<String, String> _stateSvgIds = {
  '01': 'IN_JK',
  '02': 'IN_HP',
  '03': 'IN_PB',
  '04': 'IN_CH',
  '05': 'IN_UK',
  '06': 'IN_HR',
  '07': 'IN_DL',
  '08': 'IN_RJ',
  '09': 'IN_UP',
  '10': 'IN_BR',
  '11': 'IN_SK',
  '12': 'IN_AR',
  '13': 'IN_NL',
  '14': 'IN_MN',
  '15': 'IN_MZ',
  '16': 'IN_TR',
  '17': 'IN_ML',
  '18': 'IN_AS',
  '19': 'IN_WB',
  '20': 'IN_JH',
  '21': 'IN_OD',
  '22': 'IN_CG',
  '23': 'IN_MP',
  '24': 'IN_GJ',
  '25': 'IN_DD',
  '26': 'IN_DNH',
  '27': 'IN_MH',
  '29': 'IN_KA',
  '30': 'IN_GA',
  '31': 'IN_LD',
  '32': 'IN_KL',
  '33': 'IN_TN',
  '34': 'IN_PY',
  '35': 'IN_AN',
  // The uploaded Paintmaps SVG has old Andhra Pradesh geometry and no separate Telangana path.
  // It also has combined Jammu & Kashmir/Ladakh geometry. Map those GST codes to the available shapes.
  '36': 'IN_AP',
  '37': 'IN_AP',
  '38': 'IN_JK',
};

const Map<String, String> _stateAbbreviations = {
  '01': 'J&K',
  '02': 'HP',
  '03': 'PB',
  '04': 'CH',
  '05': 'UK',
  '06': 'HR',
  '07': 'DL',
  '08': 'RJ',
  '09': 'UP',
  '10': 'BR',
  '11': 'SK',
  '12': 'AR',
  '13': 'NL',
  '14': 'MN',
  '15': 'MZ',
  '16': 'TR',
  '17': 'ML',
  '18': 'AS',
  '19': 'WB',
  '20': 'JH',
  '21': 'OD',
  '22': 'CG',
  '23': 'MP',
  '24': 'GJ',
  '25': 'DD',
  '26': 'DNH',
  '27': 'MH',
  '29': 'KA',
  '30': 'GA',
  '31': 'LD',
  '32': 'KL',
  '33': 'TN',
  '34': 'PY',
  '35': 'AN',
  '36': 'TS',
  '37': 'AP',
  '38': 'LA',
};

const Map<String, String> _stateAbbreviationToCode = {
  'JK': '01',
  'J&K': '01',
  'HP': '02',
  'PB': '03',
  'CH': '04',
  'UK': '05',
  'UT': '05',
  'HR': '06',
  'DL': '07',
  'RJ': '08',
  'UP': '09',
  'BR': '10',
  'SK': '11',
  'AR': '12',
  'NL': '13',
  'MN': '14',
  'MZ': '15',
  'TR': '16',
  'ML': '17',
  'AS': '18',
  'WB': '19',
  'JH': '20',
  'OD': '21',
  'OR': '21',
  'CG': '22',
  'MP': '23',
  'GJ': '24',
  'DD': '25',
  'DNH': '26',
  'MH': '27',
  'KA': '29',
  'GA': '30',
  'LD': '31',
  'KL': '32',
  'TN': '33',
  'PY': '34',
  'AN': '35',
  'TS': '36',
  'TG': '36',
  'AP': '37',
  'LA': '38',
};

const List<List<String?>> _stateTileRows = [
  [null, null, '01', '38', null, null, null, null, null, null],
  [null, '03', '02', null, null, null, null, null, null, null],
  [null, '08', '06', '04', '05', null, '12', '13', null, null],
  [null, '24', '23', '07', '09', '10', '11', '18', '14', '15'],
  ['25', '26', '27', '22', '20', '19', '17', '16', null, null],
  [null, '30', '29', '36', '21', null, null, null, null, null],
  [null, '31', '32', '37', null, null, null, null, null, null],
  [null, null, '33', '34', null, null, '35', null, null, null],
];


class _Gstr1GovernmentTable {
  final String code;
  final String title;
  final String note;
  final List<String> headers;
  final List<List<Object?>> rows;

  const _Gstr1GovernmentTable({
    required this.code,
    required this.title,
    required this.note,
    required this.headers,
    required this.rows,
  });
}

class _GovernmentTaxBucket {
  final String pos;
  final double rate;
  final String supplyType;
  double taxable = 0;
  double igst = 0;
  double cgst = 0;
  double sgst = 0;

  _GovernmentTaxBucket({
    required this.pos,
    required this.rate,
    required this.supplyType,
  });
}

class _GovernmentHsnBucket {
  final String category;
  final String hsn;
  final double rate;
  final Set<String> descriptions = <String>{};
  double quantity = 0;
  double taxable = 0;
  double igst = 0;
  double cgst = 0;
  double sgst = 0;

  _GovernmentHsnBucket({
    required this.category,
    required this.hsn,
    required this.rate,
  });
}

class _Gstr1ExportData {
  final int month;
  final int year;
  final String companyStateCode;
  final List<InvoiceModel> invoices;
  final List<ReturnOrderRecord> returns;
  final List<List<Object?>> invoiceRows;
  final List<_HsnSummary> hsnSummaries;
  final List<MapEntry<String, _SectionSummary>> sectionSummaries;
  final List<List<Object?>> summaryRows;

  const _Gstr1ExportData({
    required this.month,
    required this.year,
    required this.companyStateCode,
    required this.invoices,
    required this.returns,
    required this.invoiceRows,
    required this.hsnSummaries,
    required this.sectionSummaries,
    required this.summaryRows,
  });

  String get periodLabel => '${year}-${month.toString().padLeft(2, '0')}';
  double get totalTaxable => invoiceRows.fold<double>(0, (sum, row) => sum + Gstr1Service._asDouble(row[11]));
  double get totalIgst => invoiceRows.fold<double>(0, (sum, row) => sum + Gstr1Service._asDouble(row[13]));
  double get totalCgst => invoiceRows.fold<double>(0, (sum, row) => sum + Gstr1Service._asDouble(row[14]));
  double get totalSgst => invoiceRows.fold<double>(0, (sum, row) => sum + Gstr1Service._asDouble(row[15]));
  double get totalTax => totalIgst + totalCgst + totalSgst;
  double get totalInvoiceValue => invoices.fold<double>(0, (sum, invoice) => sum + invoice.grandTotal);
}

class _SectionSummary {
  final Set<String> invoiceIds = <String>{};
  double taxableValue = 0;
  double igst = 0;
  double cgst = 0;
  double sgst = 0;
  double invoiceValue = 0;

  List<Object?> toRow(String section) => [
        section,
        invoiceIds.length,
        taxableValue,
        igst,
        cgst,
        sgst,
        igst + cgst + sgst,
        invoiceValue,
      ];
}

class _HsnSummary {
  final String hsn;
  final Set<String> products = <String>{};
  double quantity = 0;
  double taxable = 0;
  double igst = 0;
  double cgst = 0;
  double sgst = 0;

  _HsnSummary(this.hsn);

  void addItem(InvoiceLineItem item, {required double igst, required double cgst, required double sgst}) {
    products.add(item.productName);
    quantity += item.quantity;
    taxable += item.taxableValue;
    this.igst += igst;
    this.cgst += cgst;
    this.sgst += sgst;
  }

  List<Object?> toRow() => [
        hsn,
        products.take(4).join(' | '),
        quantity,
        taxable,
        igst,
        cgst,
        sgst,
        igst + cgst + sgst,
        taxable + igst + cgst + sgst,
      ];
}


class _StateAccumulator {
  final String code;
  final Set<String> invoiceIds = <String>{};
  double salesAmount = 0;
  double quantity = 0;

  _StateAccumulator(this.code);
}

class _StateCoverage {
  final String code;
  final String state;
  final int invoiceCount;
  final double salesAmount;
  final double quantity;
  final String tier;

  const _StateCoverage({
    required this.code,
    required this.state,
    required this.invoiceCount,
    required this.salesAmount,
    required this.quantity,
    required this.tier,
  });

  List<Object?> toRow() => [
        code,
        state,
        'India',
        invoiceCount,
        salesAmount,
        quantity,
        tier,
        salesAmount > 0 ? 'Yes' : 'No',
      ];
}
