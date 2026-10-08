import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_2_models/expense_model.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  String _dateFilter = 'This Month';
  String _categoryFilter = 'All';

  final List<String> _dateFilters = const ['Today', 'This Week', 'This Month', 'All Time'];
  final List<String> _categoryFilters = const [
    'All',
    ExpenseModel.categoryInventoryRefill,
    ExpenseModel.categorySalary,
    ExpenseModel.categoryOther,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Refill & Expenses',
      currentRoute: AppRoutes.expenses,
      body: PosSyncBuilder(
        builder: (context) {
          final allExpenses = _repo.expensesBox.values.toList();
          final expenses = _filteredExpenses(allExpenses);
          final products = _repo.products();
          final lowStockProducts = products.where((p) => p.isLowStock).toList()
            ..sort((a, b) => a.stock.compareTo(b.stock));

          final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
          final refillTotal = expenses
              .where((e) => e.isInventoryRefill)
              .fold<double>(0, (sum, e) => sum + e.amount);
          final salaryTotal = expenses
              .where((e) => e.isSalary)
              .fold<double>(0, (sum, e) => sum + e.amount);
          final otherTotal = expenses
              .where((e) => e.isOther)
              .fold<double>(0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              ModernPageHeader(
                title: 'Inventory Refill & Expenses',
                subtitle: 'Use one screen for stock refill purchases, salaries, and other operating expenses. Refill entries update stock automatically.',
                icon: Icons.move_down_rounded,
                actions: [
                  ElevatedButton.icon(
                    onPressed: products.isEmpty
                        ? null
                        : () => _showExpenseDialog(
                              initialCategory: ExpenseModel.categoryInventoryRefill,
                            ),
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Refill Inventory'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExpenseDialog(initialCategory: ExpenseModel.categoryOther),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Expense'),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Filtered Spend', value: svMoney(total), caption: _dateFilter, icon: Icons.payments_rounded, color: SalesVistaPalette.primary),
                  ModernMetricCard(title: 'Inventory Refill', value: svMoney(refillTotal), caption: 'Stock purchase', icon: Icons.inventory_2_rounded, color: SalesVistaPalette.emerald),
                  ModernMetricCard(title: 'Salaries', value: svMoney(salaryTotal), caption: 'Payroll entries', icon: Icons.badge_rounded, color: SalesVistaPalette.violet),
                  ModernMetricCard(title: 'Other', value: svMoney(otherTotal), caption: 'Operational expense', icon: Icons.receipt_long_rounded, color: SalesVistaPalette.amber),
                  ModernMetricCard(title: 'Refill Alerts', value: lowStockProducts.length.toString(), caption: 'Low/out stock SKUs', icon: Icons.warning_rounded, color: lowStockProducts.isEmpty ? SalesVistaPalette.emerald : SalesVistaPalette.rose),
                ],
              ),
              const SizedBox(height: 14),
              _refillAlertPanel(lowStockProducts),
              const SizedBox(height: 12),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 760;
                        final search = ModernSearchField(
                          controller: _searchController,
                          label: 'Search title, product, category or note',
                          onChanged: (_) => setState(() {}),
                        );
                        final date = DropdownButtonFormField<String>(
                          value: _dateFilter,
                          decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range_rounded)),
                          items: _dateFilters.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                          onChanged: (value) => setState(() => _dateFilter = value ?? _dateFilter),
                        );
                        if (narrow) {
                          return Column(
                            children: [
                              search,
                              const SizedBox(height: 12),
                              date,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: search),
                            const SizedBox(width: 12),
                            SizedBox(width: 190, child: date),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ModernFilterBar(
                      selected: _categoryFilter,
                      options: _categoryFilters,
                      onChanged: (value) => setState(() => _categoryFilter = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: expenses.isEmpty
                    ? const ModernEmptyState(
                        title: 'No entries found',
                        subtitle: 'Add an inventory refill, salary, or other expense entry.',
                        icon: Icons.receipt_long_rounded,
                      )
                    : ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          final color = _categoryColor(expense.safeCategory);
                          return ModernSectionCard(
                            padding: const EdgeInsets.all(12),
                            glowColor: color,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(18)),
                                child: Icon(_categoryIcon(expense.safeCategory), color: color),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      expense.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink),
                                    ),
                                  ),
                                  StatusPill(label: expense.safeCategory, color: color),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 5,
                                  children: [
                                    Text(_dateFormat.format(expense.date)),
                                    if (expense.isInventoryRefill) Text('Batch: ${expense.safeBatchNumber}'),
                                    if (expense.isInventoryRefill) Text('Product: ${expense.productLabel}'),
                                    if (expense.isInventoryRefill) Text('Refill: ${expense.refillLabel}'),
                                    if (expense.isInventoryRefill) Text('Unit Price: ${svMoney(expense.safeUnitPurchasePrice)}'),
                                    if (expense.isInventoryRefill && expense.posPriceUpdated) Text('POS Price: ${svMoney(expense.sellingPriceAfterRefill)}'),
                                    if (expense.note.trim().isNotEmpty) Text('Note: ${expense.note.trim()}'),
                                  ].map((w) => DefaultTextStyle(style: const TextStyle(fontWeight: FontWeight.w700, color: SalesVistaPalette.muted, fontSize: 12), child: w)).toList(),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(svMoney(expense.amount), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                                  IconButton(
                                    tooltip: expense.isInventoryRefill ? 'Delete and reverse stock refill' : 'Delete expense',
                                    onPressed: () => _confirmDelete(expense),
                                    icon: const Icon(Icons.delete_rounded, color: SalesVistaPalette.rose),
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

  Widget _refillAlertPanel(List<PosProduct> lowStockProducts) {
    if (lowStockProducts.isEmpty) {
      return ModernSectionCard(
        padding: const EdgeInsets.all(14),
        glowColor: SalesVistaPalette.emerald,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: SalesVistaPalette.emerald.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.verified_rounded, color: SalesVistaPalette.emerald),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Stock is healthy. No product is below its refill alert level.',
                style: TextStyle(fontWeight: FontWeight.w800, color: SalesVistaPalette.ink),
              ),
            ),
          ],
        ),
      );
    }

    return ModernSectionCard(
      padding: const EdgeInsets.all(14),
      glowColor: SalesVistaPalette.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SalesVistaPalette.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.notification_important_rounded, color: SalesVistaPalette.amber),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Refill Alerts',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: SalesVistaPalette.ink),
                ),
              ),
              StatusPill(label: '${lowStockProducts.length} item(s)', color: SalesVistaPalette.amber),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: lowStockProducts.take(6).map((product) {
              final color = product.stock <= 0 ? SalesVistaPalette.rose : SalesVistaPalette.amber;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showExpenseDialog(
                  initialCategory: ExpenseModel.categoryInventoryRefill,
                  initialProductId: product.id,
                ),
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(product.stock <= 0 ? Icons.error_rounded : Icons.warning_rounded, color: color, size: 19),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Stock ${product.stock.toStringAsFixed(2)} ${product.unit} • Alert ${product.lowStock.toStringAsFixed(2)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      const Text('Tap to create refill entry', style: TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<ExpenseModel> _filteredExpenses(List<ExpenseModel> source) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((e) {
      final searchable = '${e.title} ${e.safeCategory} ${e.safeBatchNumber} ${e.productName} ${e.note}'.toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) return false;
      if (_categoryFilter != 'All' && e.safeCategory != _categoryFilter) return false;
      if (_dateFilter == 'Today' && !_sameDay(e.date, today)) return false;
      if (_dateFilter == 'This Week' && e.date.isBefore(today.subtract(Duration(days: today.weekday - 1)))) return false;
      if (_dateFilter == 'This Month' && (e.date.month != now.month || e.date.year != now.year)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _showExpenseDialog({
    String initialCategory = ExpenseModel.categoryOther,
    String? initialProductId,
  }) async {
    final products = _repo.products();
    final categories = const [
      ExpenseModel.categoryInventoryRefill,
      ExpenseModel.categorySalary,
      ExpenseModel.categoryOther,
    ];

    String category = categories.contains(initialCategory) ? initialCategory : ExpenseModel.categoryOther;
    String? selectedProductId = products.any((p) => p.id == initialProductId) ? initialProductId : null;
    final selectedProduct = selectedProductId == null ? null : products.where((p) => p.id == selectedProductId).first;

    final title = TextEditingController(
      text: category == ExpenseModel.categoryInventoryRefill && selectedProduct != null ? 'Inventory Refill - ${selectedProduct.name}' : '',
    );
    final amount = TextEditingController();
    final qty = TextEditingController();
    final unitPrice = TextEditingController(text: selectedProduct != null && selectedProduct.purchasePrice > 0 ? selectedProduct.purchasePrice.toStringAsFixed(2) : '');
    final salePrice = TextEditingController(text: selectedProduct?.price.toStringAsFixed(2) ?? '');
    var updatePosPrice = false;
    final note = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isRefill = category == ExpenseModel.categoryInventoryRefill;
          final matchingProducts = selectedProductId == null
              ? <PosProduct>[]
              : products.where((p) => p.id == selectedProductId).toList();
          final PosProduct? currentProduct = matchingProducts.isEmpty ? null : matchingProducts.first;
          final refillQty = double.tryParse(qty.text.trim()) ?? 0;
          final refillUnitPrice = double.tryParse(unitPrice.text.trim()) ?? 0;
          final calculatedRefillTotal = refillQty * refillUnitPrice;

          return AlertDialog(
            title: Text(isRefill ? 'Refill Inventory' : 'Add Expense'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Expense Type', prefixIcon: Icon(Icons.category_rounded)),
                      items: categories.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          category = value ?? category;
                          if (category != ExpenseModel.categoryInventoryRefill) {
                            selectedProductId = null;
                          }
                        });
                      },
                    ),
                    if (isRefill) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        decoration: const InputDecoration(labelText: 'Select Product to Refill', prefixIcon: Icon(Icons.inventory_2_rounded)),
                        items: products
                            .map((product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text('${product.name} • Stock ${product.stock.toStringAsFixed(2)} ${product.unit}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          final product = products.where((p) => p.id == value).toList();
                          setDialogState(() {
                            selectedProductId = value;
                            if (title.text.trim().isEmpty && product.isNotEmpty) {
                              title.text = 'Inventory Refill - ${product.first.name}';
                            }
                            if (product.isNotEmpty) {
                              unitPrice.text = product.first.purchasePrice > 0 ? product.first.purchasePrice.toStringAsFixed(2) : '';
                              salePrice.text = product.first.price.toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                      if (currentProduct != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusPill(
                                label: 'Current ${currentProduct.stock.toStringAsFixed(2)} ${currentProduct.unit} • Alert ${currentProduct.lowStock.toStringAsFixed(2)}',
                                color: currentProduct.isLowStock ? SalesVistaPalette.amber : SalesVistaPalette.emerald,
                                icon: currentProduct.isLowStock ? Icons.warning_rounded : Icons.verified_rounded,
                              ),
                              StatusPill(
                                label: 'Buy ${svMoney(currentProduct.purchasePrice)} • POS ${svMoney(currentProduct.price)}',
                                color: SalesVistaPalette.primary,
                                icon: Icons.price_change_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: SalesVistaPalette.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SalesVistaPalette.primary.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number_rounded, color: SalesVistaPalette.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Auto Batch: ${_repo.previewNextRefillBatchNumber()}',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Refill Quantity ${currentProduct == null ? '' : '(${currentProduct.unit})'}'),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: unitPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Per Quantity Purchase Price', prefixText: '₹ '),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SalesVistaPalette.emerald.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SalesVistaPalette.emerald.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calculate_rounded, color: SalesVistaPalette.emerald),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Total refill cost = ${refillQty.toStringAsFixed(2)} × ${svMoney(refillUnitPrice)}',
                                style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(svMoney(calculatedRefillTotal), style: const TextStyle(color: SalesVistaPalette.emerald, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: updatePosPrice,
                        title: const Text('Update POS selling price also', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: const Text('Turn on only when this refill changes the selling price used in POS checkout.'),
                        onChanged: (value) => setDialogState(() => updatePosPrice = value),
                      ),
                      if (updatePosPrice) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: salePrice,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'New POS Selling Price', prefixText: '₹ '),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title / Reason')),
                    const SizedBox(height: 12),
                    if (!isRefill)
                      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount'))
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Expense amount will be saved as ${svMoney(calculatedRefillTotal)}', style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 12),
                    TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note / Supplier / Salary month')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final refillQty = double.tryParse(qty.text.trim()) ?? 0;
                  final refillUnitPrice = double.tryParse(unitPrice.text.trim()) ?? 0;
                  final calculatedRefillTotal = refillQty * refillUnitPrice;
                  final value = isRefill ? calculatedRefillTotal : (double.tryParse(amount.text.trim()) ?? 0);
                  final newPosPrice = double.tryParse(salePrice.text.trim()) ?? 0;
                  if (value <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than zero')));
                    return;
                  }
                  if (isRefill && (selectedProductId == null || refillQty <= 0 || refillUnitPrice <= 0)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select product, quantity, and per quantity purchase price')));
                    return;
                  }
                  if (isRefill && updatePosPrice && newPosPrice <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid new POS selling price or turn off the toggle')));
                    return;
                  }
                  try {
                    await _repo.addExpense(
                      title.text.trim(),
                      value,
                      category: category,
                      productId: selectedProductId ?? '',
                      refillQuantity: refillQty,
                      unitPurchasePrice: refillUnitPrice,
                      updateSellingPrice: updatePosPrice,
                      newSellingPrice: newPosPrice,
                      note: note.text,
                    );
                    if (mounted) Navigator.pop(context);
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                child: Text(isRefill ? 'Save & Refill Stock' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(ExpenseModel expense) async {
    final message = expense.isInventoryRefill
        ? 'Delete refill batch ${expense.safeBatchNumber} and reverse ${expense.refillLabel} from ${expense.productLabel}?'
        : 'Delete this expense entry?';
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      await _repo.deleteExpense(expense);
      if (mounted) setState(() {});
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case ExpenseModel.categoryInventoryRefill:
        return SalesVistaPalette.emerald;
      case ExpenseModel.categorySalary:
        return SalesVistaPalette.violet;
      case ExpenseModel.categoryOther:
      default:
        return SalesVistaPalette.amber;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case ExpenseModel.categoryInventoryRefill:
        return Icons.inventory_2_rounded;
      case ExpenseModel.categorySalary:
        return Icons.badge_rounded;
      case ExpenseModel.categoryOther:
      default:
        return Icons.receipt_long_rounded;
    }
  }
}
