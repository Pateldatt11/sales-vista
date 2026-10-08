// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:printing/printing.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../phase_2_models/order_model.dart';
// import '../phase_2_models/transaction_model.dart';
// import '../phase_2_models/user_model.dart';
// import '../phase_1_core/app_routes.dart';
// import '../phase_3_services/invoice_pdf_service.dart';
// import '../phase_4_widgets/base_scaffold.dart';

// enum TimeFilter { week, month, year }

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   TimeFilter selectedFilter = TimeFilter.month;

//   @override
//   Widget build(BuildContext context) {
//     final orderBox = Hive.box<OrderModel>('orders_box');
//     final transactionBox = Hive.box<TransactionModel>('transactions_box');
//     final userBox = Hive.box<UserModel>('users_box');

//     final totalSales = orderBox.values.fold<double>(
//       0.0,
//       (sum, order) => sum + order.totalAmount,
//     );

//     final paid =
//         orderBox.values.where((o) => o.due == 0).length.toDouble();
//     final partial =
//         orderBox.values.where((o) => o.paid > 0 && o.due > 0).length.toDouble();
//     final unpaid =
//         orderBox.values.where((o) => o.paid == 0).length.toDouble();

//     return BaseScaffold(
//       title: "Dashboard",
//       currentRoute: AppRoutes.dashboard,
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           bool isDesktop = constraints.maxWidth > 1000;
//           bool isTablet =
//               constraints.maxWidth > 700 && constraints.maxWidth <= 1000;

//           return Container(
//             color: const Color(0xFFF5F6F8),
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [

//                   // ================= HEADER =================
//                   _buildHeader(),

//                   const SizedBox(height: 30),

//                   // ================= KPI ROW =================
//                   _buildKpiRow(
//                     totalSales,
//                     orderBox.length,
//                     transactionBox.length,
//                     userBox.length,
//                     isDesktop,
//                     isTablet,
//                   ),

//                   const SizedBox(height: 30),

//                   // ================= CHART + PIE =================
//                   isDesktop
//                       ? Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                                 flex: 3,
//                                 child: _styledLineChart(
//                                     orderBox.values.toList(),
//                                     selectedFilter)),
//                             const SizedBox(width: 24),
//                             Expanded(
//                                 flex: 2,
//                                 child: _styledInvoicePieChart(
//                                     paid, partial, unpaid)),
//                           ],
//                         )
//                       : Column(
//                           children: [
//                             _styledLineChart(
//                                 orderBox.values.toList(),
//                                 selectedFilter),
//                             const SizedBox(height: 24),
//                             _styledInvoicePieChart(
//                                 paid, partial, unpaid),
//                           ],
//                         ),

//                   const SizedBox(height: 30),

//                   _recentInvoicesTable(orderBox.values.toList()),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // ================= HEADER =================
//   Widget _buildHeader() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "Hello, Darshan 👋",
//               style: TextStyle(
//                   fontSize: 26, fontWeight: FontWeight.bold),
//             ),
//             Text(
//               "Explore your business analytics",
//               style: TextStyle(color: Colors.grey.shade600),
//             ),
//           ],
//         ),
//         Container(
//           width: 280,
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(30),
//           ),
//           child: const TextField(
//             decoration: InputDecoration(
//               border: InputBorder.none,
//               icon: Icon(Icons.search),
//               hintText: "Search...",
//             ),
//           ),
//         )
//       ],
//     );
//   }

//   // ================= KPI =================
//   Widget _buildKpiRow(
//       double sales,
//       int orders,
//       int transactions,
//       int users,
//       bool desktop,
//       bool tablet) {
//     final kpis = [
//       _kpi("Total Sales",
//           "₹${sales.toStringAsFixed(0)}", Icons.trending_up, Colors.green),
//       _kpi("Orders", orders.toString(),
//           Icons.shopping_cart, Colors.purple),
//       _kpi("Transactions", transactions.toString(),
//           Icons.receipt_long, Colors.blue),
//       _kpi("Users", users.toString(),
//           Icons.group, Colors.orange),
//     ];

//     int crossAxis =
//         desktop ? 4 : tablet ? 2 : 1;

//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: kpis.length,
//       gridDelegate:
//           SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: crossAxis,
//         crossAxisSpacing: 20,
//         mainAxisSpacing: 20,
//         childAspectRatio: 1.5,
//       ),
//       itemBuilder: (context, index) => kpis[index],
//     );
//   }

//   Widget _kpi(
//       String title,
//       String value,
//       IconData icon,
//       Color color) {
//     return Container(
//       padding: const EdgeInsets.all(22),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 20,
//               offset: const Offset(0, 10))
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(14)),
//             child: Icon(icon, color: color),
//           ),
//           const Spacer(),
//           Text(value,
//               style: const TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold)),
//           const SizedBox(height: 6),
//           Text(title,
//               style: TextStyle(color: Colors.grey.shade600)),
//         ],
//       ),
//     );
//   }

