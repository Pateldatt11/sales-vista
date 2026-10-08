// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:intl/intl.dart';
// import '../phase_2_models/invoice_model.dart';
// import '../phase_1_core/app_routes.dart';
// import '../phase_4_widgets/base_scaffold.dart';
// import 'package:salesvista/phase_3_services/gstr1_service.dart';

// class GstR1StatementScreen extends StatefulWidget {
//   const GstR1StatementScreen({super.key});

//   @override
//   State<GstR1StatementScreen> createState() =>
//       _GstR1StatementScreenState();
// }

// class _GstR1StatementScreenState
//     extends State<GstR1StatementScreen> {

//   late DateTime selectedDate;

//   @override
//   void initState() {
//     super.initState();
//     selectedDate = DateTime.now();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final invoiceBox =
//         Hive.box<InvoiceModel>('invoice_box');

//     return BaseScaffold(
//       title: "GST R1 Report",
//       currentRoute: AppRoutes.gstr1,
//       body: SafeArea(
//         child: Container(
//           color: const Color(0xFFF4F6F8),
//           padding: const EdgeInsets.symmetric(
//               horizontal: 20,
//               vertical: 20),
//           child: ValueListenableBuilder(
//             valueListenable:
//                 invoiceBox.listenable(),
//             builder: (context,
//                 Box<InvoiceModel> box,
//                 _) {

//               final invoices =
//                   box.values.where((invoice) =>
//                       invoice.date.month ==
//                           selectedDate.month &&
//                       invoice.date.year ==
//                           selectedDate.year);

//               double taxable = 0;
//               double cgst = 0;
//               double sgst = 0;
//               double igst = 0;
//               double total = 0;
//               int invoiceCount = 0;

//               for (final inv in invoices) {
//                 invoiceCount++;
//                 taxable += inv.subtotal;
//                 cgst += inv.cgst;
//                 sgst += inv.sgst;
//                 igst += inv.igst;
//                 total += inv.grandTotal;
//               }

//               return SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment:
//                       CrossAxisAlignment.start,
//                   children: [

//                     /// HEADER
//                     LayoutBuilder(
//                       builder: (context, constraints) {
//                         bool isSmall =
//                             constraints.maxWidth < 700;

//                         return isSmall
//                             ? Column(
//                                 crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                 children: [
//                                   _headerLeft(),
//                                   const SizedBox(
//                                       height: 16),
//                                   _headerRight(
//                                       invoices.toList()),
//                                 ],
//                               )
//                             : Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment
//                                         .spaceBetween,
//                                 children: [
//                                   _headerLeft(),
//                                   _headerRight(
//                                       invoices.toList()),
//                                 ],
//                               );
//                       },
//                     ),

//                     const SizedBox(height: 30),

//                     /// KPI CARDS
//                     Wrap(
//                       spacing: 16,
//                       runSpacing: 16,
//                       children: [
//                         _metricCard(
//                             "Total Invoices",
//                             invoiceCount
//                                 .toString()),
//                         _metricCard(
//                             "Taxable Value",
//                             taxable
//                                 .toStringAsFixed(
//                                     2)),
//                         _metricCard(
//                             "Total GST",
//                             (cgst +
//                                     sgst +
//                                     igst)
//                                 .toStringAsFixed(
//                                     2)),
//                       ],
//                     ),

//                     const SizedBox(height: 40),

//                     /// TAX BREAKDOWN
//                     _buildFinanceCard(
//                         taxable,
//                         cgst,
//                         sgst,
//                         igst,
//                         total),

//                     const SizedBox(height: 40),

//                     /// GST TABLE
//                     _buildGstTable(
//                         box,
//                         invoiceCount,
//                         taxable,
//                         cgst,
//                         sgst,
//                         igst,
//                         total),

//                     const SizedBox(height: 40),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _headerLeft() {
//     return Column(
//       crossAxisAlignment:
//           CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "GST R1 Report",
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight:
//                 FontWeight.w600,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Text(
//           "Monthly tax summary overview",
//           style: TextStyle(
//             color:
//                 Colors.grey.shade600,
//             fontSize: 14,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _headerRight(
//       List<InvoiceModel> invoices) {
//     return Row(
//       children: [
//         InkWell(
//           onTap: _pickMonthYear,
//           child: Row(
//             children: [
//               const Icon(
//                   Icons.calendar_month,
//                   color: Colors.blue),
//               const SizedBox(width: 8),
//               Text(
//                 DateFormat(
//                         "MMM yyyy")
//                     .format(
//                         selectedDate),
//                 style:
//                     const TextStyle(
//                   fontSize: 16,
//                   fontWeight:
//                       FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 12),
//         ElevatedButton.icon(
//           onPressed: () async {
//             await _downloadGstr1File(
//                 invoices);
//           },
//           icon:
//               const Icon(Icons.download),
//           label: const Text(
//               "Download GST R1"),
//         ),
//       ],
//     );
//   }

