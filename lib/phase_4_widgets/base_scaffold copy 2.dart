// import 'dart:ui';
// import 'package:flutter/material.dart';
// import '../phase_1_core/app_routes.dart';
// import '../phase_1_core/responsive.dart';

// class BaseScaffold extends StatelessWidget {
//   final String title;
//   final Widget body;
//   final String currentRoute;

//   const BaseScaffold({
//     super.key,
//     required this.title,
//     required this.body,
//     required this.currentRoute,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final padding = Responsive.getPadding(context);

//     // ================= MOBILE =================
//     if (Responsive.isMobile(context)) {
//       return Scaffold(
//         appBar: AppBar(title: Text(title), centerTitle: true),
//         drawer: _buildDrawer(context),
//         body: Padding(
//           padding: EdgeInsets.all(padding),
//           child: body,
//         ),
//       );
//     }

//     // ================= TABLET =================
//     if (Responsive.isTablet(context)) {
//       return Scaffold(
//         appBar: AppBar(title: Text(title), centerTitle: true),
//         body: LayoutBuilder(
//           builder: (context, constraints) {
//             final width = constraints.maxWidth;
//             final height = constraints.maxHeight;
//             final shortestSide = width < height ? width : height;

//             double dockWidth = (width * 0.16).clamp(90.0, 160.0);
//             double baseIconSize = (shortestSide * 0.075).clamp(48.0, 90.0);
//             double topSpacing = (baseIconSize * 0.8).clamp(24.0, 60.0);

//             return Row(
//               children: [
//                 _buildTabletDock(context, dockWidth, baseIconSize, topSpacing),
//                 const VerticalDivider(width: 1),
//                 Expanded(
//                   child: Padding(
//                     padding: EdgeInsets.all(padding),
//                     child: body,
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       );
//     }

//     // ================= DESKTOP =================
//     return Scaffold(
//       body: Row(
//         children: [
//           _buildDesktopMacDock(context),
//           Expanded(
//             child: Padding(
//               padding: EdgeInsets.all(padding),
//               child: body,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ================= MOBILE DRAWER =================
//   Widget _buildDrawer(BuildContext context) => Drawer(
//         child: ListView(
//           children: [
//             const DrawerHeader(
//               decoration: BoxDecoration(color: Colors.indigo),
//               child: Text(
//                 "SalesVista",
//                 style: TextStyle(color: Colors.white, fontSize: 22),
//               ),
//             ),
//             ..._routes.map((e) => _drawerItem(context, e)),
//           ],
//         ),
//       );

//   Widget _drawerItem(BuildContext context, _RouteItem item) {
//     final isActive = currentRoute == item.route;
//     return ListTile(
//       leading: Icon(item.icon, color: isActive ? Colors.indigo : null),
//       title: Text(
//         item.title,
//         style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
//       ),
//       onTap: () {
//         if (!isActive) Navigator.pushReplacementNamed(context, item.route);
//       },
//     );
//   }

//   // ================= TABLET DOCK (Frosted Glass) =================
//   Widget _buildTabletDock(
//       BuildContext context, double width, double baseIconSize, double topSpacing) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(20),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//         child: Container(
//           width: width,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.2),
//           ),
//           child: Column(
//             children: [
//               SizedBox(height: topSpacing),
//               Icon(Icons.analytics_rounded, size: baseIconSize * 0.7),
//               SizedBox(height: topSpacing),
//               Expanded(
//                 child: ScrollConfiguration(
//                   behavior: const ScrollBehavior().copyWith(scrollbars: false),
//                   child: _TabletDock(
//                     items: _routes,
//                     currentRoute: currentRoute,
//                     baseIconSize: baseIconSize,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ================= DESKTOP DOCK (Frosted Glass) =================
//   Widget _buildDesktopMacDock(BuildContext context) => ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//           child: Container(
//             width: 130,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Column(
//               children: [
//                 const SizedBox(height: 30),
//                 const Icon(Icons.analytics_rounded, size: 32),
//                 const SizedBox(height: 30),
//                 Expanded(
//                   child: ScrollConfiguration(
//                     behavior: const ScrollBehavior().copyWith(scrollbars: false),
//                     child: SingleChildScrollView(
//                       child: _MacStyleDock(
//                         items: _routes,
//                         currentRoute: currentRoute,
//                         onTap: (route) => Navigator.pushReplacementNamed(context, route),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       );

//   // ================= ROUTES =================
//   List<_RouteItem> get _routes => [
//         _RouteItem("Dashboard", AppRoutes.dashboard, Icons.dashboard_rounded),
//         _RouteItem("Sales", AppRoutes.sales, Icons.trending_up_rounded),
//         _RouteItem("Transactions", AppRoutes.transactions, Icons.receipt_long_rounded),
//         _RouteItem("Users", AppRoutes.users, Icons.group_rounded),
//         _RouteItem("Countries", AppRoutes.countries, Icons.public_rounded),
//         _RouteItem("Invoices", AppRoutes.invoice, Icons.description_rounded),
//         _RouteItem("Orders", AppRoutes.orders, Icons.shopping_cart_rounded),
//         _RouteItem("GST R1", AppRoutes.gstr1, Icons.file_download_rounded),
//         _RouteItem("Company Info", AppRoutes.company, Icons.business_rounded),
//         _RouteItem("Settings", AppRoutes.settings, Icons.settings_rounded),
//       ];
// }

// // ================= TABLET DOCK (TOUCH + MOUSE OPTIMIZED) =================
// class _TabletDock extends StatefulWidget {
//   final List<_RouteItem> items;
//   final String currentRoute;
//   final double baseIconSize;

