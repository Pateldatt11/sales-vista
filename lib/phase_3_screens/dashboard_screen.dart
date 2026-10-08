import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:salesvista/phase_3_services/invoice_pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../phase_2_models/order_model.dart';
import '../phase_2_models/transaction_model.dart';
import '../phase_2_models/user_model.dart';
import '../phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

enum TimeFilter { week, month, year }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  TimeFilter selectedFilter = TimeFilter.month;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderBox = Hive.box<OrderModel>('orders_box');
    final transactionBox = Hive.box<TransactionModel>('transactions_box');
    final userBox = Hive.box<UserModel>('users_box');

    final totalOrderAmount = orderBox.values.fold<double>(
      0.0,
      (sum, order) => sum + order.totalAmount,
    );

    final stats = [
      {
        'title': 'Total Sales',
        'value': '₹${totalOrderAmount.toStringAsFixed(2)}',
        'icon': Icons.trending_up_rounded,
        'color': Colors.blue,
        'route': AppRoutes.sales,
      },
      {
        'title': 'Orders',
        'value': orderBox.length.toString(),
        'icon': Icons.shopping_cart_rounded,
        'color': Colors.purple,
        'route': AppRoutes.orders,
      },
      {
        'title': 'Invoices',
        'value': orderBox.length.toString(),
        'icon': Icons.description_rounded,
        'color': Colors.indigo,
        'route': AppRoutes.invoice,
      },
      {
        'title': 'Transactions',
        'value': transactionBox.length.toString(),
        'icon': Icons.receipt_long_rounded,
        'color': Colors.green,
        'route': AppRoutes.transactions,
      },
      {
        'title': 'Users',
        'value': userBox.length.toString(),
        'icon': Icons.group_rounded,
        'color': Colors.orange,
        'route': AppRoutes.users,
      },
    ];

    final paidInvoices =
        orderBox.values.where((o) => o.due == 0).length.toDouble();
    final partialInvoices =
        orderBox.values.where((o) => o.paid > 0 && o.due > 0).length.toDouble();
    final unpaidInvoices =
        orderBox.values.where((o) => o.paid == 0).length.toDouble();

    final invoiceStats = [
      {
        'title': 'Total Invoices',
        'value': orderBox.length.toString(),
        'color': Colors.blue,
      },
      {
        'title': 'Paid',
        'value': paidInvoices.toStringAsFixed(0),
        'color': Colors.green,
      },
      {
        'title': 'Partial',
        'value': partialInvoices.toStringAsFixed(0),
        'color': Colors.orange,
      },
      {
        'title': 'Unpaid',
        'value': unpaidInvoices.toStringAsFixed(0),
        'color': Colors.red,
      },
    ];

    return BaseScaffold(
      title: "Dashboard",
      currentRoute: AppRoutes.dashboard,
      body: LayoutBuilder(builder: (context, constraints) {
        // ignore: unused_local_variable
        double width = constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              // ================= KPI CARDS =================
              LayoutBuilder(
                builder: (context, constraints) {
                  double width = constraints.maxWidth;

                  int crossAxisCount;
                  if (width < 480) {
                    crossAxisCount = 2;
                  } else if (width < 900) {
                    crossAxisCount = 3;
                  } else {
                    crossAxisCount = 5;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stats.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio:
                          width < 480 ? 0.9 : 1.05,
                    ),
                    itemBuilder: (context, index) {
                      final stat = stats[index];
                      return AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _cardController.value,
                            child: GestureDetector(
                              onTap: stat['route'] != null
                                  ? () {
                                      Navigator.pushNamed(
                                          context,
                                          stat['route']
                                              as String);
                                    }
                                  : null,
                              child: _buildStatCard(
                                context,
                                stat['title'] as String,
                                stat['value'] as String,
                                stat['icon'] as IconData,
                                stat['color'] as Color,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 30),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Invoices",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                          fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),

              // ================= INVOICE SUMMARY =================
              LayoutBuilder(builder: (context, constraints) {
                double w = constraints.maxWidth;
                int count = w < 600 ? 2 : 4;

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: invoiceStats.length,
                  itemBuilder: (context, index) {
                    final stat = invoiceStats[index];
                    return _buildInvoiceCard(
                      stat['title'] as String,
                      stat['value'] as String,
                      stat['color'] as Color,
                    );
                  },
                );
              }),

              const SizedBox(height: 24),

              // ================= TIME FILTER =================
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  ToggleButtons(
                    isSelected: [
                      selectedFilter ==
                          TimeFilter.week,
                      selectedFilter ==
                          TimeFilter.month,
                      selectedFilter ==
                          TimeFilter.year,
                    ],
                    onPressed: (i) {
                      setState(() {
                        selectedFilter =
                            TimeFilter.values[i];
                      });
                    },
                    borderRadius:
                        BorderRadius.circular(12),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Text("Week")),
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Text("Month")),
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Text("Year")),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================= CHARTS =================
              LayoutBuilder(builder: (context, constraints) {
                bool isSmall =
                    constraints.maxWidth < 800;

                return isSmall
                    ? Column(
                        children: [
                          _styledLineChart(
                              orderBox.values.toList(),
                              selectedFilter),
                          const SizedBox(height: 24),
                          _styledInvoicePieChart(
                              paidInvoices,
                              partialInvoices,
                              unpaidInvoices),
                        ],
                      )
                    : Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _styledLineChart(
                                orderBox.values
                                    .toList(),
                                selectedFilter),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child:
                                _styledInvoicePieChart(
                                    paidInvoices,
                                    partialInvoices,
                                    unpaidInvoices),
                          ),
                        ],
                      );
              }),

              const SizedBox(height: 24),

              _recentInvoicesTable(
                  orderBox.values.toList()),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatCard(BuildContext context,
      String title,
      String value,
      IconData icon,
      Color color) {
    final width =
        MediaQuery.of(context).size.width;

    double iconRadius =
        width < 600 ? 24 : 30;
    double iconSize =
        width < 600 ? 26 : 32;
    double valueSize =
        width < 600 ? 16 : 20;
    double titleSize =
        width < 600 ? 13 : 15;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: iconRadius,
              backgroundColor:
                  // ignore: deprecated_member_use
                  color.withOpacity(0.15),
              child: Icon(icon,
                  size: iconSize,
                  color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: valueSize,
                    fontWeight:
                        FontWeight.bold,
                    color: color)),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                    fontSize: titleSize)),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(
      String title,
      String value,
      Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
          children: [
            Expanded(
              child: Text(title,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w500)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // Keep your chart, pie chart,
  // recent table,
  // PDF generation,
  // WhatsApp functions unchanged below this line.

    // ================= STYLED LINE CHART WIDGET =================
Widget _styledLineChart(List<OrderModel> orders, TimeFilter filter) {
  if (orders.isEmpty) {
    return const SizedBox(
      height: 250,
      child: Center(child: Text("No sales data available")),
    );
  }

  final now = DateTime.now();
  Map<String, double> data = {};

  // Aggregate data
  if (filter == TimeFilter.week) {
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('E').format(day);
      data[key] = orders
          .where((o) =>
              o.date.year == day.year &&
              o.date.month == day.month &&
              o.date.day == day.day)
          .fold(0.0, (sum, o) => sum + o.totalAmount);
    }
  } else if (filter == TimeFilter.month) {
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(now.year, now.month, i);
      final key = DateFormat('d').format(day);
      data[key] = orders
          .where((o) =>
              o.date.year == day.year &&
              o.date.month == day.month &&
              o.date.day == day.day)
          .fold(0.0, (sum, o) => sum + o.totalAmount);
    }
  } else {
    for (int i = 1; i <= 12; i++) {
      final key = DateFormat('MMM').format(DateTime(now.year, i));
      data[key] = orders
          .where((o) => o.date.year == now.year && o.date.month == i)
          .fold(0.0, (sum, o) => sum + o.totalAmount);
    }
  }

  final spots = data.entries
      .toList()
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.value))
      .toList();

  double maxY = data.values.isNotEmpty
      ? data.values.reduce((a, b) => a > b ? a : b) * 1.2
      : 10;

  final keys = data.keys.toList();

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sales Trend",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,

                // ✅ Tooltip Styling
                lineTouchData: LineTouchData(
  handleBuiltInTouches: true,

  // ✅ REMOVE vertical blue line
  getTouchedSpotIndicator: (barData, spotIndexes) {
    return spotIndexes.map((index) {
      return TouchedSpotIndicatorData(
        FlLine(
          color: Colors.transparent, // 👈 Makes vertical line invisible
          strokeWidth: 0,
        ),
        FlDotData(show: true),
      );
    }).toList();
  },

  touchTooltipData: LineTouchTooltipData(
    tooltipRoundedRadius: 12,
    tooltipPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    tooltipBgColor: const Color(0xFF1E293B),
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          "₹${NumberFormat('#,##0').format(spot.y)}",
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        );
      }).toList();
    },
  ),
),

                // Grid
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    // ignore: deprecated_member_use
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),

                // Titles
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              keys[index],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 5,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('0');
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),

                // Border
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom:
                        // ignore: deprecated_member_use
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                    left:
                        // ignore: deprecated_member_use
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                    right: const BorderSide(color: Colors.transparent),
                    top: const BorderSide(color: Colors.transparent),
                  ),
                ),

                // ✅ Gradient Line
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF3B82F6),
                      ],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF3B82F6),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1)
                              // ignore: deprecated_member_use
                              .withOpacity(0.3),
                          const Color(0xFF3B82F6)
                              // ignore: deprecated_member_use
                              .withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ================= STYLED PIE CHART WIDGET =================
