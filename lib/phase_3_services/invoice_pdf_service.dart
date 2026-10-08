import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';

class PdfService {
  static const double _b2cLargeThreshold = 100000.0;

  // Walk-in/customer-counter bills use an 80mm thermal receipt width.
  // The receipt height is calculated from the invoice content so the paper
  // setup opens at the right size without manual adjustment for every bill.
  static const double _walkInPaperWidthMm = 80.0;
  static const double _walkInMinPaperHeightMm = 120.0;
  static const double _walkInMaxPaperHeightMm = 900.0;
  static const double _walkInMarginHorizontalMm = 4.0;
  static const double _walkInMarginVerticalMm = 4.0;

  static pw.Font? _cachedFont;

  static Future<pw.Font> _loadFont() async {
    _cachedFont ??= pw.Font.helvetica();
    return _cachedFont!;
  }

  static Future<void> generateOrderInvoicePdf(
    OrderModel order, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final pdf = await buildOrderPdfForPreview(
      order,
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );
    await _saveOrPrintPdf(pdf, 'invoice_${order.id}.pdf');
  }

  static Future<void> generateInvoiceModelPdf(
    InvoiceModel invoice, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final pdf = await buildInvoicePdfForPreview(
      invoice,
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );
    await _saveOrPrintPdf(pdf, 'invoice_${invoice.id}.pdf');
  }

  /// Opens the system print dialog directly. The generated layout is selected
  /// automatically: compact retail receipt for walk-in/small B2C invoices and
  /// full GST tax invoice for B2B or large B2C invoices.
  static Future<void> printInvoiceModel(
    InvoiceModel invoice, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final companyBox = await Hive.openBox('companyBox');
    final company = _companyInfo(companyBox: companyBox);
    final isReceipt = _isCompactRetailReceipt(invoice, company.stateCode);
    final printFormat = isReceipt ? _walkInReceiptPageFormat(invoice) : PdfPageFormat.a4;

    await Printing.layoutPdf(
      name: isReceipt ? 'receipt_${invoice.id}.pdf' : 'invoice_${invoice.id}.pdf',
      format: printFormat,
      dynamicLayout: isReceipt,
      usePrinterSettings: false,
      onLayout: (_) async {
        final pdf = await buildInvoicePdfForPreview(
          invoice,
          logoBytes: logoBytes,
          signatureBytes: signatureBytes,
        );
        return pdf.save();
      },
    );
  }