//   Future<void> _pickMonthYear() async {
//     final picked =
//         await showDatePicker(
//       context: context,
//       initialDate: selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       helpText:
//           'Select Month & Year',
//       initialDatePickerMode:
//           DatePickerMode.year,
//     );
//     if (picked != null) {
//       setState(() {
//         selectedDate = picked;
//       });
//     }
//   }

//   Future<void> _downloadGstr1File(
//       List<InvoiceModel>
//           invoices) async {
//     try {
//       await Gstr1Service
//           .exportMonthlyGstr1(
//         month:
//             selectedDate.month,
//         year:
//             selectedDate.year,
//         companyStateCode:
//             "KA",
//       );

//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           content: Text(
//               "GST R1 for ${DateFormat("MMM yyyy").format(selectedDate)} downloaded!"),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//             content: Text(
//                 "Failed: $e")),
//       );
//     }
//   }

//   Widget _buildGstTable(
//       Box<InvoiceModel> box,
//       int invoiceCount,
//       double taxable,
//       double cgst,
//       double sgst,
//       double igst,
//       double total) {
//     return SingleChildScrollView(
//       scrollDirection:
//           Axis.horizontal,
//       child: Container(
//         padding:
//             const EdgeInsets.all(
//                 20),
//         decoration:
//             BoxDecoration(
//           color: Colors.white,
//           borderRadius:
//               BorderRadius
//                   .circular(18),
//         ),
//         child: DataTable(
//           columns: const [
//             DataColumn(
//                 label:
//                     Text("Type")),
//             DataColumn(
//                 label:
//                     Text("Invoices")),
//             DataColumn(
//                 label:
//                     Text("Taxable")),
//             DataColumn(
//                 label:
//                     Text("CGST")),
//             DataColumn(
//                 label:
//                     Text("SGST")),
//             DataColumn(
//                 label:
//                     Text("IGST")),
//             DataColumn(
//                 label:
//                     Text("Total")),
//           ],
//           rows: [
//             DataRow(
//               cells: [
//                 const DataCell(
//                     Text("TOTAL")),
//                 DataCell(Text(
//                     invoiceCount
//                         .toString())),
//                 DataCell(Text(
//                     taxable
//                         .toStringAsFixed(
//                             2))),
//                 DataCell(Text(
//                     cgst
//                         .toStringAsFixed(
//                             2))),
//                 DataCell(Text(
//                     sgst
//                         .toStringAsFixed(
//                             2))),
//                 DataCell(Text(
//                     igst
//                         .toStringAsFixed(
//                             2))),
//                 DataCell(Text(
//                     total
//                         .toStringAsFixed(
//                             2))),
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _metricCard(
//       String label,
//       String value) {
//     return Container(
//       width: 260,
//       padding:
//           const EdgeInsets
//               .symmetric(
//               vertical: 24,
//               horizontal: 22),
//       decoration:
//           BoxDecoration(
//         color: Colors.white,
//         borderRadius:
//             BorderRadius
//                 .circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment:
//             CrossAxisAlignment
//                 .start,
//         children: [
//           Text(label),
//           const SizedBox(
//               height: 10),
//           Text(
//             value,
//             style:
//                 const TextStyle(
//               fontSize: 22,
//               fontWeight:
//                   FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFinanceCard(
//       double taxable,
//       double cgst,
//       double sgst,
//       double igst,
//       double total) {

//     return Container(
//       padding:
//           const EdgeInsets.all(
//               28),
//       decoration:
//           BoxDecoration(
//         color: Colors.white,
//         borderRadius:
//             BorderRadius
//                 .circular(
//                     18),
//       ),
//       child: Column(
//         crossAxisAlignment:
//             CrossAxisAlignment
//                 .start,
//         children: [
//           const Text(
//             "Tax Breakdown",
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight:
//                   FontWeight
//                       .w600,
//             ),
//           ),
//           const SizedBox(
//               height: 28),
//           _cleanRow(
//               "Taxable",
//               taxable),
//           const Divider(),
//           _cleanRow(
//               "CGST", cgst),
//           const Divider(),
//           _cleanRow(
//               "SGST", sgst),
//           const Divider(),
//           _cleanRow(
//               "IGST", igst),
//           const Divider(),
//           _cleanRow(
//               "Total Liability",
//               total,
//               isBold: true),
//         ],
//       ),
//     );
//   }

//   Widget _cleanRow(
//       String label,
//       double value,
//       {bool isBold =
//           false}) {
//     return Padding(
//       padding:
//           const EdgeInsets
//               .symmetric(
//               vertical: 8),
//       child: Row(
//         mainAxisAlignment:
//             MainAxisAlignment
//                 .spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight:
//                   isBold
//                       ? FontWeight
//                           .w600
//                       : FontWeight
//                           .w400,
//             ),
//           ),
//           Text(
//             value
//                 .toStringAsFixed(
//                     2),
//             style: TextStyle(
//               fontWeight:
//                   isBold
//                       ? FontWeight
//                           .w600
//                       : FontWeight
//                           .w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }