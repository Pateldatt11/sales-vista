class DashboardSummaryModel {
  final double totalRevenue;
  final double totalProfit;
  final int totalOrders;
  final int tickets;
  final double todayRevenue;
  final double monthlyRevenue;
  final double yearlyRevenue;

  DashboardSummaryModel({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalOrders,
    required this.tickets,
    required this.todayRevenue,
    required this.monthlyRevenue,
    required this.yearlyRevenue,
  });
}
