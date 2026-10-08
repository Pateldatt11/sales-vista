import 'package:flutter/material.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_1_core/app_theme.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/modern_pos_widgets.dart';
import 'package:salesvista/phase_4_widgets/pos_sync_builder.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  final List<String> _filters = const ['All', 'Receivable', 'B2B GSTIN', 'Retail'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Customers',
      currentRoute: AppRoutes.customers,
      body: PosSyncBuilder(
        builder: (context) {
          final customers = _filteredCustomers();
          final allCustomers = _repo.customers();
          final totalReceivable = allCustomers.fold<double>(0, (sum, c) => sum + _repo.receivableForCustomer(c.name, customerId: c.id));
          final b2bCount = allCustomers.where((c) => c.gstin.isNotEmpty).length;

          return Column(
            children: [
              ModernPageHeader(
                title: 'Customer CRM',
                subtitle: 'Maintain contact details, GSTIN, state code, address, and receivable ledger.',
                icon: Icons.groups_rounded,
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _showCustomerDialog(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Customer'),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ModernMetricCard(title: 'Customers', value: allCustomers.length.toString(), caption: '${customers.length} visible', icon: Icons.groups_rounded, color: SalesVistaPalette.primary),
                  ModernMetricCard(title: 'Receivable', value: svMoney(totalReceivable), caption: 'Total outstanding', icon: Icons.payments_rounded, color: SalesVistaPalette.rose),
                  ModernMetricCard(title: 'B2B GSTIN', value: b2bCount.toString(), caption: 'GST registered', icon: Icons.verified_rounded, color: SalesVistaPalette.emerald),
                ],
              ),
              const SizedBox(height: 14),
              ModernSectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ModernSearchField(controller: _searchController, label: 'Search customers, phone, email or GSTIN', onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: ModernFilterBar(selected: _filter, options: _filters, onChanged: (value) => setState(() => _filter = value))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: customers.isEmpty
                    ? const ModernEmptyState(title: 'No customers found', subtitle: 'Add a customer or change the filter.', icon: Icons.person_search_rounded)
                    : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          final due = _repo.receivableForCustomer(c.name, customerId: c.id);
                          final dueColor = due > 0 ? SalesVistaPalette.rose : SalesVistaPalette.emerald;
                          return ModernSectionCard(
                            padding: const EdgeInsets.all(14),
                            glowColor: dueColor,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 700;
                                final main = Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: SalesVistaPalette.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.person_rounded, color: SalesVistaPalette.primary)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: SalesVistaPalette.ink, fontSize: 16)),
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 7,
                                            children: [
                                              if (c.phone.isNotEmpty) Text('Phone: ${c.phone}'),
                                              if (c.email.isNotEmpty) Text('Email: ${c.email}'),
                                              if (c.gstin.isNotEmpty) Text('GSTIN: ${c.gstin}'),
                                              if (c.stateCode.isNotEmpty) Text('State: ${c.stateCode}'),
                                              if (c.address.isNotEmpty) Text('Address: ${c.address}'),
                                            ].map((w) => DefaultTextStyle(style: const TextStyle(color: SalesVistaPalette.muted, fontWeight: FontWeight.w700, fontSize: 12), child: w)).toList(),
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
                                    StatusPill(label: 'Due ${svMoney(due)}', color: dueColor, icon: due > 0 ? Icons.pending_actions_rounded : Icons.check_circle_rounded),
                                    IconButton(onPressed: () => _showCustomerDialog(customer: c), icon: const Icon(Icons.edit_rounded)),
                                    IconButton(onPressed: () => _deleteCustomer(c), icon: const Icon(Icons.delete_rounded, color: SalesVistaPalette.rose)),
                                  ],
                                );
                                if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [main, const SizedBox(height: 12), actions]);
                                return Row(children: [Expanded(child: main), const SizedBox(width: 12), actions]);
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

  List<PosCustomer> _filteredCustomers() {
    final query = _searchController.text.trim().toLowerCase();
    return _repo.customers().where((c) {
      final matchesSearch = query.isEmpty || c.name.toLowerCase().contains(query) || c.phone.toLowerCase().contains(query) || c.email.toLowerCase().contains(query) || c.gstin.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      final receivable = _repo.receivableForCustomer(c.name, customerId: c.id);
      if (_filter == 'Receivable') return receivable > 0;
      if (_filter == 'B2B GSTIN') return c.gstin.isNotEmpty;
      if (_filter == 'Retail') return c.gstin.isEmpty;
      return true;
    }).toList();
  }

  Future<void> _showCustomerDialog({PosCustomer? customer}) async {
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final email = TextEditingController(text: customer?.email ?? '');
    final gstin = TextEditingController(text: customer?.gstin ?? '');
    final stateCode = TextEditingController(text: customer?.stateCode ?? '24');
    final address = TextEditingController(text: customer?.address ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(name, 'Customer Name', width: 280),
                _field(phone, 'Phone', width: 180),
                _field(email, 'Email', width: 240),
                _field(gstin, 'GSTIN', width: 220),
                _field(stateCode, 'State Code', width: 120),
                _field(address, 'Address', width: 560, maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await _repo.saveCustomer(id: customer?.id, name: name.text, phone: phone.text, email: email.text, gstin: gstin.text, stateCode: stateCode.text, address: address.text);
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {double width = 200, int maxLines = 1}) {
    return SizedBox(
      width: width,
      child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label)),
    );
  }

  Future<void> _deleteCustomer(PosCustomer customer) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete ${customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      await _repo.deleteCustomer(customer.id);
      setState(() {});
    }
  }
}
