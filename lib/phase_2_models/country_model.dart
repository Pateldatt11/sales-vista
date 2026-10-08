import 'package:hive/hive.dart';

part 'country_model.g.dart';

@HiveType(typeId: 3) // changed from 0 to 3
class CountryModel extends HiveObject {
  @HiveField(0)
  final String countryName;

  @HiveField(1)
  final double totalSales;

  CountryModel({
    required this.countryName,
    required this.totalSales,
  });
}
