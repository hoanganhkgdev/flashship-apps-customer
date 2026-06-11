import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Fmt {
  static final _vnd = NumberFormat('#,###', 'vi_VN');

  // Cache service labels from backend
  static final Map<String, String> _serviceLabelCache = {};
  static void updateServiceLabels(Map<String, String> labels) {
    _serviceLabelCache
      ..clear()
      ..addAll(labels);
  }
  static final _dtFmt   = DateFormat('dd/MM/yyyy HH:mm');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static String currency(num amount) => '${_vnd.format(amount)}đ';
  static String dateTime(DateTime dt) => _dtFmt.format(dt.toLocal());
  static String date(DateTime dt)     => _dateFmt.format(dt.toLocal());

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
    if (diff.inDays < 7)     return '${diff.inDays} ngày trước';
    return _dateFmt.format(dt);
  }

  static String serviceLabel(String type) {
    if (_serviceLabelCache.containsKey(type)) return _serviceLabelCache[type]!;
    const fallback = {
      'delivery': 'Lấy Hộ', 'shopping': 'Mua Hộ',
      'topup': 'Nạp Tiền', 'bike': 'Xe Ôm',
      'motor': 'Lái Xe Máy', 'car': 'Lái Xe Hơi',
    };
    return fallback[type] ?? type;
  }

  static String orderStatus(String status) {
    const m = {
      'pending':    'Đang tìm tài xế',
      'assigned':   'Tài xế đã nhận',
      'processing': 'Đang lấy hàng',
      'on_the_way': 'Đang giao',
      'completed':  'Hoàn thành',
      'cancelled':  'Đã huỷ',
    };
    return m[status] ?? status;
  }

  static String shortAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)} triệu';
    }
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toString();
  }

  static IconData serviceIcon(String type) {
    const m = {
      'delivery': Icons.storefront_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'topup':    Icons.account_balance_wallet_rounded,
      'bike':     Icons.electric_moped_rounded,
      'motor':    Icons.motorcycle_rounded,
      'car':      Icons.directions_car_rounded,
    };
    return m[type] ?? Icons.local_shipping_rounded;
  }
}
