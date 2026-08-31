import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Kết quả ước tính giá từ `GET /customer/pricing/estimate`.
class PricingEstimate {
  final int fee;
  final int nightSurcharge;
  final double? distanceKm;

  const PricingEstimate({
    required this.fee,
    required this.nightSurcharge,
    this.distanceKm,
  });
}

/// Gọi API ước tính giá dùng chung cho các màn đặt đơn
/// (delivery/shopping/topup/ride). Trả về `null` nếu lỗi (giá tạm thời
/// không khả dụng, không throw để màn gọi không cần try/catch riêng).
Future<PricingEstimate?> fetchPricingEstimate(
  WidgetRef ref,
  Map<String, dynamic> params,
) async {
  try {
    final res = await ref
        .read(apiClientProvider)
        .get('/customer/pricing/estimate', params: params);
    final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
    return PricingEstimate(
      fee: (data['fee'] as num).toInt(),
      nightSurcharge: (data['night_surcharge'] as num?)?.toInt() ?? 0,
      distanceKm: (data['distance_km'] as num?)?.toDouble(),
    );
  } catch (_) {
    return null;
  }
}