//   // Keep your existing:
//   // _styledLineChart
//   // _styledInvoicePieChart
//   // _recentInvoicesTable
//   // _generateInvoicePDF
//   // _sendWhatsAppReminder

//       // ================= STYLED LINE CHART WIDGET =================
// Widget _styledLineChart(List<OrderModel> orders, TimeFilter filter) {
//   if (orders.isEmpty) {
//     return const SizedBox(
//       height: 250,
//       child: Center(child: Text("No sales data available")),
//     );
//   }

//   final now = DateTime.now();
//   Map<String, double> data = {};

//   // Aggregate data
//   if (filter == TimeFilter.week) {
//     for (int i = 0; i < 7; i++) {
//       final day = now.subtract(Duration(days: 6 - i));
//       final key = DateFormat('E').format(day);
//       data[key] = orders
//           .where((o) =>
//               o.date.year == day.year &&
//               o.date.month == day.month &&
//               o.date.day == day.day)
//           .fold(0.0, (sum, o) => sum + o.totalAmount);
//     }
//   } else if (filter == TimeFilter.month) {
//     final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
//     for (int i = 1; i <= daysInMonth; i++) {
//       final day = DateTime(now.year, now.month, i);
//       final key = DateFormat('d').format(day);
//       data[key] = orders
//           .where((o) =>
//               o.date.year == day.year &&
//               o.date.month == day.month &&
//               o.date.day == day.day)
//           .fold(0.0, (sum, o) => sum + o.totalAmount);
//     }
//   } else {
//     for (int i = 1; i <= 12; i++) {
//       final key = DateFormat('MMM').format(DateTime(now.year, i));
//       data[key] = orders
//           .where((o) => o.date.year == now.year && o.date.month == i)
//           .fold(0.0, (sum, o) => sum + o.totalAmount);
//     }
//   }

//   final spots = data.entries
//       .toList()
//       .asMap()
//       .entries
//       .map((e) => FlSpot(e.key.toDouble(), e.value.value))
//       .toList();

//   double maxY = data.values.isNotEmpty
//       ? data.values.reduce((a, b) => a > b ? a : b) * 1.2
//       : 10;

//   final keys = data.keys.toList();

//   return Card(
//     elevation: 3,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     child: Padding(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Sales Trend",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             height: 250,
//             child: LineChart(
//               LineChartData(
//                 minX: 0,
//                 maxX: (spots.length - 1).toDouble(),
//                 minY: 0,
//                 maxY: maxY,

//                 // ✅ Tooltip Styling
//                 lineTouchData: LineTouchData(
//   handleBuiltInTouches: true,

//   // ✅ REMOVE vertical blue line
//   getTouchedSpotIndicator: (barData, spotIndexes) {
//     return spotIndexes.map((index) {
//       return TouchedSpotIndicatorData(
//         FlLine(
//           color: Colors.transparent, // 👈 Makes vertical line invisible
//           strokeWidth: 0,
//         ),
//         FlDotData(show: true),
//       );
//     }).toList();
//   },

