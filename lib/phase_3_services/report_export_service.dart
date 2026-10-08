import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:salesvista/phase_2_models/expense_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:universal_html/html.dart' as html;

class ReportExportService {
  ReportExportService(this.repo);

  final PosRepository repo;
  final DateFormat _date = DateFormat('yyyy-MM-dd');
  final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  Future<String> export({
    required String reportType,
    required String format,
    DateTime? from,
    DateTime? to,
  }) async {
    final table = _buildReport(reportType, from: from, to: to);
    final fileBase = '${table.fileStem}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    switch (format.toLowerCase()) {
      case 'pdf':
        return _exportPdf(table, '$fileBase.pdf');
      case 'xlsx':
        return _exportXlsx(table, '$fileBase.xlsx');
      case 'csv':
      default:
        return _exportCsv(table, '$fileBase.csv');
    }
  }

  ReportTable _buildReport(String reportType, {DateTime? from, DateTime? to}) {
    final key = reportType.toLowerCase().replaceAll(' ', '_');
    switch (key) {
      case 'inventory':
        return _inventoryReport();
      case 'customers':
      case 'customer_ledger':
        return _customerReport();
      case 'gstr1':
      case 'gst_r1':
        return _gstr1Report(from: from, to: to);
      case 'expenses':
        return _expenseReport(from: from, to: to);
      case 'inventory_refill':
      case 'inventory_refills':
      case 'refill':
      case 'refills':
        return _inventoryRefillReport(from: from, to: to);
      case 'transactions':
        return _transactionReport(from: from, to: to);
      case 'returns':
      case 'return_orders':
        return _returnsReport(from: from, to: to);
      case 'invoices':
        return _invoiceReport(from: from, to: to);
      case 'sales':
      default:
        return _salesReport(from: from, to: to);
    }
  }

  ReportTable _salesReport({DateTime? from, DateTime? to}) {
    final orders = _filterDates<OrderModel>(repo.ordersBox.values, (o) => o.date, from, to)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Sales Report',
      fileStem: 'sales_report',
      subtitle: _periodLabel(from, to),
      headers: const ['Date', 'Customer', 'Product', 'Qty', 'Taxable Value', 'GST', 'Grand Total', 'Paid', 'Due'],
      rows: orders.map((o) => [
        _date.format(o.date),
        o.customerName,
        o.productName,
        o.quantity,
        o.totalAmount,
        o.gstAmount,
        o.grandTotal,
        o.paid,
        o.due,
      ]).toList(),
    );
  }

  ReportTable _invoiceReport({DateTime? from, DateTime? to}) {
    final invoices = _filterDates<InvoiceModel>(repo.invoicesBox.values, (i) => i.date, from, to)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Invoice Register',
      fileStem: 'invoice_register',
      subtitle: _periodLabel(from, to),
      headers: const ['Date', 'Invoice No', 'Customer', 'GSTIN', 'Items', 'Taxable Value', 'GST', 'Discount', 'Grand Total', 'Paid', 'Due', 'Mode'],
      rows: invoices.map((i) => [
        _date.format(i.date),
        i.id,
        i.customerName,
        i.buyerGstin ?? '',
        i.safeProductName,
        i.subtotal,
        i.gstAmount,
        i.discountAmount,
        i.grandTotal,
        i.paid,
        i.due,
        i.paymentMode,
      ]).toList(),
    );
  }

  ReportTable _inventoryReport() {
    final products = repo.products();
    return ReportTable(
      title: 'Inventory Report',
      fileStem: 'inventory_report',
      subtitle: 'Current stock snapshot',
      headers: const ['Product', 'SKU', 'Barcode', 'HSN', 'Unit', 'Stock', 'Low Stock', 'Purchase Price', 'Selling Price', 'GST %', 'Stock Value'],
      rows: products.map((p) => [
        p.name,
        p.sku,
        p.barcode,
        p.hsn,
        p.unit,
        p.stock,
        p.lowStock,
        p.purchasePrice,
        p.price,
        p.gstPercent,
        p.stock * p.purchasePrice,
      ]).toList(),
    );
  }

  ReportTable _customerReport() {
    final customers = repo.customers();
    return ReportTable(
      title: 'Customer Ledger',
      fileStem: 'customer_ledger',
      subtitle: 'Outstanding receivables and GST profile',
      headers: const ['Name', 'Phone', 'Email', 'GSTIN', 'State Code', 'Address', 'Receivable'],
      rows: customers.map((c) => [
        c.name,
        c.phone,
        c.email,
        c.gstin,
        c.stateCode,
        c.address,
        repo.receivableForCustomer(c.name, customerId: c.id),
      ]).toList(),
    );
  }

  ReportTable _expenseReport({DateTime? from, DateTime? to}) {
    final expenses = _filterDates<ExpenseModel>(repo.expensesBox.values, (e) => e.date, from, to)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Expense Report',
      fileStem: 'expense_report',
      subtitle: _periodLabel(from, to),
      headers: const ['Date', 'Category', 'Batch Number', 'Title', 'Product', 'Refill Qty', 'Unit', 'Unit Purchase Price', 'Total Amount', 'POS Price Updated', 'New POS Price', 'Note'],
      rows: expenses.map((e) => [
        _date.format(e.date),
        e.safeCategory,
        e.safeBatchNumber,
        e.displayTitle,
        e.productName,
        e.refillQuantity <= 0 ? '' : e.refillQuantity,
        e.unit,
        e.isInventoryRefill ? e.safeUnitPurchasePrice : '',
        e.amount,
        e.posPriceUpdated ? 'Yes' : 'No',
        e.posPriceUpdated ? e.sellingPriceAfterRefill : '',
        e.note,
      ]).toList(),
    );
  }

  ReportTable _inventoryRefillReport({DateTime? from, DateTime? to}) {
    final refills = _filterDates<ExpenseModel>(
      repo.expensesBox.values.where((e) => e.isInventoryRefill),
      (e) => e.date,
      from,
      to,
    ).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Inventory Refill Register',
      fileStem: 'inventory_refill_register',
      subtitle: _periodLabel(from, to),
      headers: const ['Date', 'Batch Number', 'Product', 'Refill Qty', 'Unit', 'Unit Purchase Price', 'Total Amount', 'POS Price Updated', 'New POS Price', 'Title', 'Note'],
      rows: refills.map((e) => [
        _date.format(e.date),
        e.safeBatchNumber,
        e.productName,
        e.refillQuantity,
        e.unit,
        e.safeUnitPurchasePrice,
        e.amount,
        e.posPriceUpdated ? 'Yes' : 'No',
        e.posPriceUpdated ? e.sellingPriceAfterRefill : '',
        e.displayTitle,
        e.note,
      ]).toList(),
    );
  }

  ReportTable _transactionReport({DateTime? from, DateTime? to}) {
    final transactions = _filterDates<TransactionModel>(repo.transactionsBox.values, (t) => t.date, from, to)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Transaction Report',
      fileStem: 'transaction_report',
      subtitle: _periodLabel(from, to),
      headers: const ['Date', 'Title', 'Type', 'Amount', 'Order Id', 'Sales Id'],
      rows: transactions.map((t) => [_date.format(t.date), t.title, t.type, t.amount, t.orderId ?? '', t.salesId ?? '']).toList(),
    );
  }


  ReportTable _returnsReport({DateTime? from, DateTime? to}) {
    final returns = _filterDates<ReturnOrderRecord>(repo.returnRecords(), (r) => r.date, from, to)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ReportTable(
      title: 'Return Order Register',
      fileStem: 'return_order_register',
      subtitle: _periodLabel(from, to),
      headers: const ['Return Date', 'Return ID', 'Original Date', 'Invoice No', 'Order ID', 'Customer', 'Product', 'HSN', 'Qty', 'Taxable Value', 'GST %', 'GST Amount', 'Return Amount', 'Refund Amount', 'Payment Mode', 'Reason', 'Source'],
      rows: returns.map((r) => [
        _date.format(r.date),
        r.id,
        r.originalDate == null ? '' : _date.format(r.originalDate!),
        r.invoiceId,
        r.orderId,
        r.customerName,
        r.productName,
        r.hsn,
        r.quantity,
        r.taxableValue,
        r.gstPercent,
        r.gstAmount,
        r.returnAmount,
        r.refundAmount,
        r.paymentMode,
        r.reason,
        r.source,
      ]).toList(),
    );
  }

  ReportTable _gstr1Report({DateTime? from, DateTime? to}) {
    final companyStateCode = repo.settingsBox.get('companyStateCode', defaultValue: '24').toString();
    final invoices = _filterDates<InvoiceModel>(repo.invoicesBox.values, (i) => i.date, from, to)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final rows = <List<Object?>>[];
    for (final invoice in invoices) {
      invoice.calculateTax(companyStateCode);
      for (final item in invoice.items) {
        final lineTax = item.gstAmount;
        final isInterState = invoice.igst > 0;
        rows.add([
          invoice.invoiceType,
          invoice.buyerGstin ?? '',
          invoice.id,
          _date.format(invoice.date),
          invoice.grandTotal,
          invoice.placeOfSupply ?? companyStateCode,
          item.productName,
          item.hsn,
          item.quantity,
          item.taxableValue,
          item.gstPercent,
          isInterState ? lineTax : 0.0,
          isInterState ? 0.0 : lineTax / 2,
          isInterState ? 0.0 : lineTax / 2,
        ]);
      }
    }

    return ReportTable(
      title: 'GSTR-1 Working Register',
      fileStem: 'gstr1_working_register',
      subtitle: '${_periodLabel(from, to)} • Verify on GST portal before filing',
      headers: const ['Type', 'GSTIN', 'Invoice No', 'Invoice Date', 'Invoice Value', 'Place Of Supply', 'Product', 'HSN', 'Qty', 'Taxable Value', 'GST %', 'IGST', 'CGST', 'SGST'],
      rows: rows,
    );
  }

  Future<String> _exportCsv(ReportTable table, String fileName) async {
    final chart = _chartFromTable(table);
    final rows = <List<Object?>>[table.headers, ...table.rows];
    if (chart != null) {
      rows.add([]);
      rows.add(['Generated Chart', chart.title]);
      rows.add(['Metric', 'Value']);
      rows.addAll(chart.points.map((point) => [point.label, point.value]));
    }
    final csv = const ListToCsvConverter().convert(rows);
    return _saveBytes(utf8.encode(csv), fileName, 'text/csv');
  }

  Future<String> _exportXlsx(ReportTable table, String fileName) async {
    final companyInfo = await _companyReportInfo();
    final excel = Excel.createExcel();
    final sheetName = table.title.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    final targetSheetName = sheetName.isEmpty ? 'Report' : sheetName;
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, targetSheetName);
    }
    final sheet = excel[targetSheetName];

    _appendXlsxRow(sheet, [companyInfo.name]);
    _appendXlsxRow(sheet, ['GSTIN', companyInfo.gstin]);
    _appendXlsxRow(sheet, ['Address', companyInfo.address]);
    _appendXlsxRow(sheet, ['Phone', companyInfo.phone, 'Email', companyInfo.email]);
    _appendXlsxRow(sheet, ['Report', table.title]);
    _appendXlsxRow(sheet, ['Period', table.subtitle]);
    _appendXlsxRow(sheet, const <Object?>[]);

    const tableHeaderRowIndex = 7;
    _appendXlsxRow(sheet, table.headers);
    for (final row in table.rows) {
      _appendXlsxRow(sheet, row.map((value) => value ?? ''));
    }

    _applyReadableXlsxLayout(sheet, table, headerRowIndex: tableHeaderRowIndex);
    _appendXlsxChartSheet(excel, table);

    final encodedBytes = excel.encode();
    if (encodedBytes == null || encodedBytes.isEmpty) {
      throw StateError('Could not create XLSX file');
    }
    final bytes = List<int>.from(encodedBytes, growable: true);
    if (!_looksLikeXlsxPackage(bytes)) {
      throw StateError('Could not create a valid XLSX file');
    }
    return _saveBytes(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  void _appendXlsxRow(Sheet sheet, Iterable<Object?> row) {
    // The excel package can mutate the supplied row during write. Use a fresh
    // growable copy so const/static header lists never crash XLSX export.
    sheet.appendRow(List<Object?>.from(row, growable: true));
  }

  void _appendXlsxChartSheet(Excel excel, ReportTable table) {
    final chart = _chartFromTable(table);
    if (chart == null || chart.points.isEmpty) return;

    final chartSheet = excel['Charts'];
    _appendXlsxRow(chartSheet, [table.title]);
    _appendXlsxRow(chartSheet, [table.subtitle]);
    _appendXlsxRow(chartSheet, const <Object?>[]);
    _appendXlsxRow(chartSheet, ['Generated Chart', chart.title]);
    _appendXlsxRow(chartSheet, ['Metric', 'Value', 'Visual Bar']);

    final maxValue = chart.points.fold<double>(0, (max, point) => point.value > max ? point.value : max);
    for (final point in chart.points) {
      _appendXlsxRow(chartSheet, [point.label, point.value, _xlsxChartBar(point.value, maxValue)]);
    }

    chartSheet.setColWidth(0, 28);
    chartSheet.setColWidth(1, 18);
    chartSheet.setColWidth(2, 42);
    for (var i = 0; i < 5 + chart.points.length; i++) {
      for (var c = 0; c < 3; c++) {
        chartSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i)).cellStyle = CellStyle(textWrapping: TextWrapping.WrapText);
      }
    }
    for (var c = 0; c < 3; c++) {
      chartSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4)).cellStyle = CellStyle(bold: true, textWrapping: TextWrapping.WrapText);
    }
  }

  String _xlsxChartBar(double value, double maxValue) {
    if (value <= 0 || maxValue <= 0) return '';
    final blocks = ((value / maxValue) * 28).clamp(1, 28).round();
    return List.filled(blocks, '█').join();
  }

  void _applyReadableXlsxLayout(Sheet sheet, ReportTable table, {int headerRowIndex = 0}) {
    final headerStyle = CellStyle(
      bold: true,
      textWrapping: TextWrapping.WrapText,
    );
    final bodyStyle = CellStyle(
      textWrapping: TextWrapping.WrapText,
    );

    for (var columnIndex = 0; columnIndex < table.headers.length; columnIndex++) {
      sheet.setColWidth(columnIndex, _columnWidthFor(table, columnIndex));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: headerRowIndex)).cellStyle = headerStyle;
      for (var rowIndex = headerRowIndex + 1; rowIndex <= headerRowIndex + table.rows.length; rowIndex++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = bodyStyle;
      }
    }

    for (var rowIndex = 0; rowIndex < headerRowIndex - 1; rowIndex++) {
      for (var columnIndex = 0; columnIndex < 4; columnIndex++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle =
            rowIndex == 0 ? CellStyle(bold: true, textWrapping: TextWrapping.WrapText) : bodyStyle;
      }
    }
  }

  double _columnWidthFor(ReportTable table, int columnIndex) {
    final header = table.headers[columnIndex];
    var maxLength = header.length;

    for (final row in table.rows) {
      if (columnIndex >= row.length) continue;
      final value = row[columnIndex];
      final length = value == null ? 0 : value.toString().length;
      if (length > maxLength) maxLength = length;
    }

    var width = (maxLength + 2).toDouble();
    final headerKey = header.toLowerCase();

    if (headerKey.contains('product') || headerKey.contains('address') || headerKey.contains('note') || headerKey.contains('reason')) {
      width = width.clamp(28.0, 52.0).toDouble();
    } else if (headerKey.contains('invoice') || headerKey.contains('batch') || headerKey.contains('return id') || headerKey.contains('order id')) {
      width = width.clamp(18.0, 38.0).toDouble();
    } else if (headerKey.contains('gstin')) {
      width = width.clamp(18.0, 22.0).toDouble();
    } else if (headerKey.contains('date')) {
      width = width.clamp(13.0, 16.0).toDouble();
    } else if (headerKey.contains('amount') || headerKey.contains('total') || headerKey.contains('value') || headerKey.contains('price') || headerKey.contains('paid') || headerKey.contains('due') || headerKey.contains('gst')) {
      width = width.clamp(13.0, 18.0).toDouble();
    } else {
      width = width.clamp(10.0, 28.0).toDouble();
    }

    return width;
  }

  Future<String> _exportPdf(ReportTable table, String fileName) async {
    final font = pw.Font.helvetica();
    final pdf = pw.Document();
    final totals = _numericTotals(table);
    final chart = _chartFromTable(table);
    final companyInfo = await _companyReportInfo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyInfo.name, style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.SizedBox(height: 2),
                  pw.Text(table.title, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.SizedBox(height: 2),
                  pw.Text(table.subtitle, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  if (companyInfo.gstin.isNotEmpty) pw.Text('GSTIN: ${companyInfo.gstin}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  if (companyInfo.address.isNotEmpty) pw.Text(companyInfo.address, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  if (companyInfo.contactLine.isNotEmpty) pw.Text(companyInfo.contactLine, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Text('Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          if (totals.isNotEmpty) _pdfTotals(totals, font),
          if (totals.isNotEmpty) pw.SizedBox(height: 10),
          if (chart != null) _pdfChart(chart, font),
          if (chart != null) pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: table.headers,
            data: table.rows.map((row) => row.map(_pdfCell).toList()).toList(),
            headerStyle: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: pw.TextStyle(font: font, fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
    return 'PDF generated: $fileName';
  }

  pw.Widget _pdfChart(ReportChartData chart, pw.Font font) {
    final maxValue = chart.points.fold<double>(0, (max, point) => point.value > max ? point.value : max);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(chart.title, style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 8),
          ...chart.points.map((point) {
            final ratio = maxValue <= 0 ? 0.0 : (point.value / maxValue).clamp(0.0, 1.0).toDouble();
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 110, child: pw.Text(point.label, style: pw.TextStyle(font: font, fontSize: 8))),
                  pw.SizedBox(
                    width: 220,
                    child: pw.Stack(
                      children: [
                        pw.Container(width: 220, height: 9, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(5))),
                        pw.Container(width: 220 * ratio, height: 9, decoration: pw.BoxDecoration(color: PdfColors.indigo600, borderRadius: pw.BorderRadius.circular(5))),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 70, child: pw.Text(_money.format(point.value), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _pdfTotals(Map<String, double> totals, pw.Font font) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: totals.entries.map((entry) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(5)),
          child: pw.Text('${entry.key}: ${_money.format(entry.value)}', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        );
      }).toList(),
    );
  }

  ReportChartData? _chartFromTable(ReportTable table) {
    final totals = _numericTotals(table);
    if (totals.isEmpty) return null;
    final points = totals.entries
        .where((entry) => entry.value.abs() > 0)
        .map((entry) => ReportChartPoint(entry.key, entry.value.abs()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (points.isEmpty) return null;
    return ReportChartData('${table.title} - generated summary chart', points.take(8).toList());
  }

  Map<String, double> _numericTotals(ReportTable table) {
    final totals = <String, double>{};
    for (var columnIndex = 0; columnIndex < table.headers.length; columnIndex++) {
      double total = 0;
      var numericCount = 0;
      for (final row in table.rows) {
        if (columnIndex >= row.length) continue;
        final value = row[columnIndex];
        if (value is num) {
          total += value.toDouble();
          numericCount++;
        }
      }
      final headerKey = table.headers[columnIndex].toLowerCase();
      final isUsefulNumeric = headerKey.contains(RegExp(r'amount|total|paid|due|gst|taxable|value|receivable|expense|refund|return'));
      final isPercent = headerKey.contains('%') || headerKey.contains('percent');
      final isUnitPrice = headerKey.contains('unit purchase price') || headerKey.contains('purchase price') || headerKey.contains('selling price') || headerKey == 'new pos price';
      if (numericCount > 0 && isUsefulNumeric && !isPercent && !isUnitPrice) {
        totals[table.headers[columnIndex]] = total;
      }
    }
    return totals;
  }


  bool _looksLikeXlsxPackage(List<int> bytes) {
    return bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  }

  Future<String> _saveBytes(List<int> bytes, String fileName, String mimeType) async {
    if (bytes.isEmpty) {
      throw StateError('Cannot save an empty export file');
    }

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      await Future<void>.delayed(const Duration(seconds: 2));
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded $fileName';
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


  Future<_CompanyReportInfo> _companyReportInfo() async {
    try {
      final box = Hive.isBoxOpen('companyBox')
          ? Hive.box('companyBox')
          : await Hive.openBox('companyBox');
      return _CompanyReportInfo(
        name: _boxText(box, 'companyName', 'SalesVista'),
        gstin: _boxText(box, 'companyGst', ''),
        address: _boxText(box, 'companyAddress', ''),
        phone: _boxText(box, 'companyPhone', ''),
        email: _boxText(box, 'companyEmail', ''),
      );
    } catch (_) {
      return const _CompanyReportInfo(
        name: 'SalesVista',
        gstin: '',
        address: '',
        phone: '',
        email: '',
      );
    }
  }

  String _boxText(Box box, String key, String fallback) {
    final value = box.get(key, defaultValue: fallback);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Iterable<T> _filterDates<T>(Iterable<T> values, DateTime Function(T value) dateOf, DateTime? from, DateTime? to) {
    final start = from == null ? null : DateTime(from.year, from.month, from.day);
    final end = to == null ? null : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return values.where((item) {
      final date = dateOf(item);
      if (start != null && date.isBefore(start)) return false;
      if (end != null && date.isAfter(end)) return false;
      return true;
    });
  }

  String _periodLabel(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'All dates';
    if (from != null && to != null) return '${_date.format(from)} to ${_date.format(to)}';
    if (from != null) return 'From ${_date.format(from)}';
    return 'Up to ${_date.format(to!)}';
  }

  String _pdfCell(Object? value) {
    if (value is DateTime) return _date.format(value);
    if (value is num) return value.toStringAsFixed(2);
    return value?.toString() ?? '';
  }
}

class _CompanyReportInfo {
  final String name;
  final String gstin;
  final String address;
  final String phone;
  final String email;

  const _CompanyReportInfo({
    required this.name,
    required this.gstin,
    required this.address,
    required this.phone,
    required this.email,
  });

  String get contactLine {
    final parts = <String>[
      if (phone.trim().isNotEmpty) 'Phone: $phone',
      if (email.trim().isNotEmpty) 'Email: $email',
    ];
    return parts.join(' • ');
  }
}

class ReportTable {
  final String title;
  final String fileStem;
  final String subtitle;
  final List<String> headers;
  final List<List<Object?>> rows;

  const ReportTable({
    required this.title,
    required this.fileStem,
    required this.subtitle,
    required this.headers,
    required this.rows,
  });
}

class ReportChartData {
  final String title;
  final List<ReportChartPoint> points;

  const ReportChartData(this.title, this.points);
}

class ReportChartPoint {
  final String label;
  final double value;

  const ReportChartPoint(this.label, this.value);
}
