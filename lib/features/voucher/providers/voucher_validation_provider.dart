import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/voucher_validation_result.dart';

final voucherValidationServiceProvider = Provider<VoucherValidationService>(
  (ref) => VoucherValidationService(ref.read(apiClientProvider)),
);

class VoucherValidationService {
  const VoucherValidationService(this._apiClient);

  final ApiClient _apiClient;

  Future<VoucherValidationResult> validate({
    required String code,
    required String serviceType,
    required int orderFee,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final response = await _apiClient.post(
      '/customer/vouchers/validate',
      data: {
        'code': normalizedCode,
        'service_type': serviceType,
        'order_total': orderFee,
        'shipping_fee': orderFee,
      },
    );

    return VoucherValidationResult.fromResponse(
      response.data,
      code: normalizedCode,
    );
  }
}