//   touchTooltipData: LineTouchTooltipData(
//     tooltipRoundedRadius: 12,
//     tooltipPadding: const EdgeInsets.symmetric(
//       horizontal: 12,
//       vertical: 8,
//     ),
//     tooltipBgColor: const Color(0xFF1E293B),
//     getTooltipItems: (touchedSpots) {
//       return touchedSpots.map((spot) {
//         return LineTooltipItem(
//           "₹${NumberFormat('#,##0').format(spot.y)}",
//           const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//         );
//       }).toList();
//     },
//   ),
// ),

//                 // Grid
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                   horizontalInterval: maxY / 5,
//                   getDrawingHorizontalLine: (value) => FlLine(
//                     color: Colors.grey.withOpacity(0.15),
//                     strokeWidth: 1,
//                   ),
//                 ),

//                 // Titles
//                 titlesData: FlTitlesData(
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 36,
//                       interval: 1,
//                       getTitlesWidget: (value, meta) {
//                         int index = value.toInt();
//                         if (index >= 0 && index < keys.length) {
//                           return Padding(
//                             padding: const EdgeInsets.only(top: 8),
//                             child: Text(
//                               keys[index],
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.black54,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),
//                   ),
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       interval: maxY / 5,
//                       reservedSize: 40,
//                       getTitlesWidget: (value, meta) {
//                         if (value == 0) return const Text('0');
//                         return Text(
//                           value.toInt().toString(),
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color: Colors.black45,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   topTitles:
//                       AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                   rightTitles:
//                       AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                 ),

//                 // Border
//                 borderData: FlBorderData(
//                   show: true,
//                   border: Border(
//                     bottom:
//                         BorderSide(color: Colors.grey.withOpacity(0.3)),
//                     left:
//                         BorderSide(color: Colors.grey.withOpacity(0.3)),
//                     right: const BorderSide(color: Colors.transparent),
//                     top: const BorderSide(color: Colors.transparent),
//                   ),
//                 ),

//                 // ✅ Gradient Line
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots: spots,
//                     isCurved: true,
//                     gradient: const LinearGradient(
//                       colors: [
//                         Color(0xFF6366F1),
//                         Color(0xFF3B82F6),
//                       ],
//                     ),
//                     barWidth: 4,
//                     isStrokeCapRound: true,
//                     dotData: FlDotData(
//                       show: true,
//                       getDotPainter: (spot, percent, barData, index) =>
//                           FlDotCirclePainter(
//                         radius: 4,
//                         color: const Color(0xFF3B82F6),
//                         strokeWidth: 2,
//                         strokeColor: Colors.white,
//                       ),
//                     ),
//                     belowBarData: BarAreaData(
//                       show: true,
//                       gradient: LinearGradient(
//                         colors: [
//                           const Color(0xFF6366F1)
//                               .withOpacity(0.3),
//                           const Color(0xFF3B82F6)
//                               .withOpacity(0.05),
//                         ],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ================= STYLED PIE CHART WIDGET =================
// Widget _styledInvoicePieChart(
//     double paid, double partial, double unpaid) {
//   final total = paid + partial + unpaid;
//   if (total == 0) {
//     return const SizedBox(
//       height: 250,
//       child: Center(child: Text("No invoice data available")),
//     );
//   }

//   final sections = [
//     PieChartSectionData(
//       value: paid,
//       color: Colors.green,
//       title: '${((paid / total) * 100).toStringAsFixed(1)}%',
//       radius: 60,
//       titleStyle: const TextStyle(
//           fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
//     ),
//     PieChartSectionData(
//       value: partial,
//       color: Colors.orange,
//       title: '${((partial / total) * 100).toStringAsFixed(1)}%',
//       radius: 60,
//       titleStyle: const TextStyle(
//           fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
//     ),
//     PieChartSectionData(
//       value: unpaid,
//       color: Colors.red,
//       title: '${((unpaid / total) * 100).toStringAsFixed(1)}%',
//       radius: 60,
//       titleStyle: const TextStyle(
//           fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
//     ),
//   ];

