import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  String _statusFilter = 'All';
  String _dateFilter = 'All Time';

  final List<String> _statusFilters = const ['All', 'Paid', 'Partial', 'Due'];
  final List<String> _dateFilters = const ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderBox = Hive.box<OrderModel>('orders_box');

    return BaseScaffold(
      title: 'Sales',
      currentRoute: AppRoutes.sales,
      body: ValueListenableBuilder(
        valueListenable: orderBox.listenable(),
        builder: (context, Box<OrderModel> box, _) {
          final orders = _filteredOrders(box.values.toList());
          final total = orders.fold<double>(0, (sum, o) => sum + o.grandTotal);
          final paid = orders.fold<double>(0, (sum, o) => sum + o.paid);
          final due = orders.fold<double>(0, (sum, o) => sum + o.due);
          final qty = orders.fold<double>(0, (sum, o) => sum + o.quantity);

          return Column(
            children: [
              ModernPageHeader(
                title: 'Sales Register',
                subtitle: 'Track paid, partial, due, and returned sales with payment sync to invoices and transactions.',
                icon: Icons.trending_up_rounded,
                actions: [
                  ElevatedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.pos), icon: const Icon(Icons.point_of_sale_rounded), label: const Text('New Sale')),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Gross Sales', value: svMoney(total), caption: '${orders.length} bills', icon: Icons.stacked_line_chart_rounded, color: SalesVistaPalette.primary),
                  ModernMetricCard(title: 'Collected', value: svMoney(paid), caption: 'Paid amount', icon: Icons.payments_rounded, color: SalesVistaPalette.emerald),
                  ModernMetricCard(title: 'Receivable', value: svMoney(due), caption: 'Pending due', icon: Icons.pending_actions_rounded, color: SalesVistaPalette.rose),
                  ModernMetricCard(title: 'Quantity', value: qty.toStringAsFixed(2), caption: 'Units sold', icon: Icons.scale_rounded, color: SalesVistaPalette.violet),
                ],
              ),
              const SizedBox(height: 14),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ModernSearchField(controller: _searchController, label: 'Search sales by customer or product', onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ModernFilterBar(selected: _statusFilter, options: _statusFilters, onChanged: (value) => setState(() => _statusFilter = value))),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            value: _dateFilter,
                            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range_rounded)),
                            items: _dateFilters.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                            onChanged: (value) => setState(() => _dateFilter = value ?? _dateFilter),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: orders.isEmpty
                    ? const ModernEmptyState(title: 'No sales found', subtitle: 'Create a new POS bill or relax the filters.', icon: Icons.receipt_long_rounded)
                    : ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final statusColor = order.due <= 0 ? SalesVistaPalette.emerald : order.paid > 0 ? SalesVistaPalette.amber : SalesVistaPalette.rose;
                          final statusText = order.due <= 0 ? 'Paid' : order.paid > 0 ? 'Partial' : 'Due';
                          return ModernSectionCard(
                            padding: const EdgeInsets.all(14),
                            glowColor: statusColor,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 680;
                                final body = Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.receipt_long_rounded, color: statusColor)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: Text(order.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink, fontSize: 16))),
                                              StatusPill(label: statusText, color: statusColor),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          Text('${order.productName} • Qty ${order.quantity.toStringAsFixed(2)} • ${_dateFormat.format(order.date)}', style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 8),
                                          Wrap(spacing: 10, runSpacing: 6, children: [
                                            StatusPill(label: 'Total ${svMoney(order.grandTotal)}', color: SalesVistaPalette.primary),
                                            StatusPill(label: 'Paid ${svMoney(order.paid)}', color: SalesVistaPalette.emerald),
                                            StatusPill(label: 'Due ${svMoney(order.due)}', color: order.due > 0 ? SalesVistaPalette.rose : SalesVistaPalette.emerald),
                                          ]),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                final actions = Wrap(
                                  spacing: 3,
                                  children: [
                                    IconButton(tooltip: 'Update payment', onPressed: () => _showPaymentDialog(order), icon: const Icon(Icons.payments_rounded)),
                                    IconButton(tooltip: 'Void/return sale', onPressed: () => _voidSale(order), icon: const Icon(Icons.undo_rounded, color: SalesVistaPalette.rose)),
                                  ],
                                );
                                if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [body, const SizedBox(height: 8), actions]);
                                return Row(children: [Expanded(child: body), const SizedBox(width: 12), actions]);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<OrderModel> _filteredOrders(List<OrderModel> source) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((o) {
      final matchesSearch = query.isEmpty || o.customerName.toLowerCase().contains(query) || o.productName.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_statusFilter == 'Paid' && o.due > 0) return false;
      if (_statusFilter == 'Partial' && !(o.due > 0 && o.paid > 0)) return false;
      if (_statusFilter == 'Due' && !(o.due > 0 && o.paid <= 0)) return false;
      if (_dateFilter == 'Today' && !_sameDay(o.date, today)) return false;
      if (_dateFilter == 'This Week' && o.date.isBefore(today.subtract(Duration(days: today.weekday - 1)))) return false;
      if (_dateFilter == 'This Month' && (o.date.month != now.month || o.date.year != now.year)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _showPaymentDialog(OrderModel order) async {
    final paid = TextEditingController(text: order.paid.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.customerName} • ${order.productName}'),
            const SizedBox(height: 12),
            TextField(controller: paid, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Paid Amount', helperText: 'Grand Total ${svMoney(order.grandTotal)}')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(paid.text.trim()) ?? 0;
              await _repo.updateOrderPayment(order, value);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _voidSale(OrderModel order) async {
    final reason = TextEditingController(text: 'Customer return / wrong bill');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void / Return Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will delete the sale and invoice, return ${order.quantity.toStringAsFixed(2)} stock to inventory, and save a permanent return-order record.'),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Void Sale')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.voidOrder(order, reason: reason.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale voided, stock returned, and return record saved')));
    }
  }
}
