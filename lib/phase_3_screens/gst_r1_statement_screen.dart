import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../phase_2_models/invoice_model.dart';
import '../phase_1_core/app_routes.dart';
import '../phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_3_services/gstr1_service.dart'; // <-- import the service


class GstR1StatementScreen extends StatefulWidget {
  const GstR1StatementScreen({super.key});

  @override
  State<GstR1StatementScreen> createState() =>
      _GstR1StatementScreenState();
}

class _GstR1StatementScreenState
    extends State<GstR1StatementScreen> {

  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceBox =
        Hive.box<InvoiceModel>('invoice_box');

    return BaseScaffold(
      title: "GST R1 Report",
      currentRoute: AppRoutes.gstr1,
      body: Container(
        color: const Color(0xFFF4F6F8),
        padding:
            const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 28),
        child: ValueListenableBuilder(
          valueListenable:
              invoiceBox.listenable(),
          builder: (context,
              Box<InvoiceModel> box,
              _) {

            final invoices =
                box.values.where((invoice) =>
                    invoice.date.month ==
                        selectedDate.month &&
                    invoice.date.year ==
                        selectedDate.year);

            double taxable = 0;
            double cgst = 0;
            double sgst = 0;
            double igst = 0;
            double total = 0;
            int invoiceCount = 0;

            for (final inv in invoices) {
              invoiceCount++;
              taxable += inv.subtotal;
              cgst += inv.cgst;
              sgst += inv.sgst;
              igst += inv.igst;
              total += inv.grandTotal;
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  /// HEADER with calendar picker and download
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "GST R1 Report",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(
                              height: 6),
                          Text(
                            "Monthly tax summary overview",
                            style: TextStyle(
                              color: Colors
                                  .grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: _pickMonthYear,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  "${selectedDate.month}-${selectedDate.year}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _downloadGstr1File(
                                  invoices.toList());
                            },
                            icon: const Icon(Icons.download),
                            label: const Text("Download GST R1"),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 40),

                  /// KPI CARDS
                  Row(
                    children: [
                      _metricCard(
                          "Total Invoices",
                          invoiceCount
                              .toString()),
                      const SizedBox(
                          width: 20),
                      _metricCard(
                          "Taxable Value",
                          taxable
                              .toStringAsFixed(
                                  2)),
                      const SizedBox(
                          width: 20),
                      _metricCard(
                          "Total GST",
                          (cgst +
                                  sgst +
                                  igst)
                              .toStringAsFixed(
                                  2)),
                    ],
                  ),

                  const SizedBox(
                      height: 40),

                  /// TAX BREAKDOWN FIRST
                  _buildFinanceCard(
                      taxable,
                      cgst,
                      sgst,
                      igst,
                      total),

                  const SizedBox(
                      height: 40),

                  /// GST SUMMARY TABLE
                  Container(
                    padding:
                        const EdgeInsets
                            .all(24),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius
                              .circular(
                                  18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors
                              .black
                              // ignore: deprecated_member_use
                              .withOpacity(
                                  0.05),
                          blurRadius:
                              25,
                          offset:
                              const Offset(
                                  0,
                                  10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          "GST Summary",
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        const SizedBox(
                            height:
                                20),

                        Table(
                          columnWidths:
                              const {
                            0:
                                FlexColumnWidth(
                                    2),
                            1:
                                FlexColumnWidth(),
                            2:
                                FlexColumnWidth(),
                            3:
                                FlexColumnWidth(),
                            4:
                                FlexColumnWidth(),
                            5:
                                FlexColumnWidth(),
                            6:
                                FlexColumnWidth(),
                          },
                          border:
                              TableBorder
                                  .all(
                            color: Colors
                                .grey
                                .shade300,
                          ),
                          children: [

                            _tableHeader(),

                            _tableRow(
                              "B2B",
                              box.values
                                  .where(
                                      (e) =>
                                          e.invoiceType ==
                                              "B2B" &&
                                          e.date.month ==
                                              selectedDate.month &&
                                          e.date.year ==
                                              selectedDate.year)
                                  .length
                                  .toString(),
                              _sum(
                                      box,
                                      "B2B",
                                      "subtotal")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2B",
                                      "cgst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2B",
                                      "sgst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2B",
                                      "igst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2B",
                                      "grandTotal")
                                  .toStringAsFixed(
                                      2),
                            ),

                            _tableRow(
                              "B2C",
                              box.values
                                  .where(
                                      (e) =>
                                          e.invoiceType ==
                                              "B2C" &&
                                          e.date.month ==
                                              selectedDate.month &&
                                          e.date.year ==
                                              selectedDate.year)
                                  .length
                                  .toString(),
                              _sum(
                                      box,
                                      "B2C",
                                      "subtotal")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2C",
                                      "cgst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2C",
                                      "sgst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2C",
                                      "igst")
                                  .toStringAsFixed(
                                      2),
                              _sum(
                                      box,
                                      "B2C",
                                      "grandTotal")
                                  .toStringAsFixed(
                                      2),
                            ),

                            _tableRow(
                              "TOTAL",
                              invoiceCount
                                  .toString(),
                              taxable
                                  .toStringAsFixed(
                                      2),
                              cgst
                                  .toStringAsFixed(
                                      2),
                              sgst
                                  .toStringAsFixed(
                                      2),
                              igst
                                  .toStringAsFixed(
                                      2),
                              total
                                  .toStringAsFixed(
                                      2),
                              isBold: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                      height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Month/Year picker using a dialog
  /// Month-Year Picker using Bottom Sheet
Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Month & Year',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
  
    /// Download using Gstr1Service
  Future<void> _downloadGstr1File(List<InvoiceModel> invoices) async {
    try {
      await Gstr1Service.exportMonthlyGstr1(
        month: selectedDate.month,
        year: selectedDate.year,
        companyStateCode: "KA", // <-- replace with your logic
      );

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "GST R1 for ${selectedDate.month}-${selectedDate.year} downloaded!"),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to download GST R1: $e")),
      );
    }
  }

  // ============================== UI helpers (unchanged) ==============================

  TableRow _tableHeader() {
    return  TableRow(
      decoration: const BoxDecoration(
          color:
              Color(0xFFEDEFF2)),
      children: [
        _cell("Type", true),
        _cell("Invoices", true),
        _cell("Taxable", true),
        _cell("CGST", true),
        _cell("SGST", true),
        _cell("IGST", true),
        _cell("Total", true),
      ],
    );
  }

  TableRow _tableRow(
    String type,
    String inv,
    String taxable,
    String cgst,
    String sgst,
    String igst,
    String total, {
    bool isBold = false,
  }) {
    return TableRow(
      children: [
        _cell(type, isBold),
        _cell(inv, isBold),
        _cell(taxable, isBold),
        _cell(cgst, isBold),
        _cell(sgst, isBold),
        _cell(igst, isBold),
        _cell(total, isBold),
      ],
    );
  }

  static Widget _cell(
      String text,
      bool bold) {
    return Padding(
      padding:
          const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    );
  }

  double _sum(
      Box<InvoiceModel> box,
      String type,
      String field) {

    final filtered =
        box.values.where((e) =>
            e.invoiceType ==
                type &&
            e.date.month ==
                selectedDate.month &&
            e.date.year ==
                selectedDate.year);

    double total = 0;

    for (var inv in filtered) {
      switch (field) {
        case "subtotal":
          total += inv.subtotal;
          break;
        case "cgst":
          total += inv.cgst;
          break;
        case "sgst":
          total += inv.sgst;
          break;
        case "igst":
          total += inv.igst;
          break;
        case "grandTotal":
          total += inv.grandTotal;
          break;
      }
    }

    return total;
  }

  Widget _metricCard(
      String label,
      String value) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets
                .symmetric(
                vertical: 24,
                horizontal: 22),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius
                  .circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Text(label),
            const SizedBox(
                height: 10),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight
                        .w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard(
      double taxable,
      double cgst,
      double sgst,
      double igst,
      double total) {

    return Container(
      padding:
          const EdgeInsets.all(28),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
                18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Text(
            "Tax Breakdown",
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
              height: 28),
          _cleanRow(
              "Taxable",
              taxable),
          const Divider(
              height: 32),
          _cleanRow(
              "CGST", cgst),
          const Divider(
              height: 32),
          _cleanRow(
              "SGST", sgst),
          const Divider(
              height: 32),
          _cleanRow(
              "IGST", igst),
          const Divider(
              height: 40),
          _cleanRow(
              "Total Liability",
              total,
              isBold: true),
        ],
      ),
    );
  }

  Widget _cleanRow(
      String label,
      double value,
      {bool isBold =
          false}) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight:
                isBold
                    ? FontWeight
                        .w600
                    : FontWeight
                        .w400,
          ),
        ),
        Text(
          value
              .toStringAsFixed(2),
          style: TextStyle(
            fontWeight:
                isBold
                    ? FontWeight
                        .w600
                    : FontWeight
                        .w500,
          ),
        ),
      ],
    );
  }
}