  static Future<pw.Document> buildOrderPdfForPreview(
    OrderModel order, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');
    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ?? order.signatureBytes ?? companyBox.get('signatureBytes') as Uint8List?;

    final item = InvoiceLineItem(
      orderId: order.id,
      productId: order.salesId ?? '',
      productName: order.productName,
      hsn: '',
      quantity: order.quantity,
      unitPrice: order.quantity == 0 ? 0 : order.totalAmount / order.quantity,
      gstPercent: order.isGstEnabled ? order.gstPercent : 0,
    );

    final invoice = InvoiceModel(
      id: order.id,
      saleId: order.salesId ?? '',
      customerName: order.customerName,
      amount: order.subtotal,
      date: order.date,
      productName: order.productName,
      quantity: order.quantity,
      unitPrice: item.unitPrice,
      orderId: order.id,
      paidAmount: order.paid,
      dueAmount: order.due,
      signatureBytes: storedSignature,
      isGstEnabled: order.isGstEnabled,
      gstPercent: item.gstPercent,
      lineItems: [item.toJson()],
      paymentMode: 'Cash',
    );

    final company = _companyInfo(companyBox: companyBox);
    final useReceipt = _isCompactRetailReceipt(invoice, company.stateCode);

    if (useReceipt) {
      return _buildWalkInReceiptPdf(
        invoice,
        font: font,
        company: company,
      );
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(font, storedLogo, company),
          pw.SizedBox(height: 18),
          _billInfo(
            customerName: order.customerName,
            invoiceId: order.id,
            date: order.date,
            font: font,
          ),
          pw.SizedBox(height: 18),
          _itemsTable([item], font),
          pw.SizedBox(height: 18),
          _totalBox(
            subtotal: order.subtotal,
            gstAmount: order.gstAmount,
            discount: 0,
            paid: order.paid,
            due: order.due,
            finalTotal: order.grandTotal,
            igst: 0,
            cgst: order.gstAmount / 2,
            sgst: order.gstAmount / 2,
            font: font,
          ),
          pw.SizedBox(height: 40),
          _signature(font, storedSignature),
        ],
      ),
    );
    return pdf;
  }

  static Future<pw.Document> buildInvoicePdfForPreview(
    InvoiceModel invoice, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final font = await _loadFont();
    final companyBox = await Hive.openBox('companyBox');
    final storedLogo = logoBytes ?? companyBox.get('logoBytes') as Uint8List?;
    final storedSignature = signatureBytes ?? invoice.signatureBytes ?? companyBox.get('signatureBytes') as Uint8List?;
    final company = _companyInfo(companyBox: companyBox);

    if (_isCompactRetailReceipt(invoice, company.stateCode)) {
      return _buildWalkInReceiptPdf(
        invoice,
        font: font,
        company: company,
      );
    }

    return _buildGstTaxInvoicePdf(
      invoice,
      font: font,
      company: company,
      logoBytes: storedLogo,
      signatureBytes: storedSignature,
    );
  }

  static pw.Document _buildGstTaxInvoicePdf(
    InvoiceModel invoice, {
    required pw.Font font,
    required _InvoiceCompanyInfo company,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(font, logoBytes, company),
          pw.SizedBox(height: 18),
          _billInfo(
            customerName: invoice.customerName,
            invoiceId: invoice.id,
            date: invoice.date,
            font: font,
            buyerGstin: invoice.buyerGstin,
            placeOfSupply: invoice.placeOfSupply,
            paymentMode: invoice.paymentMode,
          ),
          pw.SizedBox(height: 18),
          _itemsTable(invoice.items, font),
          pw.SizedBox(height: 18),
          _totalBox(
            subtotal: invoice.subtotal,
            gstAmount: invoice.gstAmount,
            discount: invoice.discountAmount,
            paid: invoice.paid,
            due: invoice.due,
            finalTotal: invoice.grandTotal,
            igst: invoice.igst,
            cgst: invoice.cgst,
            sgst: invoice.sgst,
            font: font,
          ),
          pw.SizedBox(height: 40),
          _signature(font, signatureBytes),
        ],
      ),
    );
    return pdf;
  }

  static pw.Document _buildWalkInReceiptPdf(
    InvoiceModel invoice, {
    required pw.Font font,
    required _InvoiceCompanyInfo company,
  }) {
    final receiptFormat = _walkInReceiptPageFormat(invoice);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: receiptFormat,
        margin: pw.EdgeInsets.symmetric(
          horizontal: _walkInMarginHorizontalMm * PdfPageFormat.mm,
          vertical: _walkInMarginVerticalMm * PdfPageFormat.mm,
        ),
        build: (_) => [
          _retailReceiptHeader(invoice, company, font),
          _receiptRule(),
          _retailReceiptMeta(invoice, company, font),
          _receiptRule(),
          _retailReceiptItems(invoice, font),
          _receiptRule(),
          _retailReceiptTotals(invoice, font),
          if (invoice.gstAmount > 0) ...[
            _receiptRule(),
            _retailReceiptTaxSummary(invoice, font),
          ],
          _receiptRule(),
          _retailReceiptFooter(invoice, font),
        ],
      ),
    );
    return pdf;
  }

  static PdfPageFormat _walkInReceiptPageFormat(InvoiceModel invoice) {
    final heightMm = _estimateWalkInReceiptHeightMm(invoice)
        .clamp(_walkInMinPaperHeightMm, _walkInMaxPaperHeightMm)
        .toDouble();

    return PdfPageFormat(
      _walkInPaperWidthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 0,
    );
  }

  static double _estimateWalkInReceiptHeightMm(InvoiceModel invoice) {
    final company = _companyInfo();
    final companyAddressLines = company.address.trim().isEmpty ? 0 : (company.address.trim().length / 34).ceil();
    final companyContactLines = company.phone.trim().isEmpty && company.email.trim().isEmpty ? 0 : 1;
    final companyGstinLines = company.gstin.trim().isEmpty ? 0 : 1;

    final headerMm = 22.0 + (companyAddressLines * 4.0) + (companyContactLines * 4.0) + (companyGstinLines * 4.0);
    const metaMm = 24.0;
    const tableHeaderMm = 8.0;

    var itemRowsMm = 0.0;
    for (final item in invoice.items) {
      final nameLines = (_receiptSafe(item.productName, max: 33).length / 33).ceil().clamp(1, 3).toInt();
      itemRowsMm += 8.5 + ((nameLines - 1) * 4.0);
    }

    var totalsRows = 4; // total qty, taxable, grand total, paid.
    if (invoice.discountAmount > 0) totalsRows += 1;
    if (invoice.igst > 0) totalsRows += 1;
    if (invoice.cgst > 0) totalsRows += 1;
    if (invoice.sgst > 0) totalsRows += 1;
    if (invoice.gstAmount > 0 && invoice.igst == 0 && invoice.cgst == 0 && invoice.sgst == 0) totalsRows += 1;
    if (invoice.due > 0) totalsRows += 1;
    final totalsMm = 10.0 + (totalsRows * 4.2);

    var taxSummaryMm = 0.0;
    if (invoice.gstAmount > 0) {
      final rates = invoice.items.map((item) => item.gstPercent).toSet().length;
      taxSummaryMm = 12.0 + (rates * 4.0);
    }

    const rulesMm = 26.0;
    const footerMm = 28.0;
    const safetyMm = 22.0;

    return headerMm + metaMm + tableHeaderMm + itemRowsMm + totalsMm + taxSummaryMm + rulesMm + footerMm + safetyMm;
  }

  static pw.Widget _retailReceiptHeader(
    InvoiceModel invoice,
    _InvoiceCompanyInfo company,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          company.name.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (company.address.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              company.address,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 6.8),
            ),
          ),
        if (company.phone.isNotEmpty || company.email.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              [company.phone, company.email].where((value) => value.trim().isNotEmpty).join(' | '),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 6.5),
            ),
          ),
        if (company.gstin.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'GSTIN: ${company.gstin}',
              style: pw.TextStyle(font: font, fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.7),
          ),
          child: pw.Text(
            invoice.isGstEnabled ? 'TAX INVOICE / RETAIL RECEIPT' : 'RETAIL RECEIPT',
            style: pw.TextStyle(font: font, fontSize: 8.2, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _retailReceiptMeta(
    InvoiceModel invoice,
    _InvoiceCompanyInfo company,
    pw.Font font,
  ) {
    final date = DateFormat('dd/MM/yyyy').format(invoice.date);
    final time = DateFormat('hh:mm a').format(invoice.date);
    final customer = invoice.customerName.trim().isEmpty ? 'Walk-in Customer' : invoice.customerName.trim();

    return pw.Column(
      children: [
        _receiptTextRow('Bill No', invoice.id, font, boldValue: true),
        _receiptTextRow('Date', '$date   Time: $time', font),
        _receiptTextRow('Customer', customer, font),
        if (invoice.paymentMode.trim().isNotEmpty) _receiptTextRow('Payment', invoice.paymentMode, font),
        if (company.stateCode.isNotEmpty) _receiptTextRow('State Code', company.stateCode, font),
      ],
    );
  }

  static pw.Widget _retailReceiptItems(InvoiceModel invoice, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              flex: 42,
              child: pw.Text('PARTICULARS', style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 16,
              child: pw.Text('QTY', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 18,
              child: pw.Text('RATE', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 24,
              child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        ...invoice.items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final gstText = item.gstPercent > 0 ? 'GST ${item.gstPercent.toStringAsFixed(0)}%' : 'GST 0%';
          final hsnText = item.hsn.trim().isEmpty ? '' : 'HSN ${item.hsn.trim()}';

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$index. ${_receiptSafe(item.productName, max: 33)}',
                  style: pw.TextStyle(font: font, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 1),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 42,
                      child: pw.Text(
                        [hsnText, gstText].where((value) => value.isNotEmpty).join(' | '),
                        style: pw.TextStyle(font: font, fontSize: 5.9, color: PdfColors.grey700),
                      ),
                    ),
                    pw.Expanded(
                      flex: 16,
                      child: pw.Text(_qtyText(item.quantity), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8)),
                    ),
                    pw.Expanded(
                      flex: 18,
                      child: pw.Text(item.unitPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8)),
                    ),
                    pw.Expanded(
                      flex: 24,
                      child: pw.Text(item.lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _retailReceiptTotals(InvoiceModel invoice, pw.Font font) {
    return pw.Column(
      children: [
        _receiptAmountRow('Total Qty', invoice.totalQuantity, font, decimals: 2),
        _receiptAmountRow('Taxable Value', invoice.subtotal, font),
        if (invoice.discountAmount > 0) _receiptAmountRow('Discount', -invoice.discountAmount, font),
        if (invoice.igst > 0) _receiptAmountRow('IGST', invoice.igst, font),
        if (invoice.cgst > 0) _receiptAmountRow('CGST', invoice.cgst, font),
        if (invoice.sgst > 0) _receiptAmountRow('SGST', invoice.sgst, font),
        if (invoice.gstAmount > 0 && invoice.igst == 0 && invoice.cgst == 0 && invoice.sgst == 0) _receiptAmountRow('GST', invoice.gstAmount, font),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: _receiptAmountRow('GRAND TOTAL', invoice.grandTotal, font, bold: true, fontSize: 9.2),
        ),
        pw.SizedBox(height: 2),
        _receiptAmountRow('Paid', invoice.paid, font),
        _receiptAmountRow('Balance Due', invoice.due, font, bold: invoice.due > 0),
      ],
    );
  }

  static pw.Widget _retailReceiptTaxSummary(InvoiceModel invoice, pw.Font font) {
    final byRate = <double, _ReceiptTaxBucket>{};
    for (final item in invoice.items) {
      final bucket = byRate.putIfAbsent(item.gstPercent, () => _ReceiptTaxBucket());
      bucket.taxable += item.taxableValue;
      bucket.tax += item.gstAmount;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GST SUMMARY', style: pw.TextStyle(font: font, fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.Expanded(child: pw.Text('Rate', style: pw.TextStyle(font: font, fontSize: 6.2, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text('Taxable', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.2, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text('Tax', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.2, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...byRate.entries.map((entry) {
          return pw.Row(
            children: [
              pw.Expanded(child: pw.Text('${entry.key.toStringAsFixed(0)}%', style: pw.TextStyle(font: font, fontSize: 6.2))),
              pw.Expanded(child: pw.Text(entry.value.taxable.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.2))),
              pw.Expanded(child: pw.Text(entry.value.tax.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 6.2))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _retailReceiptFooter(InvoiceModel invoice, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Items sold: ${invoice.itemCount}', style: pw.TextStyle(font: font, fontSize: 6.6)),
        pw.SizedBox(height: 6),
        pw.Text('THANK YOU FOR SHOPPING WITH US', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 7.8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text('Please retain this bill for exchange / warranty / accounting.', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 6.1)),
        pw.SizedBox(height: 8),
        pw.Text('Powered by SalesVista POS', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 5.8, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _receiptRule() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Container(height: 0.6, color: PdfColors.grey700),
    );
  }

  static pw.Widget _receiptTextRow(String label, String value, pw.Font font, {bool boldValue = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 44, child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 6.8, color: PdfColors.grey800))),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: font, fontSize: 6.8, fontWeight: boldValue ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _receiptAmountRow(
    String label,
    double value,
    pw.Font font, {
    bool bold = false,
    int decimals = 2,
    double fontSize = 7.1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(
            decimals == 0 ? value.toStringAsFixed(0) : _money(value),
            style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static pw.Widget _header(pw.Font font, Uint8List? logoBytes, _InvoiceCompanyInfo company) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: PdfColors.indigo, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          logoBytes != null
              ? pw.Image(pw.MemoryImage(logoBytes), height: 50)
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(company.name, style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Professional POS Invoice', style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 11)),
                  ],
                ),
          pw.Text('TAX INVOICE', style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _billInfo({
    required String customerName,
    required String invoiceId,
    required DateTime date,
    required pw.Font font,
    String? buyerGstin,
    String? placeOfSupply,
    String paymentMode = '',
  }) {
    final company = _companyInfo();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('Seller', font),
              pw.Text(company.name, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
              if (company.address.isNotEmpty) pw.Text(company.address, style: pw.TextStyle(font: font, fontSize: 10)),
              if (company.phone.isNotEmpty) pw.Text('Phone: ${company.phone}', style: pw.TextStyle(font: font, fontSize: 10)),
              if (company.gstin.isNotEmpty) pw.Text('GSTIN: ${company.gstin}', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(width: 22),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _sectionTitle('Buyer', font),
              pw.Text(customerName, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
              if ((buyerGstin ?? '').trim().isNotEmpty) pw.Text('GSTIN: $buyerGstin', style: pw.TextStyle(font: font, fontSize: 10)),
              if ((placeOfSupply ?? '').trim().isNotEmpty) pw.Text('POS: $placeOfSupply', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text('Invoice #: $invoiceId', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(date)}', style: pw.TextStyle(font: font, fontSize: 10)),
              if (paymentMode.trim().isNotEmpty) pw.Text('Payment: $paymentMode', style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: pw.TextStyle(font: font, color: PdfColors.indigo, fontWeight: pw.FontWeight.bold, fontSize: 11)),
    );
  }

  static pw.Widget _itemsTable(List<InvoiceLineItem> items, pw.Font font) {
    return pw.Table.fromTextArray(
      headers: const ['#', 'Product', 'HSN', 'Qty', 'Rate', 'GST %', 'Taxable', 'Tax', 'Total'],
      data: List.generate(items.length, (index) {
        final item = items[index];
        return [
          '${index + 1}',
          item.productName,
          item.hsn.isEmpty ? '-' : item.hsn,
          item.quantity.toStringAsFixed(2),
          item.unitPrice.toStringAsFixed(2),
          item.gstPercent.toStringAsFixed(0),
          item.taxableValue.toStringAsFixed(2),
          item.gstAmount.toStringAsFixed(2),
          item.lineTotal.toStringAsFixed(2),
        ];
      }),
      headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignment: pw.Alignment.centerRight,
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(2.4),
        2: const pw.FlexColumnWidth(0.8),
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
      },
      border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
    );
  }

  static pw.Widget _totalBox({
    required double subtotal,
    required double gstAmount,
    required double discount,
    required double paid,
    required double due,
    required double finalTotal,
    required double igst,
    required double cgst,
    required double sgst,
    required pw.Font font,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 245,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _totalRow('Taxable Value', subtotal, font),
            if (igst > 0) _totalRow('IGST', igst, font),
            if (cgst > 0) _totalRow('CGST', cgst, font),
            if (sgst > 0) _totalRow('SGST', sgst, font),
            if (gstAmount > 0 && igst == 0 && cgst == 0 && sgst == 0) _totalRow('GST', gstAmount, font),
            if (discount > 0) _totalRow('Discount', -discount, font),
            pw.Divider(),
            _totalRow('Grand Total', finalTotal, font, isBold: true),
            _totalRow('Paid', paid, font),
            _totalRow('Due', due, font, isBold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String title, double value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10)),
          pw.Text(_money(value), style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _signature(pw.Font font, Uint8List? signatureBytes) {
    const double lineWidth = 160;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('Thank you for your business!', style: pw.TextStyle(font: font)),
        pw.Container(
          width: lineWidth,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (signatureBytes != null)
                pw.Container(width: lineWidth, alignment: pw.Alignment.center, child: pw.Image(pw.MemoryImage(signatureBytes), height: 50, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 5),
              pw.Container(width: lineWidth, height: 1, color: PdfColors.grey),
              pw.SizedBox(height: 6),
              pw.Text('Authorized Signature', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font)),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isCompactRetailReceipt(InvoiceModel invoice, String companyStateCode) {
    final hasBuyerGstin = (invoice.buyerGstin ?? '').trim().isNotEmpty;
    if (hasBuyerGstin || invoice.invoiceType.trim().toUpperCase() == 'B2B') return false;

    final pos = invoice.placeOfSupply?.trim();
    final isInterState = pos != null && pos.isNotEmpty && pos != companyStateCode.trim();
    final isLargeB2c = isInterState && invoice.grandTotal > _b2cLargeThreshold;

    return !isLargeB2c;
  }

  static _InvoiceCompanyInfo _companyInfo({Box? companyBox}) {
    Box? box = companyBox;
    try {
      box ??= Hive.box('companyBox');
    } catch (_) {
      box = null;
    }

    String readCompany(String key, String fallback) {
      try {
        return box?.get(key, defaultValue: fallback)?.toString().trim() ?? fallback;
      } catch (_) {
        return fallback;
      }
    }

    String readSettings(String key, String fallback) {
      try {
        return Hive.box('settingsBox').get(key, defaultValue: fallback)?.toString().trim() ?? fallback;
      } catch (_) {
        return fallback;
      }
    }

    final gstin = readCompany('companyGst', readSettings('companyGst', ''));
    final stateFromGstin = _stateCodeFromGstin(gstin);

    return _InvoiceCompanyInfo(
      name: readCompany('companyName', readSettings('companyName', 'SalesVista')),
      address: readCompany('companyAddress', readSettings('companyAddress', '')),
      phone: readCompany('companyPhone', readSettings('companyPhone', '')),
      email: readCompany('companyEmail', readSettings('companyEmail', '')),
      gstin: gstin,
      stateCode: stateFromGstin ?? readSettings('companyStateCode', '24'),
    );
  }

  static String? _stateCodeFromGstin(String gstin) {
    final clean = gstin.trim();
    if (clean.length >= 2 && RegExp(r'^\d{2}').hasMatch(clean)) {
      return clean.substring(0, 2);
    }
    return null;
  }

  static String _receiptSafe(String value, {int max = 30}) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 3)}...';
  }

  static String _qtyText(double quantity) {
    if (quantity == quantity.roundToDouble()) return quantity.toStringAsFixed(0);
    return quantity.toStringAsFixed(2);
  }

  static String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  static Future<void> _saveOrPrintPdf(pw.Document pdf, String fileName) async {
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }
}

class _InvoiceCompanyInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String gstin;
  final String stateCode;

  const _InvoiceCompanyInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.stateCode,
  });
}

class _ReceiptTaxBucket {
  double taxable = 0.0;
  double tax = 0.0;
}
