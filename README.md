# SalesVista Professional POS

This build keeps the existing SalesVista UI and adds a stronger industrial POS data flow:

- Central Hive-based sync listener for POS, inventory, invoices, transactions, expenses, customers and dashboard.
- Multi-product invoice support retained.
- Dashboard now includes KPI cards plus sales trend, cash-flow pie, top-products bar chart and stock-value bar chart.
- Payment updates now sync linked order, invoice, transaction, dashboard totals and customer receivable.
- Invoice void/delete now returns stock, removes linked sales and removes linked payment transaction.
- Sale void/return now updates multi-product invoices correctly and returns stock.
- Expense add/delete now keeps expense and transaction data aligned.
- Customer receivable now calculates from invoices, with customer ID support for edited customer names.
- GSTR-1 CSV export is line-item based for multi-product invoices.

Run:

```bash
flutter pub get
flutter run
```

## Modern UI + Reports Update

This build keeps the existing SalesVista structure and route names while adding:

- Global animated modern page chrome through `BaseScaffold`, so every page gets the same premium background/transition treatment.
- Modern reusable UI widgets in `lib/phase_4_widgets/modern_pos_widgets.dart`.
- Filter/search upgrades for Inventory, Customers, Sales, Invoices, Expenses, Transactions, and Reports.
- Report Center export service in `lib/phase_3_services/report_export_service.dart`.
- Report export support for PDF, CSV, and XLSX across Sales, Invoices, Inventory, Customers, Expenses, Transactions, and GSTR-1 working register.

GST note: the GSTR-1 export is a working register with invoice-level and item-level GST data. Before filing, verify it with the official GST portal/offline utility template required for your current GST filing period.

## Return Order Register Update

This build adds a permanent return order workflow:

- Every voided sale now creates a return record before the sale is removed from active sales.
- Every voided invoice creates one return record per returned invoice line.
- Return records use the pattern `RTN-YYYYMMDD-###`.
- The new **Return Orders** screen includes search, date filtering, refund filtering, return value, refund value, GST reversal, and stock-return metrics.
- Return Orders are also available in the Report Center with PDF, CSV, and XLSX export.
- Backup JSON now includes return-order records.

## Latest update: Inventory Refill + Expenses workflow

- The previous Expenses screen is now **Refill & Expenses** and appears directly after **Inventory** in the app navigation.
- Expense entry types now include **Inventory Refill**, **Salary**, and **Other**.
- Inventory Refill entries use a product dropdown, refill quantity field, amount field, and note/supplier field.
- Saving an Inventory Refill entry automatically increases product stock and writes an expense transaction.
- Deleting an Inventory Refill entry reverses the stock quantity and removes the matching transaction.
- Low/out-of-stock refill alerts are shown on the Refill & Expenses screen with quick refill entry creation.
- Reports now include richer expense columns and a separate **Inventory Refill** export option for PDF, CSV, and XLSX.

## Latest update: Auto Refill Batch Number

- Inventory Refill entries now get an automatic batch number.
- Batch number format: `BATCH-YYYYMMDD-###`, for example `BATCH-20260530-001`.
- The sequence is stored in app settings, so deleting today's refill entry does **not** reuse the old batch number.
- Batch numbers are shown in the Refill & Expenses list, transaction title, backup JSON, and Expense / Inventory Refill reports.

## Latest update: Refill Unit Price, POS Price Toggle, and Generated Report Charts

- Inventory Refill now treats the entered price as **per-quantity purchase price**.
- Refill total is calculated automatically as `refill quantity × per quantity purchase price`.
- Refill entries update product purchase price automatically so inventory stock value stays correct.
- A new toggle in the refill dialog can update the POS selling price for the selected product when required.
- Dashboard now shows **Refill Spend** as a dedicated KPI and hero metric.
- Expense and Inventory Refill reports now include unit purchase price, calculated total amount, POS price update status, and new POS price.
- PDF and XLSX report exports now include a generated chart/summary sheet. CSV includes the same generated chart summary as data because CSV cannot store visual styling.

## Latest update: GSTR-1 Multi-format Export

- The **GST R1 Report** screen now exports GST data in three formats:
  - **CSV** for raw accountant/data checking.
  - **XLSX** for readable Excel workbooks with auto-width columns, separate Summary, Invoice Lines, HSN Summary, and Charts sheets.
  - **PDF** for printable GST R1 review with summary cards, section summary, tax split chart, HSN summary, and invoice line table.
