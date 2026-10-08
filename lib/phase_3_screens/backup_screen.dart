import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_3_services/pos_repository.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _importController = TextEditingController();
  String _preview = '';

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Backup & Restore',
      currentRoute: AppRoutes.backup,
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Complete Offline Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Copies products, customers, orders, transactions and settings as JSON. Store it safely before reinstalling or moving device.'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(onPressed: _copyBackup, icon: const Icon(Icons.copy_rounded), label: const Text('Copy Backup JSON')),
                      OutlinedButton.icon(onPressed: _previewBackup, icon: const Icon(Icons.visibility_rounded), label: const Text('Preview Backup')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_preview.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_preview, maxLines: 18),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Restore Master Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Paste backup JSON to restore product master, customer master and settings. Sales history remains safe unless you clear the app data manually.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _importController,
                    maxLines: 8,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Paste backup JSON here'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(onPressed: _restoreMasterData, icon: const Icon(Icons.restore_rounded), label: const Text('Restore Master Data')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyBackup() async {
    final backup = _repo.backupJson();
    await Clipboard.setData(ClipboardData(text: backup));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup JSON copied to clipboard')));
  }

  void _previewBackup() {
    setState(() => _preview = _repo.backupJson());
  }

  Future<void> _restoreMasterData() async {
    try {
      final raw = jsonDecode(_importController.text.trim());
      if (raw is! Map) throw const FormatException('Invalid backup');
      final products = raw['products'];
      if (products is List) {
        for (final item in products) {
          if (item is! Map) continue;
          await _repo.saveProduct(
            id: item['id']?.toString(),
            name: item['name']?.toString() ?? '',
            sellingPrice: _toDouble(item['price']),
            openingStock: _toDouble(item['stock']),
            sku: item['sku']?.toString() ?? '',
            barcode: item['barcode']?.toString() ?? '',
            hsn: item['hsn']?.toString() ?? '',
            unit: item['unit']?.toString() ?? 'PCS',
            purchasePrice: _toDouble(item['purchasePrice']),
            gstPercent: _toDouble(item['gstPercent']),
            lowStock: _toDouble(item['lowStock']) == 0 ? 5 : _toDouble(item['lowStock']),
            replaceStock: true,
          );
        }
      }
      final customers = raw['customers'];
      if (customers is List) {
        for (final item in customers) {
          if (item is! Map) continue;
          await _repo.saveCustomer(
            id: item['id']?.toString(),
            name: item['name']?.toString() ?? '',
            phone: item['phone']?.toString() ?? '',
            email: item['email']?.toString() ?? '',
            gstin: item['gstin']?.toString() ?? '',
            address: item['address']?.toString() ?? '',
            stateCode: item['stateCode']?.toString() ?? '',
          );
        }
      }
      final settings = raw['settings'];
      if (settings is Map) {
        for (final entry in settings.entries) {
          await _repo.settingsBox.put(entry.key.toString(), entry.value);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master data restored')));
      _importController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
