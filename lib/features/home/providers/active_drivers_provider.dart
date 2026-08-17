import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../profile/providers/active_city_provider.dart';

// Backend chưa có endpoint GET /customer/drivers/active-count — provider này
// trả null khi gọi lỗi (404/...), widget hiển thị sẽ tự ẩn thay vì hardcode số giả.
final activeDriversCountProvider = FutureProvider.autoDispose<int?>((ref) async {
  final cityName = ref.watch(activeCityProvider).cityName;
  if (cityName.isEmpty) return null;
  try {
    final res = await ref.read(apiClientProvider).get(
      '/customer/drivers/active-count',
      params: {'city': cityName},
    );
    final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
    return (data['count'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
});
