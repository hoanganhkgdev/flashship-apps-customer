import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/voucher_model.dart';

final voucherProvider = AsyncNotifierProvider<VoucherNotifier, List<VoucherModel>>(
  VoucherNotifier.new,
);

class VoucherNotifier extends AsyncNotifier<List<VoucherModel>> {
  @override
  Future<List<VoucherModel>> build() => fetch();

  Future<List<VoucherModel>> fetch() async {
    final res = await ref.read(apiClientProvider).get('/customer/vouchers');
    final list = (res.data['data'] as List)
        .map((e) => VoucherModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
