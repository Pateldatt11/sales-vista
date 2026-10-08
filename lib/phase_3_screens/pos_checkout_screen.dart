import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_3_services/invoice_pdf_service.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_3_services/thermal_printer_service.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class PosCheckoutScreen extends StatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _printerIpController = TextEditingController();
  final TextEditingController _printerPortController = TextEditingController(text: '9100');
  final List<CartLine> _cart = [];
  String _customerId = '';
  String _paymentMode = 'Cash';
  bool _printWalkInAfterSale = true;
  bool _directThermalPrint = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadThermalPrinterSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paidController.dispose();
    _discountController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'POS Billing',
      currentRoute: AppRoutes.pos,
      body: PosSyncBuilder(
        builder: (context) {
          final products = _filteredProducts();
          final customers = _repo.customers();
          final subtotal = _cart.fold<double>(0, (sum, line) => sum + line.lineSubtotal);
          final gst = _cart.fold<double>(0, (sum, line) => sum + line.gstAmount);
          final discount = double.tryParse(_discountController.text.trim()) ?? 0;
          final total = (subtotal + gst - discount).clamp(0, double.infinity).toDouble();

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 950;
              final productPane = _buildProductPane(products);
              final cartPane = _buildCartPane(customers, subtotal, gst, discount, total);

              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: productPane),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: cartPane),
                      ],
                    )
                  : ListView(
                      children: [
                        productPane,
                        const SizedBox(height: 18),
                        cartPane,
                      ],
                    );
            },
          );
        },
      ),
    );
  }

  List<PosProduct> _filteredProducts() {
    final query = _searchController.text.trim().toLowerCase();
    final products = _repo.products();
    if (query.isEmpty) return products;
    return products.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query) ||
          p.hsn.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildProductPane(List<PosProduct> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search product / SKU / barcode / HSN',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.inventory),
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text('Inventory'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No products found. Add products in Inventory.')),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width < 700 ? 1 : 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: p.stock <= 0 ? null : () => _showQtyDialog(p),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: p.stock <= 0
                              ? Colors.red.withOpacity(0.10)
                              : Colors.indigo.withOpacity(0.10),
                          child: Icon(
                            p.stock <= 0 ? Icons.block : Icons.add_shopping_cart_rounded,
                            color: p.stock <= 0 ? Colors.red : Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('SKU: ${p.sku.isEmpty ? '-' : p.sku}  •  HSN: ${p.hsn.isEmpty ? '-' : p.hsn}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Text('Stock: ${p.stock.toStringAsFixed(2)} ${p.unit}', style: TextStyle(color: p.isLowStock ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                            Text('GST ${p.gstPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCartPane(List<PosCustomer> customers, double subtotal, double gst, double discount, double total) {
    final nextInvoiceNo = _repo.previewNextInvoiceNumber();
    PosCustomer? selected;
    for (final customer in customers) {
      if (customer.id == _customerId) {
        selected = customer;
        break;
      }
    }
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(child: Text('Live Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                TextButton.icon(onPressed: _cart.isEmpty ? null : () => setState(_cart.clear), icon: const Icon(Icons.delete_outline), label: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.withOpacity(0.16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 18, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text('Next Invoice No.', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(nextInvoiceNo, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _customerId.isEmpty ? null : _customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
              items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name}${c.gstin.isEmpty ? '' : ' - ${c.gstin}'}'))).toList(),
              onChanged: (value) => setState(() => _customerId = value ?? ''),
            ),
            if (_isWalkInCustomer(selected)) ...[
              const SizedBox(height: 12),
              _buildWalkInPrintOption(),
            ],
            const SizedBox(height: 12),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('Tap a product to add it to the bill.')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cart.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final line = _cart[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${line.quantity.toStringAsFixed(2)} x ₹${line.unitPrice.toStringAsFixed(2)} • GST ${line.gstPercent.toStringAsFixed(0)}%'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${line.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setState(() => _cart.removeAt(index)), icon: const Icon(Icons.close, color: Colors.red)),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount ₹', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMode,
                    decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                    items: const ['Cash', 'UPI', 'Card', 'Bank', 'Credit'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setState(() => _paymentMode = value ?? 'Cash'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Paid Amount',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(onPressed: () => setState(() => _paidController.text = total.toStringAsFixed(2)), child: const Text('Full')),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _amountRow('Subtotal', subtotal),
            _amountRow('GST', gst),
            _amountRow('Discount', -discount),
            const Divider(),
            _amountRow('Grand Total', total, bold: true),
            _amountRow('Due', (total - (double.tryParse(_paidController.text.trim()) ?? 0)).clamp(0, double.infinity).toDouble(), bold: true, color: Colors.red),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving || _cart.isEmpty ? null : () => _checkout(selected),
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_rounded),
                label: const Text('Complete Sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  bool _isWalkInCustomer(PosCustomer? customer) {
    if (customer == null) return true;
    final name = customer.name.trim().toLowerCase().replaceAll(RegExp(r'[-_]+'), ' ');
    final hasGstin = customer.gstin.trim().isNotEmpty;
    return !hasGstin && (name == 'walk in customer' || name == 'walkin customer' || name == 'counter sale');
  }

  Widget _buildWalkInPrintOption() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _printWalkInAfterSale,
            onChanged: (value) => setState(() => _printWalkInAfterSale = value),
            secondary: const Icon(Icons.local_printshop_rounded, color: Colors.indigo),
            title: const Text('Print walk-in receipt after sale', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              _directThermalPrint
                  ? 'Direct ESC/POS network print to 80mm thermal printer.'
                  : 'PDF print fallback with dynamic 80mm receipt paper.',
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          ),
          if (_printWalkInAfterSale) ...[
            const Divider(height: 1),
            SwitchListTile.adaptive(
              value: _directThermalPrint,
              onChanged: (value) async {
                setState(() {
                  _directThermalPrint = value;
                });
                await _saveThermalPrinterSettings(showMessage: false);
              },
              secondary: Icon(
                Icons.cable_rounded,
                color: ThermalPrinterService.isDirectPrintSupported ? Colors.green : Colors.orange,
              ),
              title: const Text('Use direct ESC/POS thermal printer', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                ThermalPrinterService.isDirectPrintSupported
                    ? 'Best for Android/Windows POS app with LAN/Wi-Fi printer on port 9100.'
                    : 'Not available in Chrome/web; app will use PDF print fallback.',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            ),
            if (_directThermalPrint)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _printerIpController,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP',
                              hintText: '192.168.1.50',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _printerPortController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testThermalPrinterConnection,
                            icon: const Icon(Icons.wifi_tethering_rounded),
                            label: const Text('Test printer'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _saveThermalPrinterSettings(showMessage: true),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save printer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadThermalPrinterSettings() async {
    try {
      final box = Hive.isBoxOpen('settingsBox')
          ? Hive.box('settingsBox')
          : await Hive.openBox('settingsBox');
      if (!mounted) return;
      setState(() {
        _printerIpController.text = box.get('thermalPrinterIp', defaultValue: '').toString();
        _printerPortController.text = box.get('thermalPrinterPort', defaultValue: '9100').toString();
        _directThermalPrint = box.get('useDirectThermalPrinter', defaultValue: false) == true;
      });
    } catch (_) {
      // Keep PDF fallback if settings cannot be read.
    }
  }

  ThermalPrinterConfig _currentThermalPrinterConfig() {
    return ThermalPrinterConfig(
      ipAddress: _printerIpController.text.trim(),
      port: int.tryParse(_printerPortController.text.trim()) ?? 9100,
      widthChars: 48,
    );
  }

  Future<void> _saveThermalPrinterSettings({required bool showMessage}) async {
    final config = _currentThermalPrinterConfig();
    try {
      await config.save();
      final box = Hive.isBoxOpen('settingsBox')
          ? Hive.box('settingsBox')
          : await Hive.openBox('settingsBox');
      await box.put('useDirectThermalPrinter', _directThermalPrint);
      if (!mounted || !showMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thermal printer settings saved.')),
      );
    } catch (e) {
      if (!mounted || !showMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save printer settings: $e')),
      );
    }
  }

  Future<void> _testThermalPrinterConnection() async {
    await _saveThermalPrinterSettings(showMessage: false);
    final result = await ThermalPrinterService.testConnection(_currentThermalPrinterConfig());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showQtyDialog(PosProduct product) {
    final qtyController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: qtyController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Quantity (${product.unit})', helperText: 'Available: ${product.stock.toStringAsFixed(2)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0 || qty > product.stock) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity within available stock')));
                return;
              }
              setState(() {
                _cart.add(CartLine(
                  productId: product.id,
                  productName: product.name,
                  quantity: qty,
                  unitPrice: product.price,
                  gstPercent: product.gstPercent,
                  hsn: product.hsn,
                ));
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(PosCustomer? customer) async {
    setState(() => _saving = true);
    try {
      final shouldPrintWalkInReceipt = _printWalkInAfterSale && _isWalkInCustomer(customer);
      final result = await _repo.checkout(
        lines: _cart,
        customerId: customer?.id ?? '',
        customerName: customer?.name ?? 'Walk-in Customer',
        customerGstin: customer?.gstin ?? '',
        placeOfSupply: customer?.stateCode ?? '',
        paidAmount: double.tryParse(_paidController.text.trim()) ?? 0,
        paymentMode: _paymentMode,
        discountAmount: double.tryParse(_discountController.text.trim()) ?? 0,
      );
      setState(() {
        _cart.clear();
        _paidController.clear();
        _discountController.text = '0';
      });
      if (!mounted) return;

      var message = 'Sale completed. Bill ${result.billId} - Total ₹${result.grandTotal.toStringAsFixed(2)}';
      if (shouldPrintWalkInReceipt) {
        final invoice = _repo.invoicesBox.get(result.billId);
        if (invoice != null) {
          try {
            if (_directThermalPrint) {
              await _saveThermalPrinterSettings(showMessage: false);
              final thermalResult = await ThermalPrinterService.printWalkInInvoice(
                invoice,
                config: _currentThermalPrinterConfig(),
              );
              if (thermalResult.success) {
                message = '$message - direct receipt printed';
              } else {
                await PdfService.printInvoiceModel(invoice);
                message = '$message - direct print failed, PDF fallback opened: ${thermalResult.message}';
              }
            } else {
              await PdfService.printInvoiceModel(invoice);
              message = '$message - print dialog opened';
            }
          } catch (printError) {
            message = '$message - print failed: ${printError.toString().replaceFirst('Bad state: ', '')}';
          }
        } else {
          message = '$message - invoice saved but print record was not found';
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
