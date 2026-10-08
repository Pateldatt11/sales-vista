import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';

class ReturnOrdersScreen extends StatefulWidget {
  const ReturnOrdersScreen({super.key});

  @override
  State<ReturnOrdersScreen> createState() => _ReturnOrdersScreenState();
}

class _ReturnOrdersScreenState extends State<ReturnOrdersScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  String _dateFilter = 'All Time';
  String _refundFilter = 'All';

  final List<String> _dateFilters = const ['Today', 'This Week', 'This Month', 'All Time'];
  final List<String> _refundFilters = const ['All', 'Refunded', 'No Refund'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returnBox = Hive.box('return_orders_box');

    return BaseScaffold(
      title: 'Return Orders',
      currentRoute: AppRoutes.returns,
      body: ValueListenableBuilder(
        valueListenable: returnBox.listenable(),
        builder: (context, Box box, _) {
          final returns = _filteredReturns(_repo.returnRecords());
          final returnValue = returns.fold<double>(0, (sum, record) => sum + record.returnAmount);
          final refundValue = returns.fold<double>(0, (sum, record) => sum + record.refundAmount);
          final stockReturned = returns.fold<double>(0, (sum, record) => sum + record.stockReturned);
          final gstReversed = returns.fold<double>(0, (sum, record) => sum + record.gstAmount);

          return Column(
            children: [
              ModernPageHeader(
                title: 'Return Order Register',
                subtitle: 'Permanent records for every voided sale or invoice, with stock restoration, refund value, GST reversal, and reason tracking.',
                icon: Icons.assignment_return_rounded,
                actions: [
                  OutlinedButton.icon(
                    onPressed: returns.isEmpty ? null : () => _copyCsv(returns),
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Copy CSV'),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Return Value', value: svMoney(returnValue), caption: '${returns.length} return rows', icon: Icons.assignment_return_rounded, color: SalesVistaPalette.rose),
                  ModernMetricCard(title: 'Refunded', value: svMoney(refundValue), caption: 'Paid amount reversed', icon: Icons.payments_rounded, color: SalesVistaPalette.amber),
                  ModernMetricCard(title: 'GST Reversal', value: svMoney(gstReversed), caption: 'Return tax value', icon: Icons.account_balance_rounded, color: SalesVistaPalette.violet),
                  ModernMetricCard(title: 'Stock Returned', value: stockReturned.toStringAsFixed(2), caption: 'Units restored', icon: Icons.inventory_2_rounded, color: SalesVistaPalette.emerald),
                ],
              ),
              const SizedBox(height: 14),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ModernSearchField(controller: _searchController, label: 'Search return ID, invoice, customer, product, or reason', onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 680;
                        final refundFilter = ModernFilterBar(selected: _refundFilter, options: _refundFilters, onChanged: (value) => setState(() => _refundFilter = value));
                        final dateFilter = DropdownButtonFormField<String>(
                          value: _dateFilter,
                          decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range_rounded)),
                          items: _dateFilters.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                          onChanged: (value) => setState(() => _dateFilter = value ?? _dateFilter),
                        );
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [refundFilter, const SizedBox(height: 12), dateFilter],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: refundFilter),
                            const SizedBox(width: 12),
                            SizedBox(width: 190, child: dateFilter),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: returns.isEmpty
                    ? const ModernEmptyState(
                        title: 'No return orders found',
                        subtitle: 'When a sale or invoice is voided, a permanent return record will appear here.',
                        icon: Icons.assignment_return_rounded,
                      )
                    : ListView.builder(
                        itemCount: returns.length,
                        itemBuilder: (context, index) => _returnCard(returns[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _returnCard(ReturnOrderRecord record) {
    final hasRefund = record.refundAmount > 0;
    final color = hasRefund ? SalesVistaPalette.amber : SalesVistaPalette.rose;

    return ModernSectionCard(
      padding: const EdgeInsets.all(14),
      glowColor: color,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.assignment_return_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(record.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink, fontSize: 16))),
                        StatusPill(label: hasRefund ? 'Refunded' : 'No Refund', color: color),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text('${record.customerName} • ${_dateFormat.format(record.date)} • ${record.productName}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (record.invoiceId.isNotEmpty) StatusPill(label: 'Invoice ${record.invoiceId}', color: SalesVistaPalette.primary, icon: Icons.description_rounded),
                        StatusPill(label: 'Qty ${record.quantity.toStringAsFixed(2)}', color: SalesVistaPalette.emerald, icon: Icons.inventory_2_rounded),
                        StatusPill(label: 'Value ${svMoney(record.returnAmount)}', color: SalesVistaPalette.rose),
                        StatusPill(label: 'Refund ${svMoney(record.refundAmount)}', color: SalesVistaPalette.amber),
                        if (record.gstAmount > 0) StatusPill(label: 'GST ${svMoney(record.gstAmount)}', color: SalesVistaPalette.violet),
                      ],
                    ),
                    if (record.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Reason: ${record.reason}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.ink, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(onPressed: () => _showDetails(record), icon: const Icon(Icons.visibility_rounded), label: const Text('Details')),
            ],
          );

          if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [details, const SizedBox(height: 12), actions]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: details), const SizedBox(width: 12), actions]);
        },
      ),
    );
  }

  List<ReturnOrderRecord> _filteredReturns(List<ReturnOrderRecord> source) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return source.where((record) {
      final matchesSearch = query.isEmpty ||
          record.id.toLowerCase().contains(query) ||
          record.invoiceId.toLowerCase().contains(query) ||
          record.orderId.toLowerCase().contains(query) ||
          record.customerName.toLowerCase().contains(query) ||
          record.productName.toLowerCase().contains(query) ||
          record.reason.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_refundFilter == 'Refunded' && record.refundAmount <= 0) return false;
      if (_refundFilter == 'No Refund' && record.refundAmount > 0) return false;
      if (_dateFilter == 'Today' && !_sameDay(record.date, today)) return false;
      if (_dateFilter == 'This Week' && record.date.isBefore(today.subtract(Duration(days: today.weekday - 1)))) return false;
      if (_dateFilter == 'This Month' && (record.date.month != now.month || record.date.year != now.year)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _copyCsv(List<ReturnOrderRecord> records) async {
    final csv = StringBuffer()
      ..writeln('Return ID,Return Date,Original Date,Invoice ID,Order ID,Customer,Product,HSN,Qty,Taxable Value,GST %,GST Amount,Return Amount,Refund Amount,Payment Mode,Reason,Source');

    for (final record in records) {
      csv.writeln(_csv([
        record.id,
        record.date.toIso8601String(),
        record.originalDate?.toIso8601String() ?? '',
        record.invoiceId,
        record.orderId,
        record.customerName,
        record.productName,
        record.hsn,
        record.quantity,
        record.taxableValue,
        record.gstPercent,
        record.gstAmount,
        record.returnAmount,
        record.refundAmount,
        record.paymentMode,
        record.reason,
        record.source,
      ]));
    }

    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filtered return orders copied as CSV')));
  }

  void _showDetails(ReturnOrderRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.id),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Return Date', _dateFormat.format(record.date)),
              _detail('Original Sale Date', record.originalDate == null ? '-' : _dateFormat.format(record.originalDate!)),
              _detail('Invoice ID', record.invoiceId.isEmpty ? '-' : record.invoiceId),
              _detail('Order ID', record.orderId.isEmpty ? '-' : record.orderId),
              _detail('Customer', record.customerName),
              _detail('Product', record.productName),
              _detail('HSN', record.hsn.isEmpty ? '-' : record.hsn),
              _detail('Quantity Returned', record.quantity.toStringAsFixed(2)),
              _detail('Unit Price', svMoney(record.unitPrice)),
              _detail('Taxable Value', svMoney(record.taxableValue)),
              _detail('GST', '${record.gstPercent.toStringAsFixed(2)}% / ${svMoney(record.gstAmount)}'),
              _detail('Return Value', svMoney(record.returnAmount)),
              _detail('Refund Amount', svMoney(record.refundAmount)),
              _detail('Payment Mode', record.paymentMode.isEmpty ? '-' : record.paymentMode),
              _detail('Source', record.source.isEmpty ? '-' : record.source),
              _detail('Reason', record.reason.isEmpty ? '-' : record.reason),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 135, child: Text(label, style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(color: SalesVistaPalette.ink, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  String _csv(List<Object?> values) {
    return values.map((value) {
      final text = value?.toString() ?? '';
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }).join(',');
  }
}
