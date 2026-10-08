import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_3_services/invoice_pdf_service.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  bool _isLoading = false;
  String _statusFilter = 'All';
  String _typeFilter = 'All';
  String _dateFilter = 'All Time';

  final List<String> _statusFilters = const ['All', 'Paid', 'Partial', 'Due'];
  final List<String> _dateFilters = const ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _previewPdf(InvoiceModel invoice) async {
    setState(() => _isLoading = true);
    final pdf = await PdfService.buildInvoicePdfForPreview(invoice);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _generatePdf(InvoiceModel invoice) async {
    setState(() => _isLoading = true);
    await PdfService.generateInvoiceModelPdf(invoice);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _printPdf(InvoiceModel invoice) async {
    setState(() => _isLoading = true);
    await PdfService.printInvoiceModel(invoice);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final invoiceBox = Hive.box<InvoiceModel>('invoice_box');

    return BaseScaffold(
      title: 'Invoices',
      currentRoute: AppRoutes.invoice,
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: invoiceBox.listenable(),
            builder: (context, Box<InvoiceModel> box, _) {
              final invoices = _filteredInvoices(box.values.toList());
              final total = invoices.fold<double>(0, (sum, i) => sum + i.grandTotal);
              final tax = invoices.fold<double>(0, (sum, i) => sum + i.gstAmount);
              final paid = invoices.fold<double>(0, (sum, i) => sum + i.paid);
              final due = invoices.fold<double>(0, (sum, i) => sum + i.due);

              return Column(
                children: [
                  ModernPageHeader(
                    title: 'Invoice Register',
                    subtitle: 'Multi-product GST invoices with PDF preview/download, due tracking, and POS sync.',
                    icon: Icons.description_rounded,
                    actions: [
                      ElevatedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.pos), icon: const Icon(Icons.point_of_sale_rounded), label: const Text('New Invoice')),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ModernMetricCard(title: 'Invoice Value', value: svMoney(total), caption: '${invoices.length} invoices', icon: Icons.description_rounded, color: SalesVistaPalette.primary),
                      ModernMetricCard(title: 'GST', value: svMoney(tax), caption: 'Tax collected', icon: Icons.account_balance_rounded, color: SalesVistaPalette.violet),
                      ModernMetricCard(title: 'Paid', value: svMoney(paid), caption: 'Received', icon: Icons.payments_rounded, color: SalesVistaPalette.emerald),
                      ModernMetricCard(title: 'Due', value: svMoney(due), caption: 'Receivable', icon: Icons.pending_actions_rounded, color: SalesVistaPalette.rose),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ModernSectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        ModernSearchField(controller: _searchController, label: 'Search invoice, customer, GSTIN or product', onChanged: (_) => setState(() {})),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: ModernFilterBar(selected: _statusFilter, options: _statusFilters, onChanged: (value) => setState(() => _statusFilter = value))),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<String>(
                                value: _typeFilter,
                                decoration: const InputDecoration(labelText: 'GST Type'),
                                items: const ['All', 'B2B', 'B2C'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                                onChanged: (value) => setState(() => _typeFilter = value ?? _typeFilter),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                value: _dateFilter,
                                decoration: const InputDecoration(labelText: 'Date'),
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
                    child: invoices.isEmpty
                        ? const ModernEmptyState(title: 'No invoices found', subtitle: 'Create a POS bill or adjust filters.', icon: Icons.description_rounded)
                        : ListView.builder(
                            itemCount: invoices.length,
                            itemBuilder: (context, index) => _invoiceCard(invoices[index]),
                          ),
                  ),
                ],
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.55),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _invoiceCard(InvoiceModel invoice) {
    final statusColor = invoice.due <= 0 ? SalesVistaPalette.emerald : invoice.paid > 0 ? SalesVistaPalette.amber : SalesVistaPalette.rose;
    final statusText = invoice.due <= 0 ? 'Paid' : invoice.paid > 0 ? 'Partial' : 'Due';

    return ModernSectionCard(
      padding: const EdgeInsets.all(14),
      glowColor: statusColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: SalesVistaPalette.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.description_rounded, color: SalesVistaPalette.primary)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Invoice #${invoice.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink, fontSize: 16))),
                        StatusPill(label: statusText, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text('${invoice.customerName} • ${_dateFormat.format(invoice.date)} • ${invoice.itemCount} item(s)', style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, runSpacing: 6, children: [
                      StatusPill(label: invoice.invoiceType, color: invoice.invoiceType == 'B2B' ? SalesVistaPalette.violet : SalesVistaPalette.primary),
                      if ((invoice.buyerGstin ?? '').isNotEmpty) StatusPill(label: invoice.buyerGstin!, color: SalesVistaPalette.violet, icon: Icons.verified_rounded),
                      StatusPill(label: 'Total ${svMoney(invoice.grandTotal)}', color: SalesVistaPalette.primary),
                      StatusPill(label: 'GST ${svMoney(invoice.gstAmount)}', color: SalesVistaPalette.violet),
                      StatusPill(label: 'Due ${svMoney(invoice.due)}', color: statusColor),
                    ]),
                    const SizedBox(height: 8),
                    Text(invoice.safeProductName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SalesVistaPalette.ink, fontWeight: FontWeight.w700)),
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
              OutlinedButton.icon(onPressed: () => _previewPdf(invoice), icon: const Icon(Icons.visibility_rounded), label: const Text('Preview')),
              OutlinedButton.icon(onPressed: () => _printPdf(invoice), icon: const Icon(Icons.print_rounded), label: const Text('Print')),
              ElevatedButton.icon(onPressed: () => _generatePdf(invoice), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('PDF')),
              IconButton(tooltip: 'Void invoice', icon: const Icon(Icons.delete_rounded, color: SalesVistaPalette.rose), onPressed: () => _deleteInvoice(invoice)),
            ],
          );
          if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const SizedBox(height: 12), actions]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: header), const SizedBox(width: 12), actions]);
        },
      ),
    );
  }

  List<InvoiceModel> _filteredInvoices(List<InvoiceModel> source) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((i) {
      final matchesSearch = query.isEmpty || i.id.toLowerCase().contains(query) || i.customerName.toLowerCase().contains(query) || (i.buyerGstin ?? '').toLowerCase().contains(query) || i.safeProductName.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_statusFilter == 'Paid' && i.due > 0) return false;
      if (_statusFilter == 'Partial' && !(i.due > 0 && i.paid > 0)) return false;
      if (_statusFilter == 'Due' && !(i.due > 0 && i.paid <= 0)) return false;
      if (_typeFilter != 'All' && i.invoiceType != _typeFilter) return false;
      if (_dateFilter == 'Today' && !_sameDay(i.date, today)) return false;
      if (_dateFilter == 'This Week' && i.date.isBefore(today.subtract(Duration(days: today.weekday - 1)))) return false;
      if (_dateFilter == 'This Month' && (i.date.month != now.month || i.date.year != now.year)) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _deleteInvoice(InvoiceModel invoice) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Invoice'),
        content: Text('Void invoice #${invoice.id}? This will delete linked sales, remove the payment entry, return sold stock to inventory, and save return-order records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Void Invoice')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.voidInvoice(invoice, reason: 'Deleted from invoice screen');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice voided, stock returned, and return records saved')));
  }
}
