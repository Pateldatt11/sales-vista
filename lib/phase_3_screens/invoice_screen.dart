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

                            return ScrollConfiguration(
                              behavior: const ScrollBehavior().copyWith(
                                scrollbars: false,
                                overscroll: false,
                              ),
                              child: ListView.builder(
                                padding:
                                    EdgeInsets.all(horizontalPadding),
                                itemCount: box.length,
                                itemBuilder: (context, index) {
                                  final invoice = box.getAt(index)!;

                                  return Card(
                                    elevation: 6,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          mobile ? 16 : 24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [

                                          // HEADER
                                          mobile
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      "Invoice #${invoice.id}",
                                                      style: TextStyle(
                                                        fontSize:
                                                            titleSize,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Colors
                                                            .indigo
                                                            .shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        height: 6),
                                                    Text(
                                                      invoice.date
                                                          .toLocal()
                                                          .toString()
                                                          .split(' ')[0],
                                                      style:
                                                          const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .grey),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      "Invoice #${invoice.id}",
                                                      style: TextStyle(
                                                        fontSize:
                                                            titleSize,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                        color: Colors
                                                            .indigo
                                                            .shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      invoice.date
                                                          .toLocal()
                                                          .toString()
                                                          .split(' ')[0],
                                                      style:
                                                          const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .grey),
                                                    ),
                                                  ],
                                                ),

                                          const Divider(height: 20),

                                          Text(
                                            "Customer: ${invoice.customerName}",
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: mobile
                                                  ? 14
                                                  : 16,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          Wrap(
                                            spacing: 20,
                                            runSpacing: 8,
                                            children: [
                                              Text(
                                                  "Product: ${invoice.safeProductName}"),
                                              Text(
                                                  "Grand Total: ₹${invoice.grandTotal.toStringAsFixed(2)}"),
                                              Text(
                                                "Paid: ₹${invoice.paid.toStringAsFixed(2)}",
                                                style:
                                                    const TextStyle(
                                                        color: Colors
                                                            .green),
                                              ),
                                              Text(
                                                "Due: ₹${invoice.due.toStringAsFixed(2)}",
                                                style:
                                                    const TextStyle(
                                                        color:
                                                            Colors.red),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 20),

                                          // BUTTONS
                                          mobile
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    AdvancedMorphButton(
                                                      label:
                                                          "Preview",
                                                      icon: Icons
                                                          .visibility,
                                                      gradientColors: [
                                                        Colors
                                                            .indigo
                                                            .shade700,
                                                        Colors
                                                            .indigo
                                                            .shade900
                                                      ],
                                                      onTap: () =>
                                                          _previewPdf(
                                                              invoice),
                                                    ),
                                                    const SizedBox(
                                                        height: 12),
                                                    AdvancedMorphButton(
                                                      label:
                                                          "Download",
                                                      icon: Icons
                                                          .picture_as_pdf,
                                                      gradientColors: [
                                                        Colors
                                                            .red
                                                            .shade700,
                                                        Colors
                                                            .red
                                                            .shade900
                                                      ],
                                                      onTap: () =>
                                                          _generatePdf(
                                                              invoice),
                                                    ),
                                                    const SizedBox(
                                                        height: 8),
                                                    Align(
                                                      alignment:
                                                          Alignment
                                                              .centerRight,
                                                      child:
                                                          IconButton(
                                                        icon: const Icon(
                                                            Icons
                                                                .delete,
                                                            color: Colors
                                                                .grey),
                                                        onPressed:
                                                            () async {
                                                          await invoice
                                                              .delete();

                                                          if (!mounted)
                                                            // ignore: curly_braces_in_flow_control_structures
                                                            return;

                                                          ScaffoldMessenger.of(
                                                                  // ignore: use_build_context_synchronously
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content:
                                                                  Text(
                                                                      "Invoice deleted"),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .end,
                                                  children: [
                                                    AdvancedMorphButton(
                                                      label:
                                                          "Preview",
                                                      icon: Icons
                                                          .visibility,
                                                      gradientColors: [
                                                        Colors
                                                            .indigo
                                                            .shade700,
                                                        Colors
                                                            .indigo
                                                            .shade900
                                                      ],
                                                      onTap: () =>
                                                          _previewPdf(
                                                              invoice),
                                                    ),
                                                    const SizedBox(
                                                        width: 16),
                                                    AdvancedMorphButton(
                                                      label:
                                                          "Download",
                                                      icon: Icons
                                                          .picture_as_pdf,
                                                      gradientColors: [
                                                        Colors
                                                            .red
                                                            .shade700,
                                                        Colors
                                                            .red
                                                            .shade900
                                                      ],
                                                      onTap: () =>
                                                          _generatePdf(
                                                              invoice),
                                                    ),
                                                    const SizedBox(
                                                        width: 16),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors
                                                              .grey),
                                                      onPressed:
                                                          () async {
                                                        await invoice
                                                            .delete();

                                                        if (!mounted)
                                                          // ignore: curly_braces_in_flow_control_structures
                                                          return;

                                                        ScaffoldMessenger.of(
                                                                // ignore: use_build_context_synchronously
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                                "Invoice deleted"),
                                                          ),
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
                  // ignore: deprecated_member_use
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