//   return Card(
//     elevation: 3,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     child: Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         children: [
//           const Text("Invoice Status",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 16),
//           SizedBox(
//             height: 220,
//             child: PieChart(
//               PieChartData(
//                 sections: sections,
//                 sectionsSpace: 4,
//                 centerSpaceRadius: 40,
//                 borderData: FlBorderData(show: false),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 16,
//             runSpacing: 8,
//             alignment: WrapAlignment.center,
//             children: [
//               _buildLegendItem(Colors.green, "Paid"),
//               _buildLegendItem(Colors.orange, "Partial"),
//               _buildLegendItem(Colors.red, "Unpaid"),
//             ],
//           )
//         ],
//       ),
//     ),
//   );
// }

//   Widget _buildLegendItem(Color color, String label) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 16,
//           height: 16,
//           decoration:
//               BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
//         ),
//         const SizedBox(width: 6),
//         Text(label,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             )),
//       ],
//     );
//   }

//   // RECENT INVOICES TABLE WITH PDF & WHATSAPP
// Widget _recentInvoicesTable(List<OrderModel> orders) {
//   final recent = orders.reversed.take(6).toList();

//   return Card(
//     elevation: 3,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     child: Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Recent Invoices",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: DataTable(
//               columns: const [
//                 DataColumn(label: Center(child: Text("No Of Genrated Invoice"))),
//                 DataColumn(label: Center(child: Text("Invoice ID"))),
//                 DataColumn(label: Center(child: Text("Customer"))),
//                 DataColumn(label: Center(child: Text("Total"))),
//                 DataColumn(label: Center(child: Text("Paid"))),
//                 DataColumn(label: Center(child: Text("Due"))),
//                 DataColumn(label: Center(child: Text("Print"))),
//                 DataColumn(label: Center(child: Text("Reminder"))),
//               ],
//               rows: recent.asMap().entries.map((entry) {
//                 final index = entry.key;
//                 final order = entry.value;

//                 return DataRow(
//                   cells: [
//                     DataCell(Center(child: Text((index + 1).toString()))),
//                     DataCell(Center(child: Text(order.id))),
//                     DataCell(Center(child: Text(order.customerName))),
//                     DataCell(Center(child: Text("₹${order.totalAmount.toStringAsFixed(2)}"))),
//                     DataCell(Center(child: Text("₹${order.paid.toStringAsFixed(2)}"))),
//                     DataCell(Center(child: Text("₹${order.due.toStringAsFixed(2)}"))),
//                     // Print icon with Material ripple
//                     DataCell(
//                       Center(
//                         child: IconButton(
//                           icon: const Icon(Icons.picture_as_pdf,
//                               color: Colors.deepPurple, size: 24),
//                           onPressed: () => _generateInvoicePDF(order),
//                           tooltip: "View PDF",
//                         ),
//                       ),
//                     ),
//                     // WhatsApp icon with Material ripple
//                     DataCell(
//                       Center(
//                         child: IconButton(
//                           icon: Icon(FontAwesomeIcons.whatsapp,
//                               color: Colors.green, size: 22),
//                           onPressed: () => _sendWhatsAppReminder(order),
//                           tooltip: "Send WhatsApp Reminder",
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }
// // ================= PDF GENERATION =================
// // ================= PDF GENERATION =================
// Future<void> _generateInvoicePDF(OrderModel order) async {
//   // Build PDF document asynchronously
//   final pdf = await PdfService.buildOrderPdfForPreview(order);

//   // Open PDF preview
//   await Printing.layoutPdf(
//     onLayout: (format) async => pdf.save(),
//   );
// }



// // ================= WHATSAPP REMINDER =================
// Future<void> _sendWhatsAppReminder(OrderModel order) async {
//   final message =
//       "Hello ${order.customerName},\nYour invoice of ₹${order.totalAmount.toStringAsFixed(2)} is due. Kindly make the payment at your earliest convenience.";
//   final encodedMessage = Uri.encodeComponent(message);

//   // WhatsApp URL
//   final whatsappUrl = Uri.parse("https://wa.me/?text=$encodedMessage");

//   if (await canLaunchUrl(whatsappUrl)) {
//     await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Could not launch WhatsApp")),
//     );
//   }
// }

// }