//   const _TabletDock({
//     required this.items,
//     required this.currentRoute,
//     required this.baseIconSize,
//   });

//   @override
//   State<_TabletDock> createState() => _TabletDockState();
// }

// class _TabletDockState extends State<_TabletDock> {
//   int? _hoverIndex;
//   double? _pointerY;
//   final ScrollController _scrollController = ScrollController();

//   void _updatePointer(double y) => setState(() => _pointerY = y);
//   void _clearPointer() => setState(() {
//         _pointerY = null;
//         _hoverIndex = null;
//       });

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Flexible(
//       child: GestureDetector(
//         onVerticalDragUpdate: (details) {
//           _scrollController.jumpTo(
//             (_scrollController.offset - details.delta.dy).clamp(
//               0.0,
//               _scrollController.position.maxScrollExtent,
//             ),
//           );
//           _updatePointer(details.localPosition.dy);
//         },
//         onVerticalDragEnd: (_) => _clearPointer(),
//         onTapUp: (_) => _clearPointer(),
//         child: MouseRegion(
//           onHover: (event) => _updatePointer(event.localPosition.dy),
//           onExit: (_) => _clearPointer(),
//           child: SingleChildScrollView(
//             controller: _scrollController,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: List.generate(widget.items.length, (i) {
//                 final item = widget.items[i];
//                 final isActive = item.route == widget.currentRoute;

//                 double scale = 1.0;

//                 if (_hoverIndex != null) {
//                   final dist = (i - _hoverIndex!).abs();
//                   scale = (1.5 - dist * 0.25).clamp(1.0, 1.5);
//                 }

//                 if (_pointerY != null) {
//                   final itemHeight = widget.baseIconSize * 1.8;
//                   final center = (itemHeight * i) + (itemHeight / 2);
//                   final distance = (center - _pointerY!).abs();
//                   final proximity = (1.8 - (distance / 140)).clamp(1.0, 1.8);
//                   if (proximity > scale) scale = proximity;
//                 }

//                 if (isActive) scale += 0.3;
//                 scale = scale.clamp(1.0, 2.2);

//                 return MouseRegion(
//                   onEnter: (_) => setState(() => _hoverIndex = i),
//                   onExit: (_) => setState(() => _hoverIndex = null),
//                   child: GestureDetector(
//                     behavior: HitTestBehavior.translucent,
//                     onTap: () => Navigator.pushReplacementNamed(context, item.route),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 300),
//                       curve: Curves.easeOutCubic,
//                       margin: EdgeInsets.symmetric(vertical: widget.baseIconSize * 0.25),
//                       height: widget.baseIconSize * scale,
//                       width: widget.baseIconSize * scale,
//                       decoration: BoxDecoration(
//                         color: isActive
//                             ? Colors.indigo.withOpacity(0.15)
//                             : (_hoverIndex == i ? Colors.grey.shade200 : Colors.transparent),
//                         borderRadius: BorderRadius.circular(100),
//                         boxShadow: isActive
//                             ? [
//                                 BoxShadow(
//                                   color: Colors.indigo.withOpacity(0.4),
//                                   blurRadius: 25,
//                                   spreadRadius: 2,
//                                 ),
//                               ]
//                             : [],
//                       ),
//                       child: Center(
//                         child: Icon(
//                           item.icon,
//                           size: widget.baseIconSize * 0.55,
//                           color: isActive ? Colors.indigo : Colors.grey.shade700,
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ================= DESKTOP MAC STYLE DOCK =================
// class _MacStyleDock extends StatefulWidget {
//   final List<_RouteItem> items;
//   final String currentRoute;
//   final Function(String route) onTap;

//   const _MacStyleDock({
//     required this.items,
//     required this.currentRoute,
//     required this.onTap,
//   });

//   @override
//   State<_MacStyleDock> createState() => _MacStyleDockState();
// }

// class _MacStyleDockState extends State<_MacStyleDock> {
//   int? _hoverIndex;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: List.generate(widget.items.length, (i) {
//         final item = widget.items[i];
//         final isActive = item.route == widget.currentRoute;

//         double hoverScale = 1.0;
//         if (_hoverIndex != null) {
//           final dist = (i - _hoverIndex!).abs();
//           hoverScale = (1.5 - (dist * 0.25)).clamp(1.0, 1.5);
//         }

//         double scale = isActive ? hoverScale + 0.3 : hoverScale;
//         scale = scale.clamp(1.0, 3.5);

//         return MouseRegion(
//           onEnter: (_) => setState(() => _hoverIndex = i),
//           onExit: (_) => setState(() => _hoverIndex = null),
//           child: GestureDetector(
//             onTap: () => widget.onTap(item.route),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 300),
//               curve: Curves.easeOutCubic,
//               margin: const EdgeInsets.symmetric(vertical: 6),
//               height: 48 * scale,
//               width: 48 * scale * 1.2,
//               decoration: BoxDecoration(
//                 color: isActive
//                     ? Colors.indigo.withOpacity(0.15)
//                     : (_hoverIndex == i ? Colors.grey.shade200 : Colors.transparent),
//                 borderRadius: BorderRadius.circular(24),
//               ),
//               child: Icon(
//                 item.icon,
//                 color: isActive ? Colors.indigo : Colors.grey.shade700,
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

// // ================= ROUTE MODEL =================
// class _RouteItem {
//   final String title;
//   final String route;
//   final IconData icon;

//   _RouteItem(this.title, this.route, this.icon);
// }