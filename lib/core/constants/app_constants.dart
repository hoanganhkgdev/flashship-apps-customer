import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

const Map<String, LatLng> kCityCenters = {
  'Cần Thơ':  LatLng(10.0452, 105.7469),
  'Rạch Giá': LatLng(10.0126, 105.0809),
};

const double kAddressSearchRadiusKm = 25.0;

const Map<String, String> kCitySearchFilter = {
  'Cần Thơ':  'Cần Thơ',
  'Rạch Giá': 'Kiên Giang|Rạch Giá',
};

class AppConstants {
  static const String baseUrl         = 'https://app.flashship.vn/api';
  static const String tokenKey        = 'auth_token';
  static const String userKey         = 'user_data';
  static const String googleMapsApiKey = 'AIzaSyDnE3bCwhzy4tJ22BVmRMyolwuyCx-1rQc';

  static const String facebookUrl = 'https://facebook.com/flashship.vn';
  static const String zaloUrl     = 'https://zalo.me/flashship';
  static const String hotline     = '1900xxxx';
}

class ServiceDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const ServiceDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

const kServices = [
  ServiceDef(
    key: 'delivery',
    label: 'Lấy Hộ',
    icon: Icons.storefront_rounded,
    color: AppColors.delivery,
    bgColor: Color(0xFFFFF3E8),
  ),
  ServiceDef(
    key: 'shopping',
    label: 'Mua Hộ',
    icon: Icons.shopping_bag_rounded,
    color: AppColors.shopping,
    bgColor: Color(0xFFF0EFFF),
  ),
  ServiceDef(
    key: 'topup',
    label: 'Nạp Tiền',
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.topup,
    bgColor: Color(0xFFE8FBF4),
  ),
  ServiceDef(
    key: 'bike',
    label: 'Xe Ôm',
    icon: Icons.electric_moped_rounded,
    color: AppColors.bike,
    bgColor: Color(0xFFFFF8E1),
  ),
  ServiceDef(
    key: 'motor',
    label: 'Lái Xe Máy',
    icon: Icons.motorcycle_rounded,
    color: AppColors.motor,
    bgColor: Color(0xFFEBF4FF),
  ),
  ServiceDef(
    key: 'car',
    label: 'Lái Xe Hơi',
    icon: Icons.directions_car_rounded,
    color: AppColors.car,
    bgColor: Color(0xFFFEECEC),
  ),
];

ServiceDef serviceDefOf(String key) =>
    kServices.firstWhere((s) => s.key == key, orElse: () => kServices.first);
