import 'package:flutter/material.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  String _sort = 'Name';

  final List<String> _filters = const ['All', 'Low Stock', 'Out of Stock', 'GST Items', 'No HSN'];
  final List<String> _sortOptions = const ['Name', 'Stock Low', 'Stock High', 'Value High'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Inventory',
      currentRoute: AppRoutes.inventory,
      body: PosSyncBuilder(
        builder: (context) {
          final products = _filteredProducts();
          final allProducts = _repo.products();
          final stockValue = allProducts.fold<double>(0, (sum, p) => sum + (p.stock * p.purchasePrice));
          final salesValue = allProducts.fold<double>(0, (sum, p) => sum + (p.stock * p.price));
          final lowStock = allProducts.where((p) => p.isLowStock).length;

          return Column(
            children: [
              ModernPageHeader(
                title: 'Inventory Control',
                subtitle: 'Manage SKUs, GST/HSN data, barcode, pricing, stock alerts, and stock adjustments.',
                icon: Icons.inventory_2_rounded,
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _showProductDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Product'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.expenses),
                    icon: const Icon(Icons.move_down_rounded),
                    label: const Text('Refill Stock'),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Products', value: allProducts.length.toString(), caption: '${products.length} visible', icon: Icons.category_rounded, color: SalesVistaPalette.primary),
                  ModernMetricCard(title: 'Low Stock', value: lowStock.toString(), caption: 'Needs reorder', icon: Icons.warning_rounded, color: SalesVistaPalette.amber),
                  ModernMetricCard(title: 'Cost Value', value: svMoney(stockValue), caption: 'At purchase price', icon: Icons.account_balance_wallet_rounded, color: SalesVistaPalette.emerald),
                  ModernMetricCard(title: 'Sales Value', value: svMoney(salesValue), caption: 'At MRP/selling', icon: Icons.sell_rounded, color: SalesVistaPalette.violet),
                ],
              ),
              const SizedBox(height: 14),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ModernSearchField(
                            controller: _searchController,
                            label: 'Search product, SKU, barcode or HSN',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            value: _sort,
                            decoration: const InputDecoration(labelText: 'Sort', prefixIcon: Icon(Icons.sort_rounded)),
                            items: _sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (value) => setState(() => _sort = value ?? _sort),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ModernFilterBar(selected: _filter, options: _filters, onChanged: (value) => setState(() => _filter = value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: products.isEmpty
                    ? const ModernEmptyState(title: 'No inventory found', subtitle: 'Try a different filter or add your first product.', icon: Icons.inventory_2_rounded)
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final stockProgress = p.lowStock <= 0 ? 1.0 : (p.stock / (p.lowStock * 4)).clamp(0.0, 1.0).toDouble();
                          final statusColor = p.stock <= 0 ? SalesVistaPalette.rose : p.isLowStock ? SalesVistaPalette.amber : SalesVistaPalette.emerald;
                          final statusLabel = p.stock <= 0 ? 'Out of Stock' : p.isLowStock ? 'Low Stock' : 'Healthy';
                          return ModernSectionCard(
                            padding: const EdgeInsets.all(14),
                            glowColor: statusColor,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 680;
                                final info = Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(18)),
                                      child: Icon(p.isLowStock ? Icons.warning_rounded : Icons.inventory_rounded, color: statusColor),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SalesVistaPalette.ink))),
                                              StatusPill(label: statusLabel, color: statusColor),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 7,
                                            children: [
                                              Text('SKU: ${p.sku.isEmpty ? '-' : p.sku}'),
                                              Text('Barcode: ${p.barcode.isEmpty ? '-' : p.barcode}'),
                                              Text('HSN: ${p.hsn.isEmpty ? '-' : p.hsn}'),
                                              Text('Unit: ${p.unit}'),
                                              Text('GST ${p.gstPercent.toStringAsFixed(0)}%'),
                                            ].map((w) => DefaultTextStyle(style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700, fontSize: 12), child: w)).toList(),
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: LinearProgressIndicator(value: stockProgress, minHeight: 7, color: statusColor, backgroundColor: const Color(0xFFE2E8F0)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                final actions = Wrap(
                                  spacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                      children: [
                                        Text(svMoney(p.price), style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.primary, fontSize: 15)),
                                        Text('Stock ${p.stock.toStringAsFixed(2)} ${p.unit}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                    IconButton(tooltip: 'Adjust stock', onPressed: () => _showStockDialog(p), icon: const Icon(Icons.tune_rounded)),
                                    IconButton(tooltip: 'Refill from expense screen', onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.expenses), icon: const Icon(Icons.move_down_rounded, color: SalesVistaPalette.emerald)),
                                    IconButton(tooltip: 'Edit', onPressed: () => _showProductDialog(product: p), icon: const Icon(Icons.edit_rounded)),
                                    IconButton(tooltip: 'Delete', onPressed: () => _deleteProduct(p), icon: const Icon(Icons.delete_rounded, color: SalesVistaPalette.rose)),
                                  ],
                                );
                                if (narrow) {
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 12), actions]);
                                }
                                return Row(children: [Expanded(child: info), const SizedBox(width: 12), actions]);
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

  List<PosProduct> _filteredProducts() {
    final query = _searchController.text.trim().toLowerCase();
    var products = _repo.products().where((p) {
      final matchesSearch = query.isEmpty || p.name.toLowerCase().contains(query) || p.sku.toLowerCase().contains(query) || p.barcode.toLowerCase().contains(query) || p.hsn.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      switch (_filter) {
        case 'Low Stock':
          return p.stock > 0 && p.isLowStock;
        case 'Out of Stock':
          return p.stock <= 0;
        case 'GST Items':
          return p.gstPercent > 0;
        case 'No HSN':
          return p.hsn.trim().isEmpty;
        case 'All':
        default:
          return true;
      }
    }).toList();

    if (_sort == 'Stock Low') {
      products.sort((a, b) => a.stock.compareTo(b.stock));
    } else if (_sort == 'Stock High') {
      products.sort((a, b) => b.stock.compareTo(a.stock));
    } else if (_sort == 'Value High') {
      products.sort((a, b) => (b.stock * b.purchasePrice).compareTo(a.stock * a.purchasePrice));
    } else {
      products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return products;
  }

  Future<void> _showProductDialog({PosProduct? product}) async {
    final name = TextEditingController(text: product?.name ?? '');
    final sku = TextEditingController(text: product?.sku ?? '');
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final hsn = TextEditingController(text: product?.hsn ?? '');
    final unit = TextEditingController(text: product?.unit ?? 'PCS');
    final selling = TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    final purchase = TextEditingController(text: product?.purchasePrice.toStringAsFixed(2) ?? '');
    final stock = TextEditingController(text: product?.stock.toStringAsFixed(2) ?? '0');
    final gst = TextEditingController(text: product?.gstPercent.toStringAsFixed(2) ?? '0');
    final lowStock = TextEditingController(text: product?.lowStock.toStringAsFixed(2) ?? '5');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Add Product' : 'Edit Product'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(name, 'Product Name', width: 290),
                _field(sku, 'SKU', width: 140),
                _field(barcode, 'Barcode', width: 220),
                _field(hsn, 'HSN/SAC', width: 120),
                _field(unit, 'Unit', width: 100),
                _field(selling, 'Selling Price', number: true, width: 150),
                _field(purchase, 'Purchase Price', number: true, width: 150),
                _field(stock, product == null ? 'Opening Stock' : 'Current Stock', number: true, width: 150, enabled: product == null),
                _field(gst, 'GST %', number: true, width: 120),
                _field(lowStock, 'Low Stock Alert', number: true, width: 150),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final productName = name.text.trim();
              final sellingPrice = double.tryParse(selling.text.trim()) ?? 0;
              if (productName.isEmpty || sellingPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product name and selling price are required')));
                return;
              }
              await _repo.saveProduct(
                id: product?.id,
                name: productName,
                sellingPrice: sellingPrice,
                openingStock: double.tryParse(stock.text.trim()) ?? 0,
                sku: sku.text,
                barcode: barcode.text,
                hsn: hsn.text,
                unit: unit.text,
                purchasePrice: double.tryParse(purchase.text.trim()) ?? 0,
                gstPercent: double.tryParse(gst.text.trim()) ?? 0,
                lowStock: double.tryParse(lowStock.text.trim()) ?? 5,
              );
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool number = false, double width = 200, bool enabled = true}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _showStockDialog(PosProduct product) async {
    final qty = TextEditingController();
    final note = TextEditingController(text: 'Manual stock adjustment');
    bool isAdd = true;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust Stock - ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('Add')), ButtonSegment(value: false, label: Text('Reduce'))],
                selected: {isAdd},
                onSelectionChanged: (value) => setDialogState(() => isAdd = value.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Reason')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(qty.text.trim()) ?? 0;
                if (value <= 0) return;
                await _repo.adjustStock(product.id, isAdd ? value : -value, note.text);
                if (mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(PosProduct product) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${product.name}? Existing invoices will remain, but this product will be removed from inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      await _repo.deleteProduct(product.id);
      setState(() {});
    }
  }
}
