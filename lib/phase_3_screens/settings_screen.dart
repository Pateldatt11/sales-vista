import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _stateCodeController = TextEditingController();
  final TextEditingController _invoicePrefixController = TextEditingController();
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _stateCodeController.text = _repo.settingsBox.get('companyStateCode', defaultValue: '24').toString();
    _invoicePrefixController.text = _repo.settingsBox.get('invoicePrefix', defaultValue: 'INV').toString();
  }

  @override
  void dispose() {
    _stateCodeController.dispose();
    _invoicePrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Settings',
      currentRoute: AppRoutes.settings,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GST & Billing Defaults', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stateCodeController,
                    decoration: const InputDecoration(labelText: 'Company State Code', helperText: 'Used for IGST vs CGST/SGST split. Gujarat = 24.', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _invoicePrefixController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Invoice Prefix',
                      helperText: 'Invoice pattern: PREFIX-YYYYMMDD-001. Example: ${_repo.previewNextInvoiceNumber()}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _repo.settingsBox.put('companyStateCode', _stateCodeController.text.trim().isEmpty ? '24' : _stateCodeController.text.trim());
                      final cleanPrefix = _invoicePrefixController.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                      await _repo.settingsBox.put('invoicePrefix', cleanPrefix.isEmpty ? 'INV' : cleanPrefix);
                      _invoicePrefixController.text = cleanPrefix.isEmpty ? 'INV' : cleanPrefix;
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Visual placeholder. Full theme switching can be connected later.'),
            value: isDarkMode,
            onChanged: (value) => setState(() => isDarkMode = value),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_rounded, color: Colors.indigo),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export JSON and restore master data'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Deletes sales, inventory, customers, invoices, transactions and reports'),
            onTap: _showClearConfirmation,
          ),
          const Divider(),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('App Version'), subtitle: Text('SalesVista Professional POS v2.0')),
          const ListTile(leading: Icon(Icons.business), title: Text('Company'), subtitle: Text('Configure company details from Company Info')),
        ],
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This permanently deletes all local app data. Export a backup first. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _clearAllBoxes();
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllBoxes() async {
    for (final name in [
      'sales_box',
      'transactions_box',
      'users_box',
      'countries_box',
      'orders_box',
      'invoice_box',
      'expenses_box',
      'inventory_meta_box',
      'customers_box',
      'app_audit_box',
    ]) {
      if (Hive.isBoxOpen(name)) await Hive.box(name).clear();
    }
  }
}