- GSTR-1 exports now include multi-product invoice line items, section classification, HSN summary, tax split, and section-wise totals.
- The export remains a **GSTR-1 working register** for review. Direct GST portal filing/upload may still require the official GST portal/offline-tool JSON schema and accountant verification.

## GST R1 export update

- Fixed web download handling for CSV/XLSX/PDF exports by appending the browser download anchor before click and delaying object URL cleanup.
- XLSX now includes a **State Coverage Map** sheet with all India GST states/UTs, state-wise sales data, invoice count, sold quantity, served/not-served status, and three blue sales tiers.
- The state table is prepared with State + Country + Sales Amount columns so it can also be used for Excel's native **Insert > Maps > Filled Map** workflow.
- PDF and CSV exports also include state service coverage data.

## GSTR-1 India State Coverage Heatmap

This build includes the selected vectorized GST state-code SVG in `assets/maps/india_gst_state_code_map_vectorized.svg` and prints it in GSTR-1 PDF/XLSX exports.

When exporting GSTR-1 PDF, SalesVista groups invoice data by `placeOfSupply`, calculates state-wise sales value, and colors the India map as:

- Dark blue: high sales state
- Blue: medium sales state
- Sky blue: low sales state
- Grey: no service/sale in the selected period

The XLSX GSTR-1 export also keeps the state coverage table and Excel filled-map-ready data. CSV remains raw data only.

## GSTR-1 uploaded India SVG map for PDF and XLSX

- The project now uses the selected `India_gst_state_code_map_vectorized.svg` at `assets/maps/india_gst_state_code_map_vectorized.svg`.
- The SVG was cleaned for Flutter/PDF compatibility and each state path was tagged with an internal ID such as `IN_GJ`, `IN_MH`, `IN_KA`, and `IN_DL`.
- GSTR-1 PDF export prints the real India SVG heatmap with dynamic state coloring from invoice `placeOfSupply` sales data.
- GSTR-1 XLSX export now tries to embed the same generated SVG heatmap into the **State Coverage Map** sheet.
- The XLSX sheet still includes the colored cell map and native Excel Filled Map source table as fallback data for viewers that do not render embedded SVG images.
- Because the uploaded map is an older state-boundary SVG, Telangana uses the available Andhra Pradesh geometry and Ladakh uses the available Jammu & Kashmir geometry on the visual map. The data table still keeps GST states separately.

- GSTR-1 PDF/XLSX exports include the selected vectorized GST state-code reference map (`india_gst_state_code_map_vectorized.svg`) plus the data-driven blue India sales heatmap.

## Latest update: Excel-friendly GSTR-1 CSV
- GSTR-1 CSV export now uses a normal single-table format: one header row and one row per invoice line item.
- Removed multi-section CSV blocks/blank separator rows so the file opens cleanly in Microsoft Excel by default.
- CSV keeps the same core GSTR-1 data: period totals, invoice line details, tax split, HSN, and state coverage fields.
- UTF-8 BOM and Windows CRLF line endings are added for better Excel compatibility.
- For formatted sheets, charts, India map, and separate summary/HSN/state tabs, use XLSX or PDF export.


## GSTR-1 State Coverage Heatmap Fix

The dynamic blue heatmap uses `assets/maps/india_state_heatmap_tagged.svg`, because every state path has its own ID (`IN_GJ`, `IN_MH`, etc.). The uploaded exact embedded SVG is kept as a reference asset, but it is a PNG inside SVG and cannot be recolored state-by-state.

Color tiers:
- Dark blue: high sale state
- Blue: medium sale state
- Sky blue: low sale state
- Grey: no sale/service state

## GSTR-1 XLSX full register update

- GSTR-1 XLSX now includes a **GSTR1 Full Register** sheet that mirrors the old detailed CSV layout:
  - Summary
  - Section Summary
  - Invoice Line Items
  - HSN Summary
  - State Service Coverage
- GSTR-1 XLSX also includes an **Excel Data** sheet that matches the Excel-friendly CSV export as a single normal table.
- The existing Summary, Invoice Lines, HSN Summary, Charts, and State Coverage Map sheets are kept.
