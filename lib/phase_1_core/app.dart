import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class SalesVistaApp extends StatelessWidget {
  const SalesVistaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SalesVista',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.dashboard,
      routes: AppRoutes.routes,
    );
  }
}
