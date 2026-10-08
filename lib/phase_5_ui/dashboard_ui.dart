import 'package:flutter/material.dart';
import 'package:salesvista/phase_1_core/responsive.dart';

class DashboardUI {
  /// ================================
  /// Responsive Cards Grid
  /// ================================
  static Widget buildResponsiveGrid({
    required BuildContext context,
    required List<Widget> cards,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridCount(context),
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio:
            Responsive.isMobile(context) ? 1.1 : 1.2,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return cards[index];
      },
    );
  }

  /// ================================
  /// Premium Dashboard Card (Pixel Perfect)
  /// ================================
  static Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Icon container (soft background circle)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: color,
            ),
          ),

          const Spacer(),

          /// Value
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 6),

          /// Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// ================================
  /// Modern Drawer Item
  /// ================================
  static Widget buildDrawerItem(
    BuildContext context,
    String title,
    String routeName,
  ) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: const Icon(Icons.circle, size: 8),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () =>
          Navigator.pushReplacementNamed(context, routeName),
    );
  }

  /// ================================
  /// Modern Drawer Header
  /// ================================
  static Widget buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.bottomLeft,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F7C73),
            Color(0xFF3A6351),
          ],
        ),
      ),
      child: const Text(
        "SalesVista",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}