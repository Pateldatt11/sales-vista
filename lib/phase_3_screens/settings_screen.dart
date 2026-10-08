import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart'; // Reusable BaseScaffold

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: "Settings",
      currentRoute: AppRoutes.settings,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [

          // ===== Theme Switch =====
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });

              // NOTE:
              // This only toggles switch visually.
              // Full theme switching requires state management.
            },
          ),

          const Divider(),

          // ===== Clear Data =====
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Clear All Data"),
            onTap: _showClearConfirmation,
          ),

          const Divider(),

          // ===== App Info =====
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("App Version"),
            subtitle: Text("SalesVista v1.0.0"),
          ),

          const ListTile(
            leading: Icon(Icons.business),
            title: Text("Company"),
            subtitle: Text("SalesVista Solutions"),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Clear All Data"),
          content: const Text(
              "This will permanently delete all app data. Continue?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _clearAllBoxes();
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllBoxes() async {
    await Hive.box('sales_box').clear();
    await Hive.box('transactions_box').clear();
    await Hive.box('users_box').clear();
    await Hive.box('countries_box').clear();

    // If invoice box exists
    if (Hive.isBoxOpen('invoice_box')) {
      await Hive.box('invoice_box').clear();
    }
  }
}
