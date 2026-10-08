import 'package:flutter/material.dart';
import 'package:salesvista/phase_1_core/responsive.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    }

    if (Responsive.isTablet(context)) {
      return tablet ?? mobile;
    }

    return mobile;
  }
}