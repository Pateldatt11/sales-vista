import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:salesvista/phase_2_models/country_model.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart'; // Import the reusable BaseScaffold

class CountriesScreen extends StatelessWidget {
  const CountriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final countryBox = Hive.box<CountryModel>('countries_box');

    // Body of the screen
    Widget countriesBody = ValueListenableBuilder(
      valueListenable: countryBox.listenable(),
      builder: (context, Box<CountryModel> box, _) {
        if (box.isEmpty) {
          return const Center(
            child: Text("No countries available"),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final country = box.getAt(index)!;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.public),
                title: Text(
                  country.countryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Total Sales: ${country.totalSales.toStringAsFixed(2)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => country.delete(),
                ),
              ),
            );
          },
        );
      },
    );

    // Return BaseScaffold for consistent sidebar
    return BaseScaffold(
      title: "Countries",
      currentRoute: AppRoutes.countries,
      body: Stack(
        children: [
          countriesBody,
          // Floating action button positioned
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showAddCountryDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCountryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final salesController = TextEditingController();
    final countryBox = Hive.box<CountryModel>('countries_box');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Country"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Country Name",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: salesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Total Sales",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    salesController.text.isEmpty) {
                  return;
                }

                final newCountry = CountryModel(
                  countryName: nameController.text.trim(),
                  totalSales:
                      double.tryParse(salesController.text.trim()) ?? 0.0,
                );

                countryBox.add(newCountry);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