Widget _styledInvoicePieChart(
    double paid, double partial, double unpaid) {
  final total = paid + partial + unpaid;
  if (total == 0) {
    return const SizedBox(
      height: 250,
      child: Center(child: Text("No invoice data available")),
    );
  }

  final sections = [
    PieChartSectionData(
      value: paid,
      color: Colors.green,
      title: '${((paid / total) * 100).toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    PieChartSectionData(
      value: partial,
      color: Colors.orange,
      title: '${((partial / total) * 100).toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    PieChartSectionData(
      value: unpaid,
      color: Colors.red,
      title: '${((unpaid / total) * 100).toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
    ),
  ];

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("Invoice Status",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(Colors.green, "Paid"),
              _buildLegendItem(Colors.orange, "Partial"),
              _buildLegendItem(Colors.red, "Unpaid"),
            ],
          )
        ],
      ),
    ),
  );
}

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  // RECENT INVOICES TABLE WITH PDF & WHATSAPP
Widget _recentInvoicesTable(List<OrderModel> orders) {
  final recent = orders.reversed.take(6).toList();

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Invoices",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Center(child: Text("No Of Genrated Invoice"))),
                DataColumn(label: Center(child: Text("Invoice ID"))),
                DataColumn(label: Center(child: Text("Customer"))),
                DataColumn(label: Center(child: Text("Total"))),
                DataColumn(label: Center(child: Text("Paid"))),
                DataColumn(label: Center(child: Text("Due"))),
                DataColumn(label: Center(child: Text("Print"))),
                DataColumn(label: Center(child: Text("Reminder"))),
              ],
              rows: recent.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Center(child: Text((index + 1).toString()))),
                    DataCell(Center(child: Text(order.id))),
                    DataCell(Center(child: Text(order.customerName))),
                    DataCell(Center(child: Text("₹${order.totalAmount.toStringAsFixed(2)}"))),
                    DataCell(Center(child: Text("₹${order.paid.toStringAsFixed(2)}"))),
                    DataCell(Center(child: Text("₹${order.due.toStringAsFixed(2)}"))),
                    // Print icon with Material ripple
                    DataCell(
                      Center(
                        child: IconButton(
                          icon: const Icon(Icons.picture_as_pdf,
                              color: Colors.deepPurple, size: 24),
                          onPressed: () => _generateInvoicePDF(order),
                          tooltip: "View PDF",
                        ),
                      ),
                    ),
                    // WhatsApp icon with Material ripple
                    DataCell(
                      Center(
                        child: IconButton(
                          icon: FaIcon(FontAwesomeIcons.whatsapp,
                              color: Colors.green, size: 22),
                          onPressed: () => _sendWhatsAppReminder(order),
                          tooltip: "Send WhatsApp Reminder",
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
// ================= PDF GENERATION =================
// ================= PDF GENERATION =================
Future<void> _generateInvoicePDF(OrderModel order) async {
  // Build PDF document asynchronously
  final pdf = await PdfService.buildOrderPdfForPreview(order);

  // Open PDF preview
  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}



// ================= WHATSAPP REMINDER =================
Future<void> _sendWhatsAppReminder(OrderModel order) async {
  final message =
      "Hello ${order.customerName},\nYour invoice of ₹${order.totalAmount.toStringAsFixed(2)} is due. Kindly make the payment at your earliest convenience.";
  final encodedMessage = Uri.encodeComponent(message);

  // WhatsApp URL
  final whatsappUrl = Uri.parse("https://wa.me/?text=$encodedMessage");

  if (await canLaunchUrl(whatsappUrl)) {
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
  } else {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Could not launch WhatsApp")),
    );
  }
}

}

