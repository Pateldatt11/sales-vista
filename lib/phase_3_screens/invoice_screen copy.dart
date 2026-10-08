import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
// ignore: unnecessary_import
import 'package:hive/hive.dart';

import '../phase_2_models/invoice_model.dart';
import 'package:salesvista/phase_3_services/invoice_pdf_service.dart';
import '../phase_1_core/app_routes.dart';
import '../phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_4_widgets/advanced_morph_button.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool _isLoading = false;
  String _searchQuery = "";
  String _sortBy = "Date (Newest)"; // Default sort option

  // ==============================
  // BREAKPOINTS
  // ==============================

  bool isMobile(double width) => width < 600;
  bool isTablet(double width) => width >= 600 && width < 1100;
  bool isDesktop(double width) => width >= 1100;

  // ==============================
  // PDF PREVIEW
  // ==============================

  Future<void> _previewPdf(InvoiceModel invoice) async {
    setState(() => _isLoading = true);

    final pdf = await PdfService.buildInvoicePdfForPreview(invoice);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ==============================
  // PDF DOWNLOAD
  // ==============================

  Future<void> _generatePdf(InvoiceModel invoice) async {
    setState(() => _isLoading = true);

    await PdfService.generateInvoiceModelPdf(invoice);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ==============================
  // BUILD
  // ==============================

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: "Invoices",
      currentRoute: AppRoutes.invoice,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final mobile = isMobile(width);
          final tablet = isTablet(width);
          final desktop = isDesktop(width);

          final horizontalPadding = mobile ? 12.0 : tablet ? 24.0 : 40.0;
          final titleSize = mobile ? 16.0 : tablet ? 18.0 : 20.0;
          final maxContentWidth = desktop ? 900.0 : double.infinity;

          final invoiceBox = Hive.box<InvoiceModel>('invoice_box');

          return Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    children: [
                      // SEARCH AND FILTER BAR
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                hintText: "Search by Name or Invoice ID...",
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  "Sort By: ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _sortBy,
                                      isExpanded: false,
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _sortBy = newValue!;
                                        });
                                      },
                                      items: <String>[
                                        'Date (Newest)',
                                        'Date (Oldest)',
                                        'Customer Name',
                                        'Amount (High-Low)',
                                      ].map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: invoiceBox.listenable(),
                          builder: (context, Box<InvoiceModel> box, _) {
                            if (box.isEmpty) {
                              return const Center(
                                child: Text(
                                  "No invoices generated yet",
                                  style: TextStyle(fontSize: 16),
                                ),
                              );
                            }

                            // Convert to List for searching and sorting
                            List<InvoiceModel> displayList = box.values.where((invoice) {
                              final nameMatch = invoice.customerName
                                  .toLowerCase()
                                  .contains(_searchQuery);
                              final idMatch = invoice.id
                                  .toString()
                                  .contains(_searchQuery);
                              return nameMatch || idMatch;
                            }).toList();

                            // Apply Sorting logic
                            if (_sortBy == 'Date (Newest)') {
                              displayList.sort((a, b) => b.date.compareTo(a.date));
                            } else if (_sortBy == 'Date (Oldest)') {
                              displayList.sort((a, b) => a.date.compareTo(b.date));
                            } else if (_sortBy == 'Customer Name') {
                              displayList.sort((a, b) => a.customerName.compareTo(b.customerName));
                            } else if (_sortBy == 'Amount (High-Low)') {
                              displayList.sort((a, b) => b.grandTotal.compareTo(a.grandTotal));
                            }

                            if (displayList.isEmpty) {
                              return const Center(
                                child: Text("No matching invoices found."),
                              );
                            }

                            return ScrollConfiguration(
                              behavior: const ScrollBehavior().copyWith(
                                scrollbars: false,
                                overscroll: false,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.all(horizontalPadding),
                                itemCount: displayList.length,
                                itemBuilder: (context, index) {
                                  final invoice = displayList[index];

                                  return Card(
                                    elevation: 6,
                                    margin: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(mobile ? 16 : 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // HEADER
                                          mobile
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Invoice #${invoice.id}",
                                                      style: TextStyle(
                                                        fontSize: titleSize,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.indigo.shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      invoice.date.toLocal().toString().split(' ')[0],
                                                      style: const TextStyle(color: Colors.grey),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      "Invoice #${invoice.id}",
                                                      style: TextStyle(
                                                        fontSize: titleSize,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.indigo.shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      invoice.date.toLocal().toString().split(' ')[0],
                                                      style: const TextStyle(color: Colors.grey),
                                                    ),
                                                  ],
                                                ),

                                          const Divider(height: 20),

                                          Text(
                                            "Customer: ${invoice.customerName}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: mobile ? 14 : 16,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          Wrap(
                                            spacing: 20,
                                            runSpacing: 8,
                                            children: [
                                              Text("Product: ${invoice.safeProductName}"),
                                              Text("Grand Total: ₹${invoice.grandTotal.toStringAsFixed(2)}"),
                                              Text(
                                                "Paid: ₹${invoice.paid.toStringAsFixed(2)}",
                                                style: const TextStyle(color: Colors.green),
                                              ),
                                              Text(
                                                "Due: ₹${invoice.due.toStringAsFixed(2)}",
                                                style: const TextStyle(color: Colors.red),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 20),

                                          // BUTTONS
                                          mobile
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    AdvancedMorphButton(
                                                      label: "Preview",
                                                      icon: Icons.visibility,
                                                      gradientColors: [Colors.indigo.shade700, Colors.indigo.shade900],
                                                      onTap: () => _previewPdf(invoice),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    AdvancedMorphButton(
                                                      label: "Download",
                                                      icon: Icons.picture_as_pdf,
                                                      gradientColors: [Colors.red.shade700, Colors.red.shade900],
                                                      onTap: () => _generatePdf(invoice),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.grey),
                                                        onPressed: () async {
                                                          await invoice.delete();
                                                          if (!mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text("Invoice deleted")),
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    AdvancedMorphButton(
                                                      label: "Preview",
                                                      icon: Icons.visibility,
                                                      gradientColors: [Colors.indigo.shade700, Colors.indigo.shade900],
                                                      onTap: () => _previewPdf(invoice),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    AdvancedMorphButton(
                                                      label: "Download",
                                                      icon: Icons.picture_as_pdf,
                                                      gradientColors: [Colors.red.shade700, Colors.red.shade900],
                                                      onTap: () => _generatePdf(invoice),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.grey),
                                                      onPressed: () async {
                                                        await invoice.delete();
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text("Invoice deleted")),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // LOADING OVERLAY
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}