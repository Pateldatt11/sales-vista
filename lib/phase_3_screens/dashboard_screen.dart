import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_2_models/expense_model.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final PosRepository _repo = PosRepository();
  final DateFormat _dayFormat = DateFormat('dd MMM');
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Dashboard',
      currentRoute: AppRoutes.dashboard,
      body: PosSyncBuilder(
        builder: (context) {
          final totals = _repo.dashboardTotals();
          final products = _repo.products();
          final lowStockProducts = products.where((p) => p.isLowStock).toList();
          final recentInvoices = _repo.invoicesBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
          final recentOrders = _repo.ordersBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
          final expenses = _repo.expensesBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));

          final stats = [
            _DashStat('New POS Bill', 'Create', 'Start counter checkout', Icons.point_of_sale_rounded, SalesVistaPalette.primary, AppRoutes.pos),
            _DashStat('Gross Sales', _money(totals['grossSales'] ?? 0.0), 'Total invoice value', Icons.trending_up_rounded, SalesVistaPalette.secondary, AppRoutes.sales),
            _DashStat('Collected', _money(totals['paid'] ?? 0.0), 'Cash received', Icons.payments_rounded, SalesVistaPalette.emerald, AppRoutes.transactions),
            _DashStat('Receivable', _money(totals['due'] ?? 0.0), 'Pending customer dues', Icons.pending_actions_rounded, SalesVistaPalette.rose, AppRoutes.customers),
            _DashStat('Inventory', '${(totals['products'] ?? 0.0).toStringAsFixed(0)} SKUs', _money(totals['stockValue'] ?? 0.0), Icons.inventory_2_rounded, SalesVistaPalette.violet, AppRoutes.inventory),
            _DashStat('Refill Spend', _money(totals['inventoryRefillExpense'] ?? 0.0), 'Purchase stock cost', Icons.move_down_rounded, SalesVistaPalette.emerald, AppRoutes.expenses),
            _DashStat('Low Stock', '${(totals['lowStock'] ?? 0.0).toStringAsFixed(0)} Alerts', 'Needs purchase action', Icons.warning_rounded, SalesVistaPalette.amber, AppRoutes.inventory),
            _DashStat('Invoices', '${(totals['invoices'] ?? 0.0).toStringAsFixed(0)} Bills', 'Multi-product billing', Icons.receipt_long_rounded, const Color(0xFF0EA5E9), AppRoutes.invoice),
            _DashStat('Net Cash', _money(totals['netCash'] ?? 0.0), 'Collected minus expense', Icons.account_balance_wallet_rounded, const Color(0xFF14B8A6), AppRoutes.reports),
          ];

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: _hero(totals, recentInvoices),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final count = width < 560 ? 2 : width < 980 ? 3 : 4;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: width < 560 ? 0.98 : 1.44,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _animated(index, _statCard(stats[index], index)),
                          childCount: stats.length,
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: _sectionTitle('Trending Analytics', 'Live charts from invoices, orders, expenses and inventory'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _graphsGrid(totals, recentInvoices, recentOrders, expenses),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: _bottomPanels(lowStockProducts, recentInvoices),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(Map<String, double> totals, List<InvoiceModel> invoices) {
    final days = _days(7);
    final values = _dailyInvoiceTotals(invoices, days, paidOnly: false);
    final current7 = values.fold<double>(0, (sum, value) => sum + value);
    final previous7 = _previousPeriodTotal(invoices, 7);
    final growth = previous7 <= 0 ? (current7 > 0 ? 100.0 : 0.0) : ((current7 - previous7) / previous7) * 100;
    final positive = growth >= 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              colors: [Color(0xFF020617), Color(0xFF111827), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: SalesVistaPalette.primary.withOpacity(0.24),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -80 + (pulse * 18),
                top: -90,
                child: _glowBlob(220, SalesVistaPalette.secondary.withOpacity(0.38)),
              ),
              Positioned(
                left: -70,
                bottom: -100 + (pulse * 12),
                child: _glowBlob(240, SalesVistaPalette.violet.withOpacity(0.34)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 760;
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_graph_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Industrial POS Command Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'SalesVista Professional POS',
                          style: TextStyle(color: Colors.white, fontSize: 30, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.7),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Animated live dashboard for billing, inventory, GST, receivable, expenses and cash flow.',
                          style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 14.5, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _heroPill(Icons.bolt_rounded, 'Today', _money(_todaySales(invoices))),
                            _heroPill(Icons.move_down_rounded, 'Refill spend', _money(totals['inventoryRefillExpense'] ?? 0.0)),
                            _heroPill(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, '7-day trend', '${positive ? '+' : ''}${growth.toStringAsFixed(1)}%'),
                            _heroPill(Icons.account_balance_wallet_rounded, 'Net cash', _money(totals['netCash'] ?? 0.0)),
                          ],
                        ),
                      ],
                    );

                    final ctaBlock = ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: wide ? 310 : double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white.withOpacity(0.16)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Weekly revenue momentum', style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Text(_money(current7), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                              const SizedBox(height: 14),
                              SizedBox(height: 84, child: _miniHeroLine(values)),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, AppRoutes.pos),
                                  icon: const Icon(Icons.add_shopping_cart_rounded),
                                  label: const Text('New Sale'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: SalesVistaPalette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (!wide) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 20), ctaBlock]);
                    }
                    return Row(
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 24),
                        ctaBlock,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('$label  ', style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 12, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _miniHeroLine(List<double> values) {
    final maxY = _max(values) <= 0 ? 1.0 : _max(values) * 1.2;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(values.length, (index) => FlSpot(index.toDouble(), values[index])),
            isCurved: true,
            color: Colors.white,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.white.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: SalesVistaPalette.ink)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: SalesVistaPalette.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_rounded, color: SalesVistaPalette.primary, size: 18),
              SizedBox(width: 8),
              Text('Live sync', style: TextStyle(color: SalesVistaPalette.primary, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _animated(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget _statCard(_DashStat stat, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => Navigator.pushNamed(context, stat.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white,
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(color: stat.color.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(right: -22, top: -22, child: _glowBlob(86, stat.color.withOpacity(0.12))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [stat.color.withOpacity(0.18), stat.color.withOpacity(0.06)]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(stat.icon, color: stat.color, size: 22),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward_rounded, color: stat.color.withOpacity(0.55), size: 18),
                  ],
                ),
                const Spacer(),
                Text(stat.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.4, color: stat.color)),
                const SizedBox(height: 5),
                Text(stat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(stat.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphsGrid(Map<String, double> totals, List<InvoiceModel> invoices, List<OrderModel> orders, List<ExpenseModel> expenses) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth > 980;
        final cards = <Widget>[
          _graphCard('Revenue Momentum', '7-day invoice value vs collection', Icons.stacked_line_chart_rounded, SalesVistaPalette.primary, _revenueMomentumChart(invoices), badge: 'Area'),
          _graphCard('Cashflow Trend', 'Daily sales and expenses', Icons.bar_chart_rounded, SalesVistaPalette.emerald, _cashflowGroupedBar(invoices, expenses), badge: 'Grouped'),
          _graphCard('Payment Mix', 'Collection by payment mode', Icons.donut_large_rounded, SalesVistaPalette.secondary, _paymentModeDonut(invoices), badge: 'Donut'),
          _graphCard('Top Product Velocity', 'Best-selling quantity leaderboard', Icons.leaderboard_rounded, SalesVistaPalette.violet, _topProductsLeaderboard(orders), badge: 'Rank'),
          _graphCard('Inventory Health', 'Healthy, low and out-of-stock SKU split', Icons.inventory_rounded, SalesVistaPalette.amber, _stockHealthDonut(), badge: 'Risk'),
          _graphCard('Margin Opportunity', 'Stock margin value by product', Icons.ssid_chart_rounded, const Color(0xFF0EA5E9), _marginOpportunityBars(), badge: 'Profit'),
        ];

        if (!twoColumn) {
          return Column(
            children: List.generate(cards.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(height: index == 3 || index == 5 ? 390 : 350, child: _animated(index, cards[index])),
              );
            }),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.58,
          ),
          itemBuilder: (context, index) => _animated(index, cards[index]),
        );
      },
    );
  }

  Widget _graphCard(String title, String subtitle, IconData icon, Color accent, Widget chart, {required String badge}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent.withOpacity(0.18), accent.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: SalesVistaPalette.ink, letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
                child: Text(badge, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _revenueMomentumChart(List<InvoiceModel> invoices) {
    final days = _days(7);
    final sales = _dailyInvoiceTotals(invoices, days, paidOnly: false);
    final collected = _dailyInvoiceTotals(invoices, days, paidOnly: true);
    final maxY = math.max(_max(sales), _max(collected)) <= 0 ? 1.0 : math.max(_max(sales), _max(collected)) * 1.24;

    if (sales.every((value) => value <= 0) && collected.every((value) => value <= 0)) {
      return _emptyChart('No invoice trend yet');
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(enabled: true),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 46, getTitlesWidget: (value, meta) => _axisText('₹${_compact(value)}'))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) return const SizedBox.shrink();
                  return _axisText(DateFormat('dd').format(days[index]));
                })),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(sales.length, (index) => FlSpot(index.toDouble(), sales[index])),
                  isCurved: true,
                  color: SalesVistaPalette.primary,
                  barWidth: 3.2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: SalesVistaPalette.primary.withOpacity(0.10)),
                ),
                LineChartBarData(
                  spots: List.generate(collected.length, (index) => FlSpot(index.toDouble(), collected[index])),
                  isCurved: true,
                  color: SalesVistaPalette.emerald,
                  barWidth: 3.2,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [_legend('Sales', sales.fold<double>(0.0, (s, v) => s + v), SalesVistaPalette.primary), const SizedBox(width: 14), _legend('Collected', collected.fold<double>(0.0, (s, v) => s + v), SalesVistaPalette.emerald)]),
      ],
    );
  }

  Widget _cashflowGroupedBar(List<InvoiceModel> invoices, List<ExpenseModel> expenses) {
    final days = _days(7);
    final sales = _dailyInvoiceTotals(invoices, days, paidOnly: true);
    final expenseValues = _dailyExpenseTotals(expenses, days);
    final maxY = math.max(_max(sales), _max(expenseValues)) <= 0 ? 1.0 : math.max(_max(sales), _max(expenseValues)) * 1.28;

    if (sales.every((value) => value <= 0) && expenseValues.every((value) => value <= 0)) {
      return _emptyChart('No cashflow data yet');
    }

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 46, getTitlesWidget: (value, meta) => _axisText('₹${_compact(value)}'))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) return const SizedBox.shrink();
                  return _axisText(DateFormat('dd').format(days[index]));
                })),
              ),
              barGroups: List.generate(days.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(toY: sales[index], color: SalesVistaPalette.emerald, width: 10, borderRadius: BorderRadius.circular(8)),
                    BarChartRodData(toY: expenseValues[index], color: SalesVistaPalette.rose, width: 10, borderRadius: BorderRadius.circular(8)),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [_legend('Income', sales.fold<double>(0.0, (s, v) => s + v), SalesVistaPalette.emerald), const SizedBox(width: 14), _legend('Expense', expenseValues.fold<double>(0.0, (s, v) => s + v), SalesVistaPalette.rose)]),
      ],
    );
  }

  Widget _paymentModeDonut(List<InvoiceModel> invoices) {
    final modes = <String, double>{};
    for (final invoice in invoices) {
      final mode = invoice.paymentMode.trim().isEmpty ? 'Cash' : invoice.paymentMode.trim();
      modes.update(mode, (value) => value + invoice.paid, ifAbsent: () => invoice.paid);
    }
    modes.removeWhere((key, value) => value <= 0);
    if (modes.isEmpty) return _emptyChart('No payment collection yet');

    final colors = [SalesVistaPalette.primary, SalesVistaPalette.emerald, SalesVistaPalette.secondary, SalesVistaPalette.amber, SalesVistaPalette.violet, SalesVistaPalette.rose];
    final entries = modes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 52,
              sections: List.generate(entries.length, (index) {
                final entry = entries[index];
                return PieChartSectionData(
                  value: entry.value,
                  title: '${((entry.value / total) * 100).toStringAsFixed(0)}%',
                  color: colors[index % colors.length],
                  radius: 58,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 118,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(math.min(entries.length, 5), (index) {
              final entry = entries[index];
              return _compactLegend(entry.key, _money(entry.value), colors[index % colors.length]);
            }),
          ),
        ),
      ],
    );
  }

  Widget _topProductsLeaderboard(List<OrderModel> orders) {
    final map = <String, double>{};
    for (final order in orders) {
      map.update(order.productName, (value) => value + order.quantity, ifAbsent: () => order.quantity);
    }
    final top = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final entries = top.take(6).toList();
    if (entries.isEmpty) return _emptyChart('No product sales yet');
    final maxValue = _max(entries.map((e) => e.value).toList());

    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final ratio = maxValue <= 0 ? 0.0 : (entry.value / maxValue).clamp(0.0, 1.0).toDouble();
        final color = [SalesVistaPalette.primary, SalesVistaPalette.secondary, SalesVistaPalette.emerald, SalesVistaPalette.violet, SalesVistaPalette.amber, SalesVistaPalette.rose][index % 6];
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: SalesVistaPalette.ink))),
                        Text('${entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)} qty', style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w800, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: ratio),
                        duration: Duration(milliseconds: 600 + (index * 80)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 9,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _stockHealthDonut() {
    final products = _repo.products();
    if (products.isEmpty) return _emptyChart('No inventory data yet');
    final out = products.where((p) => p.stock <= 0).length.toDouble();
    final low = products.where((p) => p.stock > 0 && p.isLowStock).length.toDouble();
    final healthy = products.length.toDouble() - low - out;
    final sections = [
      _PieSlice('Healthy', healthy, SalesVistaPalette.emerald),
      _PieSlice('Low', low, SalesVistaPalette.amber),
      _PieSlice('Out', out, SalesVistaPalette.rose),
    ].where((slice) => slice.value > 0).toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: sections.map((slice) {
                return PieChartSectionData(
                  value: slice.value,
                  color: slice.color,
                  title: slice.value.toStringAsFixed(0),
                  radius: 58,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 110,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sections.map((slice) => _compactLegend(slice.label, '${slice.value.toStringAsFixed(0)} SKU', slice.color)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _marginOpportunityBars() {
    final products = _repo.products().where((p) => p.stock > 0).toList();
    products.sort((a, b) => ((b.price - b.purchasePrice) * b.stock).compareTo((a.price - a.purchasePrice) * a.stock));
    final top = products.take(6).toList();
    if (top.isEmpty) return _emptyChart('No stock margin data yet');
    final values = top.map((p) => math.max((p.price - p.purchasePrice) * p.stock, 0).toDouble()).toList();
    final maxValue = _max(values);

    return Column(
      children: List.generate(top.length, (index) {
        final p = top[index];
        final value = values[index];
        final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
        final color = Color.lerp(SalesVistaPalette.secondary, SalesVistaPalette.primary, index / math.max(top.length - 1, 1)) ?? SalesVistaPalette.primary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: SalesVistaPalette.ink))),
                  Text(_money(value), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 7),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: ratio),
                duration: Duration(milliseconds: 620 + (index * 70)),
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(height: 11, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(99))),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 11,
                            width: constraints.maxWidth * animated,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color.withOpacity(0.72), color]),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _bottomPanels(List<PosProduct> lowStockProducts, List<InvoiceModel> recentInvoices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final alerts = _panel(
          'Low Stock Alerts',
          lowStockProducts.isEmpty
              ? [const ListTile(title: Text('No low stock alerts'))]
              : lowStockProducts.take(8).map((p) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: SalesVistaPalette.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.warning_rounded, color: SalesVistaPalette.amber),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
                    subtitle: Text('SKU ${p.sku.isEmpty ? '-' : p.sku} • Alert ${p.lowStock.toStringAsFixed(2)} ${p.unit}'),
                    trailing: Text('${p.stock.toStringAsFixed(2)} ${p.unit}', style: const TextStyle(color: SalesVistaPalette.rose, fontWeight: FontWeight.w900)),
                  )).toList(),
        );
        final sales = _panel(
          'Recent Invoices',
          recentInvoices.isEmpty
              ? [const ListTile(title: Text('No recent invoices'))]
              : recentInvoices.take(8).map((invoice) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: SalesVistaPalette.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.receipt_long_rounded, color: SalesVistaPalette.primary),
                    ),
                    title: Text(invoice.customerName, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
                    subtitle: Text('${invoice.itemCount} item(s) • ${_dayFormat.format(invoice.date)} • Paid ${_money(invoice.paid)}'),
                    trailing: Text(_money(invoice.grandTotal), style: const TextStyle(color: SalesVistaPalette.emerald, fontWeight: FontWeight.w900)),
                  )).toList(),
        );
        return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: alerts), const SizedBox(width: 16), Expanded(child: sales)]) : Column(children: [alerts, const SizedBox(height: 16), sales]);
      },
    );
  }

  Widget _panel(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: SalesVistaPalette.primary.withOpacity(0.07), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: SalesVistaPalette.ink))),
          const Divider(color: Color(0xFFE2E8F0)),
          ...children,
        ],
      ),
    );
  }

  Widget _emptyChart(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SalesVistaPalette.softSurface, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.insights_rounded, color: SalesVistaPalette.muted),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _legend(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Flexible(child: Text('$label ${_money(value)}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: SalesVistaPalette.slate, fontWeight: FontWeight.w800))),
      ],
    );
  }

  Widget _compactLegend(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.slate, fontSize: 12, fontWeight: FontWeight.w900)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.muted, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _axisText(String text) => Text(text, style: const TextStyle(fontSize: 10, color: SalesVistaPalette.muted, fontWeight: FontWeight.w700));

  List<DateTime> _days(int count) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    return List<DateTime>.generate(count, (index) => base.subtract(Duration(days: count - 1 - index)));
  }

  List<double> _dailyInvoiceTotals(List<InvoiceModel> invoices, List<DateTime> days, {required bool paidOnly}) {
    return days.map((day) {
      return invoices.where((invoice) => _sameDay(invoice.date, day)).fold<double>(0.0, (sum, invoice) => sum + (paidOnly ? invoice.paid : invoice.grandTotal));
    }).toList();
  }

  List<double> _dailyExpenseTotals(List<ExpenseModel> expenses, List<DateTime> days) {
    return days.map((day) {
      return expenses.where((expense) => _sameDay(expense.date, day)).fold<double>(0.0, (sum, expense) => sum + expense.amount);
    }).toList();
  }

  double _todaySales(List<InvoiceModel> invoices) {
    final now = DateTime.now();
    return invoices.where((invoice) => _sameDay(invoice.date, now)).fold<double>(0.0, (sum, invoice) => sum + invoice.grandTotal);
  }

  double _previousPeriodTotal(List<InvoiceModel> invoices, int days) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day).subtract(Duration(days: days));
    final start = end.subtract(Duration(days: days - 1));
    return invoices.where((invoice) {
      final date = DateTime(invoice.date.year, invoice.date.month, invoice.date.day);
      return !date.isBefore(start) && !date.isAfter(end);
    }).fold<double>(0.0, (sum, invoice) => sum + invoice.grandTotal);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  double _max(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  String _money(double value) {
    final abs = value.abs();
    if (abs >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (abs >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
  }

  String _compact(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

class _DashStat {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final String route;

  _DashStat(this.title, this.value, this.caption, this.icon, this.color, this.route);
}

class _PieSlice {
  final String label;
  final double value;
  final Color color;

  const _PieSlice(this.label, this.value, this.color);
}
