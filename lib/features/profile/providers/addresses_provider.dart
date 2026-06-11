import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/address_model.dart';

class AddressesNotifier extends AsyncNotifier<List<AddressModel>> {
  @override
  Future<List<AddressModel>> build() => _fetch();

  Future<List<AddressModel>> _fetch() async {
    final res  = await ref.read(apiClientProvider).get('/customer/addresses');
    final list = (res.data['data'] ?? res.data) as List;
    return list.cast<Map<String, dynamic>>().map(AddressModel.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> add({
    required String label,
    required String address,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    await ref.read(apiClientProvider).post('/customer/addresses', data: {
      'label':      label,
      'address':    address,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      'is_default': isDefault,
    });
    await refresh();
  }

  Future<void> edit({
    required int id,
    required String label,
    required String address,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    await ref.read(apiClientProvider).put('/customer/addresses/$id', data: {
      'label':      label,
      'address':    address,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      'is_default': isDefault,
    });
    await refresh();
  }

  Future<void> setDefault(int id) async {
    await ref.read(apiClientProvider).patch('/customer/addresses/$id/default');
    await refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(apiClientProvider).delete('/customer/addresses/$id');
    state = AsyncData(
      state.valueOrNull?.where((a) => a.id != id).toList() ?? [],
    );
  }
}

final addressesProvider =
    AsyncNotifierProvider<AddressesNotifier, List<AddressModel>>(
        AddressesNotifier.new);
