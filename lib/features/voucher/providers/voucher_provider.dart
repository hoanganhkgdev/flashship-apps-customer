import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/voucher_model.dart';

final voucherProvider =
    AsyncNotifierProvider.autoDispose<VoucherNotifier, List<VoucherModel>>(
  VoucherNotifier.new,
);

class VoucherNotifier extends AutoDisposeAsyncNotifier<List<VoucherModel>> {
  @override
  Future<List<VoucherModel>> build() => fetch();

  Future<List<VoucherModel>> fetch() async {
    final res = await ref.read(apiClientProvider).get('/customer/vouchers');
    final body = res.data;
    final raw = body is List
        ? body
        : body is Map
            ? body['data']
            : null;
    final items = raw is List ? raw : const <dynamic>[];
    final list = items
        .whereType<Map>()
        .map((e) => VoucherModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }
}
