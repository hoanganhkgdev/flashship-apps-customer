import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class PricingConfig {
  final String serviceType;
  final String label;
  final int baseFee;
  final int baseKm;
  final int perKmFee;
  final Map<String, dynamic>? configJson;

  const PricingConfig({
    required this.serviceType,
    required this.label,
    required this.baseFee,
    required this.baseKm,
    required this.perKmFee,
    this.configJson,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> j) => PricingConfig(
        serviceType: j['service_type'] as String,
        label:       j['label']        as String,
        baseFee:     (j['base_fee']    as num).toInt(),
        baseKm:      (j['base_km']     as num).toInt(),
        perKmFee:    (j['per_km_fee']  as num).toInt(),
        configJson:  j['config_json'] as Map<String, dynamic>?,
      );
}

final pricingConfigsProvider =
    FutureProvider.autoDispose<List<PricingConfig>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/pricing/configs');
  final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
  return list.map(PricingConfig.fromJson).toList();
});

// Lấy config của 1 dịch vụ cụ thể
final pricingForProvider = Provider.family<AsyncValue<PricingConfig?>, String>(
  (ref, serviceType) {
    return ref.watch(pricingConfigsProvider).whenData(
      (list) => list.where((c) => c.serviceType == serviceType).firstOrNull,
    );
  },
);
