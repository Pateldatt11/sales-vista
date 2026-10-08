import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_3_services/report_export_service.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final PosRepository _repo = PosRepository();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  String _reportType = 'Sales';
  String _datePreset = 'This Month';
  DateTime? _from;
  DateTime? _to;
  bool _exporting = false;

  final List<String> _reportTypes = const [
    'Sales',
    'Invoices',
    'Inventory',
    'Customers',
    'Expenses',
    'Inventory Refill',
    'Transactions',
    'Returns',
    'GSTR1',
  ];

  final List<String> _datePresets = const [
    'Today',
    'This Week',
    'This Month',
    'Last 30 Days',
    'All Time',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _applyPreset(_datePreset, notify: false);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Reports',
      currentRoute: AppRoutes.reports,
      body: PosSyncBuilder(
        builder: (context) {
          final totals = _repo.dashboardTotals();
          final invoices = _filteredInvoices();
          final orders = _filteredOrders();
          final expenses = _filteredExpenses();
          final returns = _filteredReturns();
          final totalSales = invoices.isNotEmpty
              ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.grandTotal)
              : orders.fold<double>(0, (sum, order) => sum + order.grandTotal);
          final collected = invoices.isNotEmpty
              ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.paid)
              : orders.fold<double>(0, (sum, order) => sum + order.paid);
          final due = invoices.isNotEmpty
              ? invoices.fold<double>(0, (sum, invoice) => sum + invoice.due)
              : orders.fold<double>(0, (sum, order) => sum + order.due);
          final expenseTotal = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
          final refillExpenses = expenses.where((expense) => expense.isInventoryRefill).toList();
          final refillTotal = refillExpenses.fold<double>(0, (sum, expense) => sum + expense.amount);
          final returnTotal = returns.fold<double>(0, (sum, record) => sum + record.returnAmount);
          final lowStock = _repo.products().where((p) => p.isLowStock).toList();

          return Stack(
            children: [
              ListView(
                children: [
                  ModernPageHeader(
                    title: 'Report Center',
                    subtitle: 'Generate operational, GST, ledger, inventory, and management reports in PDF, CSV, or XLSX.',
                    icon: Icons.analytics_rounded,
                    actions: [
                      ElevatedButton.icon(
                        onPressed: _exporting ? null : () => _export('pdf'),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export('csv'),
                        icon: const Icon(Icons.table_chart_rounded),
                        label: const Text('CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exporting ? null : () => _export('xlsx'),
                        icon: const Icon(Icons.grid_on_rounded),
                        label: const Text('XLSX'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ModernMetricCard(title: 'Gross Sales', value: svMoney(totalSales), caption: _periodText, icon: Icons.trending_up_rounded, color: SalesVistaPalette.primary),
                      ModernMetricCard(title: 'Collected', value: svMoney(collected), caption: 'Cash flow', icon: Icons.payments_rounded, color: SalesVistaPalette.emerald),
                      ModernMetricCard(title: 'Receivable', value: svMoney(due), caption: 'Pending dues', icon: Icons.pending_actions_rounded, color: SalesVistaPalette.rose),
                      ModernMetricCard(title: 'Expenses', value: svMoney(expenseTotal), caption: 'Filtered period', icon: Icons.money_off_rounded, color: SalesVistaPalette.amber),
                      ModernMetricCard(title: 'Refill Spend', value: svMoney(refillTotal), caption: '${refillExpenses.length} entries', icon: Icons.move_down_rounded, color: SalesVistaPalette.emerald),
                      ModernMetricCard(title: 'Returns', value: svMoney(returnTotal), caption: '${returns.length} rows', icon: Icons.assignment_return_rounded, color: SalesVistaPalette.rose),
                      ModernMetricCard(title: 'Stock Value', value: svMoney(totals['stockValue'] ?? 0), caption: '${_repo.products().length} SKUs', icon: Icons.inventory_2_rounded, color: SalesVistaPalette.violet),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ModernSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Report Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 760;
                            final typePicker = DropdownButtonFormField<String>(
                              value: _reportType,
                              decoration: const InputDecoration(labelText: 'Report Type', prefixIcon: Icon(Icons.folder_copy_rounded)),
                              items: _reportTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                              onChanged: (value) => setState(() => _reportType = value ?? _reportType),
                            );
                            final presetPicker = DropdownButtonFormField<String>(
                              value: _datePreset,
                              decoration: const InputDecoration(labelText: 'Period', prefixIcon: Icon(Icons.date_range_rounded)),
                              items: _datePresets.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                              onChanged: (value) => _applyPreset(value ?? _datePreset),
                            );
                            final customButton = OutlinedButton.icon(
                              onPressed: _pickCustomRange,
                              icon: const Icon(Icons.edit_calendar_rounded),
                              label: Text(_periodText),
                            );
                            if (narrow) {
                              return Column(
                                children: [typePicker, const SizedBox(height: 12), presetPicker, const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: customButton)],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: typePicker),
                                const SizedBox(width: 12),
                                Expanded(child: presetPicker),
                                const SizedBox(width: 12),
                                customButton,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusPill(label: '${orders.length} sales rows', color: SalesVistaPalette.primary, icon: Icons.receipt_long_rounded),
                            StatusPill(label: '${invoices.length} invoices', color: SalesVistaPalette.secondary, icon: Icons.description_rounded),
                            StatusPill(label: '${lowStock.length} low stock', color: SalesVistaPalette.amber, icon: Icons.warning_rounded),
                            StatusPill(label: '${returns.length} returns', color: SalesVistaPalette.rose, icon: Icons.assignment_return_rounded),
                            StatusPill(label: 'PDF / CSV / XLSX ready', color: SalesVistaPalette.emerald, icon: Icons.file_download_done_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 860;
                      final preview = _previewPanel(orders, invoices, expenses);
                      final alerts = _lowStockPanel(lowStock);
                      return wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: preview), const SizedBox(width: 16), Expanded(flex: 2, child: alerts)])
                          : Column(children: [preview, const SizedBox(height: 16), alerts]);
                    },
                  ),
                ],
              ),
              if (_exporting)
                Container(
                  color: Colors.white.withOpacity(0.55),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _previewPanel(List<dynamic> orders, List<dynamic> invoices, List<dynamic> expenses) {
    final title = 'Preview: $_reportType';
    final rows = _previewRows(orders, invoices, expenses);
    return ModernSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
          const SizedBox(height: 8),
          Text('Latest rows for $_periodText', style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const ModernEmptyState(title: 'No data in this period', subtitle: 'Change the filter or create new transactions to generate report rows.', icon: Icons.table_rows_rounded)
          else
            ...rows.take(8).map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: row.color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                          child: Icon(row.icon, color: row.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.ink, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(row.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(row.amount, style: TextStyle(color: row.color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _lowStockPanel(List<dynamic> lowStock) {
    return ModernSectionCard(
      glowColor: SalesVistaPalette.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Low Stock Watchlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
          const SizedBox(height: 12),
          if (lowStock.isEmpty)
            const ModernEmptyState(title: 'Stock is healthy', subtitle: 'No product has crossed its low stock alert level.', icon: Icons.verified_rounded)
          else
            ...lowStock.take(10).map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: SalesVistaPalette.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.warning_rounded, color: SalesVistaPalette.amber)),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
                  subtitle: Text('SKU ${p.sku.isEmpty ? '-' : p.sku} • Alert ${p.lowStock.toStringAsFixed(2)} ${p.unit}'),
                  trailing: Text('${p.stock.toStringAsFixed(2)} ${p.unit}', style: const TextStyle(color: SalesVistaPalette.rose, fontWeight: FontWeight.w900)),
                )),
        ],
      ),
    );
  }

  List<_PreviewRow> _previewRows(List<dynamic> orders, List<dynamic> invoices, List<dynamic> expenses) {
    switch (_reportType) {
      case 'Inventory':
        return _repo.products().take(8).map((p) => _PreviewRow(p.name, 'SKU ${p.sku.isEmpty ? '-' : p.sku} • Stock ${p.stock.toStringAsFixed(2)} ${p.unit}', svMoney(p.stock * p.purchasePrice), Icons.inventory_2_rounded, p.isLowStock ? SalesVistaPalette.amber : SalesVistaPalette.violet)).toList();
      case 'Customers':
        return _repo.customers().take(8).map((c) => _PreviewRow(c.name, c.gstin.isEmpty ? 'Retail customer' : 'GSTIN ${c.gstin}', svMoney(_repo.receivableForCustomer(c.name, customerId: c.id)), Icons.person_rounded, SalesVistaPalette.primary)).toList();
      case 'Expenses':
        return expenses.take(8).map((e) => _PreviewRow(e.displayTitle, e.isInventoryRefill ? '${e.safeBatchNumber} • ${e.refillQuantity.toStringAsFixed(2)} ${e.unit} × ${svMoney(e.safeUnitPurchasePrice)} • ${_dateFormat.format(e.date)}' : '${e.safeCategory} • ${_dateFormat.format(e.date)}', svMoney(e.amount), e.isInventoryRefill ? Icons.inventory_2_rounded : Icons.money_off_rounded, e.isInventoryRefill ? SalesVistaPalette.emerald : SalesVistaPalette.rose)).toList();
      case 'Inventory Refill':
        final refills = _filteredInventoryRefills();
        return refills.take(8).map((e) => _PreviewRow(e.productName, '${e.safeBatchNumber} • ${e.refillQuantity.toStringAsFixed(2)} ${e.unit} × ${svMoney(e.safeUnitPurchasePrice)} • ${_dateFormat.format(e.date)}', svMoney(e.amount), Icons.move_down_rounded, SalesVistaPalette.emerald)).toList();
      case 'Transactions':
        final transactions = _filteredTransactions();
        return transactions.take(8).map((t) => _PreviewRow(t.title, '${t.type.toUpperCase()} • ${_dateFormat.format(t.date)}', svMoney(t.amount), t.type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded, t.type == 'income' ? SalesVistaPalette.emerald : SalesVistaPalette.rose)).toList();
      case 'Returns':
        final returns = _filteredReturns();
        return returns.take(8).map((r) => _PreviewRow(r.id, '${r.customerName} • ${r.productName}', svMoney(r.returnAmount), Icons.assignment_return_rounded, SalesVistaPalette.rose)).toList();
      case 'GSTR1':
      case 'Invoices':
        return invoices.take(8).map((i) => _PreviewRow('#${i.id}', '${i.customerName} • ${i.itemCount} item(s)', svMoney(i.grandTotal), Icons.description_rounded, i.due <= 0 ? SalesVistaPalette.emerald : SalesVistaPalette.amber)).toList();
      case 'Sales':
      default:
        return orders.take(8).map((o) => _PreviewRow(o.customerName, '${o.productName} • ${_dateFormat.format(o.date)}', svMoney(o.grandTotal), Icons.receipt_long_rounded, o.due <= 0 ? SalesVistaPalette.emerald : SalesVistaPalette.rose)).toList();
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final message = await ReportExportService(_repo).export(reportType: _reportType, format: format, from: _from, to: _to);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _applyPreset(String preset, {bool notify = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? to;
    if (preset == 'Today') {
      from = today;
      to = today;
    } else if (preset == 'This Week') {
      from = today.subtract(Duration(days: today.weekday - 1));
      to = today;
    } else if (preset == 'This Month') {
      from = DateTime(today.year, today.month, 1);
      to = today;
    } else if (preset == 'Last 30 Days') {
      from = today.subtract(const Duration(days: 29));
      to = today;
    } else if (preset == 'All Time') {
      from = null;
      to = null;
    }
    if (preset == 'Custom') {
      _pickCustomRange();
      return;
    }
    _datePreset = preset;
    _from = from;
    _to = to;
    if (notify) setState(() {});
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = DateTimeRange(start: _from ?? DateTime(now.year, now.month, 1), end: _to ?? now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() {
      _datePreset = 'Custom';
      _from = picked.start;
      _to = picked.end;
    });
  }

  List<dynamic> _filteredOrders() => _repo.ordersBox.values.where((o) => _isInside(o.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<dynamic> _filteredInvoices() => _repo.invoicesBox.values.where((i) => _isInside(i.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<dynamic> _filteredExpenses() => _repo.expensesBox.values.where((e) => _isInside(e.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<dynamic> _filteredInventoryRefills() => _repo.expensesBox.values.where((e) => e.isInventoryRefill && _isInside(e.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<dynamic> _filteredTransactions() => _repo.transactionsBox.values.where((t) => _isInside(t.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<dynamic> _filteredReturns() => _repo.returnRecords().where((r) => _isInside(r.date)).toList()..sort((a, b) => b.date.compareTo(a.date));

  bool _isInside(DateTime date) {
    final start = _from == null ? null : DateTime(_from!.year, _from!.month, _from!.day);
    final end = _to == null ? null : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999);
    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;
    return true;
  }

  String get _periodText {
    if (_from == null && _to == null) return 'All Time';
    if (_from != null && _to != null) return '${_dateFormat.format(_from!)} - ${_dateFormat.format(_to!)}';
    if (_from != null) return 'From ${_dateFormat.format(_from!)}';
    return 'Up to ${_dateFormat.format(_to!)}';
  }
}

class _PreviewRow {
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color color;

  const _PreviewRow(this.title, this.subtitle, this.amount, this.icon, this.color);
}
