// import 'dart:typed_data';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:html' as html;

// import 'package:flutter/services.dart' show rootBundle;
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';

// import '../phase_2_models/order_model.dart';
// import '../phase_2_models/invoice_model.dart';

// class PdfService {
//   /// ================= FONT LOADER =================
//   static Future<pw.Font> _loadFont() async {
//     final fontData =
//         await rootBundle.load("assets/fonts/NotoSans-VariableFont_wdth,wght.ttf");
//     return pw.Font.ttf(fontData);
//   }

//   /// ================= PUBLIC METHODS =================

//   /// Generate PDF for OrderModel
//   static Future<void> generateOrderInvoicePdf(
//     OrderModel order, {
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   }) async {
//     final font = await _loadFont();
//     final pdf = await _buildPdfFromOrder(
//       order,
//       font,
//       logoBytes,
//       signatureBytes ?? order.signatureBytes, // fallback to model
//     );
//     await _saveOrPrintPdf(pdf, "invoice_${order.id}.pdf");
//   }

//   /// Generate PDF for InvoiceModel
//   static Future<void> generateInvoiceModelPdf(
//     InvoiceModel invoice, {
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   }) async {
//     final font = await _loadFont();
//     final pdf = await _buildPdfFromInvoice(
//       invoice,
//       font,
//       logoBytes,
//       signatureBytes ?? invoice.signatureBytes,
//     );
//     await _saveOrPrintPdf(pdf, "invoice_${invoice.id}.pdf");
//   }

//   /// Preview PDF for Order
//   static Future<pw.Document> buildOrderPdfForPreview(
//     OrderModel order, {
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   }) async {
//     final font = await _loadFont();
//     return _buildPdfFromOrder(order, font, logoBytes, signatureBytes ?? order.signatureBytes);
//   }

//   /// Preview PDF for Invoice
//   static Future<pw.Document> buildInvoicePdfForPreview(
//     InvoiceModel invoice, {
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   }) async {
//     final font = await _loadFont();
//     return _buildPdfFromInvoice(invoice, font, logoBytes, signatureBytes ?? invoice.signatureBytes);
//   }

//   /// ================= PDF BUILDERS =================

//   static Future<pw.Document> _buildPdfFromOrder(
//     OrderModel order,
//     pw.Font font,
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   ) async {
//     final quantity = order.quantity;
//     final subtotal = order.totalAmount;
//     final unitPrice = quantity != 0 ? subtotal / quantity : 0.0;

//     final pdf = pw.Document();

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(24),
//         build: (context) => [
//           _header(font, logoBytes),
//           pw.SizedBox(height: 20),
//           _billInfo(order.customerName, order.id, order.date, font),
//           pw.SizedBox(height: 20),
//           _productTable(
//             productName: order.productName,
//             unitPrice: unitPrice,
//             quantity: quantity,
//             subtotal: subtotal,
//             font: font,
//           ),
//           pw.SizedBox(height: 20),
//           _totalBox(subtotal, order.paid, order.due, subtotal, font),
//           pw.SizedBox(height: 40),
//           _signature(font, signatureBytes),
//         ],
//       ),
//     );

//     return pdf;
//   }

//   static Future<pw.Document> _buildPdfFromInvoice(
//     InvoiceModel invoice,
//     pw.Font font,
//     Uint8List? logoBytes,
//     Uint8List? signatureBytes,
//   ) async {
//     final quantity = invoice.quantity;
//     final subtotal = invoice.amount;
//     final unitPrice = quantity != 0 ? subtotal / quantity : 0.0;

//     final pdf = pw.Document();

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(24),
//         build: (context) => [
//           _header(font, logoBytes),
//           pw.SizedBox(height: 20),
//           _billInfo(invoice.customerName, invoice.id, invoice.date, font),
//           pw.SizedBox(height: 20),
//           _productTable(
//             productName: invoice.safeProductName,
//             unitPrice: unitPrice,
//             quantity: quantity,
//             subtotal: subtotal,
//             font: font,
//           ),
//           pw.SizedBox(height: 20),
//           _totalBox(subtotal, invoice.paid, invoice.due, subtotal, font),
//           pw.SizedBox(height: 40),
//           _signature(font, signatureBytes),
//         ],
//       ),
//     );

//     return pdf;
//   }

//   /// ================= HEADER =================
//   static pw.Widget _header(pw.Font font, Uint8List? logoBytes) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.indigo,
//         borderRadius: pw.BorderRadius.circular(6),
//       ),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           logoBytes != null
//               ? pw.Image(pw.MemoryImage(logoBytes), height: 40)
//               : pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.start,
//                   children: [
//                     pw.Text("SalesVista", style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
//                     pw.Text("support@salesvista.com", style: pw.TextStyle(font: font, color: PdfColors.white)),
//                     pw.Text("www.salesvista.com", style: pw.TextStyle(font: font, color: PdfColors.white)),
//                   ],
//                 ),
//           pw.Text("INVOICE", style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   /// ================= SIGNATURE =================
//   static pw.Widget _signature(pw.Font font, Uint8List? signatureBytes) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//       children: [
//         pw.Text("Thank you for your business!", style: pw.TextStyle(font: font)),
//         signatureBytes != null
//             ? pw.Image(pw.MemoryImage(signatureBytes), height: 50)
//             : pw.Column(
//                 children: [
//                   pw.Container(width: 120, height: 1, color: PdfColors.grey),
//                   pw.SizedBox(height: 4),
//                   pw.Text("Authorized Signature", style: pw.TextStyle(font: font)),
//                 ],
//               ),
//       ],
//     );
//   }

//   /// ================= BILL INFO =================
//   static pw.Widget _billInfo(String customerName, dynamic invoiceId, DateTime date, pw.Font font) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//       children: [
//         pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             pw.Text("Invoice To:", style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
//             pw.Text(customerName, style: pw.TextStyle(font: font)),
//           ],
//         ),
//         pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           children: [
//             pw.Text("Invoice #: $invoiceId", style: pw.TextStyle(font: font)),
//             pw.Text("Date: ${DateFormat.yMMMd().format(date)}", style: pw.TextStyle(font: font)),
//           ],
//         ),
//       ],
//     );
//   }

//   /// ================= PRODUCT TABLE =================
//   static pw.Widget _productTable({
//     required String productName,
//     required double unitPrice,
//     required double quantity,
//     required double subtotal,
//     required pw.Font font,
//   }) {
//     return pw.Table.fromTextArray(
//       headers: ['SL', 'Description', 'Unit Price', 'Qty', 'Total'],
//       data: [
//         ['1', productName, unitPrice.toStringAsFixed(2), quantity.toStringAsFixed(2), subtotal.toStringAsFixed(2)],
//       ],
//       headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
//       headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
//       cellStyle: pw.TextStyle(font: font),
//       border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
//     );
//   }

//   /// ================= TOTAL BOX =================
//   static pw.Widget _totalBox(double subtotal, double paid, double due, double finalTotal, pw.Font font) {
//     return pw.Align(
//       alignment: pw.Alignment.centerRight,
//       child: pw.Container(
//         width: 220,
//         padding: const pw.EdgeInsets.all(12),
//         decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             _totalRow("Subtotal", subtotal.toStringAsFixed(2), font),
//             _totalRow("Paid", paid.toStringAsFixed(2), font),
//             _totalRow("Due", due.toStringAsFixed(2), font),
//             pw.Divider(),
//             _totalRow("Total", finalTotal.toStringAsFixed(2), font, isBold: true),
//           ],
//         ),
//       ),
//     );
//   }

//   static pw.Widget _totalRow(String title, String value, pw.Font font, {bool isBold = false}) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//       children: [
//         pw.Text(title, style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
//         pw.Text("₹$value", style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
//       ],
//     );
//   }

//   /// ================= SAVE / PRINT =================
//   static Future<void> _saveOrPrintPdf(pw.Document pdf, String fileName) async {
//     final bytes = await pdf.save();

//     if (kIsWeb) {
//       final blob = html.Blob([bytes], 'application/pdf');
//       final url = html.Url.createObjectUrlFromBlob(blob);
//       final anchor = html.AnchorElement(href: url)
//         ..setAttribute("download", fileName)
//         ..click();
//       html.Url.revokeObjectUrl(url);
//     } else {
//       await Printing.layoutPdf(onLayout: (format) async => bytes);
//     }
//   }
// }