import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../order/providers/order_provider.dart';

/// Gọi API tạo đơn (`POST /customer/orders`) dùng chung cho các màn đặt đơn
/// (delivery/shopping/topup/ride): xử lý lỗi và điều hướng sau khi thành công.
/// Khi lỗi, gọi [onError] với thông báo lỗi để màn gọi tự cập nhật state của nó.
Future<void> submitBookingOrder({
  required WidgetRef ref,
  required BuildContext context,
  required Map<String, dynamic> data,
  required void Function(String message) onError,
}) async {
  try {
    final res =
        await ref.read(apiClientProvider).post('/customer/orders', data: data);
    final code = (res.data['data'] ?? res.data)['code'] as String;
    ref.read(orderListProvider.notifier).fetch();
    if (context.mounted) {
      context.pushReplacement('/order/$code', extra: 'fromBooking');
    }
  } catch (e) {
    onError(apiErrorMessage(e, 'Không thể đặt đơn.'));
  }
}
