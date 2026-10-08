import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_2_models/order_model.dart';
import 'package:salesvista/phase_2_models/transaction_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  String selectedType = 'income';
  String _typeFilter = 'All';
  String _dateFilter = 'All Time';

  final List<String> _typeFilters = const ['All', 'Income', 'Expense', 'Managed'];
  final List<String> _dateFilters = const ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionBox = Hive.box<TransactionModel>('transactions_box');
    final orderBox = Hive.box<OrderModel>('orders_box');

    return BaseScaffold(
      title: 'Transactions',
      currentRoute: AppRoutes.transactions,
      body: ValueListenableBuilder(
        valueListenable: transactionBox.listenable(),
        builder: (context, Box<TransactionModel> box, _) {
          final transactions = _filteredTransactions(box.values.toList());
          final income = transactions.where((t) => t.type == 'income').fold<double>(0, (sum, t) => sum + t.amount);
          final expense = transactions.where((t) => t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
          final managed = transactions.where((t) => _repo.invoicesBox.get(t.id) != null || t.orderId != null).length;

          return Column(
            children: [
              ModernPageHeader(
                title: 'Transaction Ledger',
                subtitle: 'Income, expense, POS payment, and invoice-linked transaction records.',
                icon: Icons.receipt_long_rounded,
                actions: [
                  ElevatedButton.icon(onPressed: () => _showAddTransactionDialog(context, transactionBox), icon: const Icon(Icons.add_rounded), label: const Text('Add Transaction')),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Income', value: svMoney(income), caption: _dateFilter, icon: Icons.south_west_rounded, color: SalesVistaPalette.emerald),
                  ModernMetricCard(title: 'Expense', value: svMoney(expense), caption: _dateFilter, icon: Icons.north_east_rounded, color: SalesVistaPalette.rose),
                  ModernMetricCard(title: 'Net Cash', value: svMoney(income - expense), caption: 'Income - expense', icon: Icons.account_balance_wallet_rounded, color: SalesVistaPalette.primary),
                  ModernMetricCard(title: 'Managed', value: managed.toString(), caption: 'Linked payments', icon: Icons.sync_alt_rounded, color: SalesVistaPalette.violet),
                ],
              ),
              const SizedBox(height: 14),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ModernSearchField(controller: _searchController, label: 'Search title, amount or type', onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ModernFilterBar(selected: _typeFilter, options: _typeFilters, onChanged: (value) => setState(() => _typeFilter = value))),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 190,
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
                child: transactions.isEmpty
                    ? const ModernEmptyState(title: 'No transactions found', subtitle: 'Add a ledger entry or relax the current filters.', icon: Icons.receipt_long_rounded)
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final isIncome = transaction.type == 'income';
                          OrderModel? linkedOrder;
                          if (transaction.orderId != null) {
                            try {
                              linkedOrder = orderBox.values.firstWhere((o) => o.id == transaction.orderId);
                            } catch (_) {
                              linkedOrder = null;
                            }
                          }
                          final linkedInvoice = _repo.invoicesBox.get(transaction.id);
                          final isManagedPayment = transaction.type == 'income' && (linkedInvoice != null || linkedOrder != null);
                          final amount = linkedInvoice != null ? linkedInvoice.paid : linkedOrder != null ? linkedOrder.paid : transaction.amount;
                          final due = linkedInvoice != null ? linkedInvoice.due : linkedOrder != null ? linkedOrder.due : 0.0;
                          final customerName = linkedInvoice?.customerName ?? linkedOrder?.customerName ?? '';
                          final color = isIncome ? SalesVistaPalette.emerald : SalesVistaPalette.rose;

                          return ModernSectionCard(
                            padding: const EdgeInsets.all(12),
                            glowColor: color,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(18)), child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: color)),
                              title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink)),
                              subtitle: Text(
                                isManagedPayment
                                    ? 'Customer: $customerName • Paid ${svMoney(amount)} • Due ${svMoney(due)} • ${_dateFormat.format(transaction.date)}'
                                    : '${transaction.type.toUpperCase()} • ${_dateFormat.format(transaction.date)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: SalesVistaPalette.muted),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusPill(label: svMoney(amount), color: color),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: SalesVistaPalette.rose),
                                    onPressed: () async {
                                      if (isManagedPayment) {
                                        await _repo.cancelPaymentTransaction(transaction);
                                      } else {
                                        await transaction.delete();
                                      }
                                    },
                                  ),
                                ],
                              ),
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

  List<TransactionModel> _filteredTransactions(List<TransactionModel> source) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((t) {
      final linked = _repo.invoicesBox.get(t.id) != null || t.orderId != null;
      if (query.isNotEmpty && !('${t.title} ${t.type} ${t.amount}'.toLowerCase()).contains(query)) return false;
      if (_typeFilter == 'Income' && t.type != 'income') return false;
      if (_typeFilter == 'Expense' && t.type != 'expense') return false;
      if (_typeFilter == 'Managed' && !linked) return false;
      if (_dateFilter == 'Today' && !_sameDay(t.date, today)) return false;
      if (_dateFilter == 'This Week' && t.date.isBefore(today.subtract(Duration(days: today.weekday - 1)))) return false;
      if (_dateFilter == 'This Month' && (t.date.month != now.month || t.date.year != now.year)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _showAddTransactionDialog(BuildContext context, Box<TransactionModel> transactionBox) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedType = value ?? selectedType);
                    setState(() {});
                  },
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (titleController.text.trim().isEmpty || amount <= 0) return;
                  final newTransaction = TransactionModel(id: const Uuid().v4(), title: titleController.text.trim(), amount: amount, type: selectedType, date: DateTime.now(), orderId: null);
                  transactionBox.add(newTransaction);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
