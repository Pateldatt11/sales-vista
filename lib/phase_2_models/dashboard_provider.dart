import 'sales_model.dart';
import 'dashboard_summary_model.dart';

class DashboardProvider {
  final List<SalesModel> _sales = [
    SalesModel(
      id: '1',
      productName: 'Product A',
      amount: 1200,
      date: DateTime.now(), customerName: '',
    ),
    SalesModel(
      id: '2',
      productName: 'Product B',
      amount: 800,
      date: DateTime.now(), customerName: '',
    ),
  ];

  List<SalesModel> get sales => _sales;

  DashboardSummaryModel getDashboardSummary() {
    final totalRevenue =
        _sales.fold(0.0, (sum, item) => sum + item.amount);

    final totalOrders = _sales.length;

    final todayRevenue = _sales
        .where((sale) =>
            sale.date.day == DateTime.now().day &&
            sale.date.month == DateTime.now().month &&
            sale.date.year == DateTime.now().year)
        .fold(0.0, (sum, item) => sum + item.amount);

    return DashboardSummaryModel(
      totalRevenue: totalRevenue,
      totalProfit: totalRevenue * 0.30, // example 30% margin
      totalOrders: totalOrders,
      tickets: 5,
      todayRevenue: todayRevenue,
      monthlyRevenue: totalRevenue,
      yearlyRevenue: totalRevenue,
    );
  }
}
