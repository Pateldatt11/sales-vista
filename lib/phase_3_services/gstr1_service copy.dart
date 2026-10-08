// import 'dart:io';
// import 'dart:typed_data';

// import 'package:excel/excel.dart';
// import 'package:csv/csv.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';

// /// Replace this with your actual Sale model
// class SaleModel {
//   final String invoiceNo;
//   final DateTime date;
//   final String customerName;
//   final double taxableAmount;
//   final double cgst;
//   final double sgst;
//   final double igst;
//   final double totalAmount;

//   SaleModel({
//     required this.invoiceNo,
//     required this.date,
//     required this.customerName,
//     required this.taxableAmount,
//     required this.cgst,
//     required this.sgst,
//     required this.igst,
//     required this.totalAmount,
//   });
// }

// class Gstr1Service {
//   final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

//   // ===============================
//   // COMMON HELPERS
//   // ===============================

//   double getTotalTaxable(List<SaleModel> sales) =>
//       sales.fold(0, (sum, item) => sum + item.taxableAmount);

//   double getTotalCgst(List<SaleModel> sales) =>
//       sales.fold(0, (sum, item) => sum + item.cgst);

//   double getTotalSgst(List<SaleModel> sales) =>
//       sales.fold(0, (sum, item) => sum + item.sgst);

//   double getTotalIgst(List<SaleModel> sales) =>
//       sales.fold(0, (sum, item) => sum + item.igst);

//   double getGrandTotal(List<SaleModel> sales) =>
//       sales.fold(0, (sum, item) => sum + item.totalAmount);

//   Future<String> _getFilePath(String fileName) async {
//     final dir = await getApplicationDocumentsDirectory();
//     return "${dir.path}/$fileName";
//   }

//   // ===============================
//   // PDF EXPORT
//   // ===============================

//   Future<String> exportAsPdf(List<SaleModel> sales) async {
//     final pdf = pw.Document();

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (context) => [
//           pw.Text(
//             "GST R1 Statement",
//             style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 10),

//           pw.Table.fromTextArray(
//             headers: [
//               "Invoice No",
//               "Date",
//               "Customer",
//               "Taxable",
//               "CGST",
//               "SGST",
//               "IGST",
//               "Total"
//             ],
//             data: sales.map((sale) {
//               return [
//                 sale.invoiceNo,
//                 _dateFormat.format(sale.date),
//                 sale.customerName,
//                 sale.taxableAmount.toStringAsFixed(2),
//                 sale.cgst.toStringAsFixed(2),
//                 sale.sgst.toStringAsFixed(2),
//                 sale.igst.toStringAsFixed(2),
//                 sale.totalAmount.toStringAsFixed(2),
//               ];
//             }).toList(),
//           ),

//           pw.SizedBox(height: 20),

//           pw.Text("Summary",
//               style:
//                   pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
//           pw.SizedBox(height: 10),

//           pw.Text("Total Taxable: ₹${getTotalTaxable(sales).toStringAsFixed(2)}"),
//           pw.Text("Total CGST: ₹${getTotalCgst(sales).toStringAsFixed(2)}"),
//           pw.Text("Total SGST: ₹${getTotalSgst(sales).toStringAsFixed(2)}"),
//           pw.Text("Total IGST: ₹${getTotalIgst(sales).toStringAsFixed(2)}"),
//           pw.Text("Grand Total: ₹${getGrandTotal(sales).toStringAsFixed(2)}"),
//         ],
//       ),
//     );

//     final filePath =
//         await _getFilePath("GST_R1_${DateTime.now().millisecondsSinceEpoch}.pdf");

//     final file = File(filePath);
//     await file.writeAsBytes(await pdf.save());

//     return filePath;
//   }

//   // ===============================
//   // EXCEL EXPORT
//   // ===============================

//   Future<String> exportAsExcel(List<SaleModel> sales) async {
//     final excel = Excel.createExcel();
//     final sheet = excel['GST_R1'];

//     sheet.appendRow([
//       "Invoice No",
//       "Date",
//       "Customer",
//       "Taxable",
//       "CGST",
//       "SGST",
//       "IGST",
//       "Total"
//     ]);

//     for (var sale in sales) {
//       sheet.appendRow([
//         sale.invoiceNo,
//         _dateFormat.format(sale.date),
//         sale.customerName,
//         sale.taxableAmount,
//         sale.cgst,
//         sale.sgst,
//         sale.igst,
//         sale.totalAmount,
//       ]);
//     }

//     sheet.appendRow([]);
//     sheet.appendRow(["Summary"]);
//     sheet.appendRow(["Total Taxable", getTotalTaxable(sales)]);
//     sheet.appendRow(["Total CGST", getTotalCgst(sales)]);
//     sheet.appendRow(["Total SGST", getTotalSgst(sales)]);
//     sheet.appendRow(["Total IGST", getTotalIgst(sales)]);
//     sheet.appendRow(["Grand Total", getGrandTotal(sales)]);

//     final filePath =
//         await _getFilePath("GST_R1_${DateTime.now().millisecondsSinceEpoch}.xlsx");

//     final file = File(filePath);
//     await file.writeAsBytes(excel.encode()!);

//     return filePath;
//   }

//   // ===============================
//   // CSV EXPORT
//   // ===============================

//   Future<String> exportAsCsv(List<SaleModel> sales) async {
//     List<List<dynamic>> rows = [];

//     rows.add([
//       "Invoice No",
//       "Date",
//       "Customer",
//       "Taxable",
//       "CGST",
//       "SGST",
//       "IGST",
//       "Total"
//     ]);

//     for (var sale in sales) {
//       rows.add([
//         sale.invoiceNo,
//         _dateFormat.format(sale.date),
//         sale.customerName,
//         sale.taxableAmount,
//         sale.cgst,
//         sale.sgst,
//         sale.igst,
//         sale.totalAmount,
//       ]);
//     }

//     rows.add([]);
//     rows.add(["Summary"]);
//     rows.add(["Total Taxable", getTotalTaxable(sales)]);
//     rows.add(["Total CGST", getTotalCgst(sales)]);
//     rows.add(["Total SGST", getTotalSgst(sales)]);
//     rows.add(["Total IGST", getTotalIgst(sales)]);
//     rows.add(["Grand Total", getGrandTotal(sales)]);

//     String csvData = const ListToCsvConverter().convert(rows);

//     final filePath =
//         await _getFilePath("GST_R1_${DateTime.now().millisecondsSinceEpoch}.csv");

//     final file = File(filePath);
//     await file.writeAsString(csvData);

//     return filePath;
//   }
// }