import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'cities_provider.dart';

class ActiveCityState {
  final int? cityId;
  final String cityName;
  final String currentAddress;
  final bool isDetecting;
  final bool isFromGps;

  const ActiveCityState({
    this.cityId,
    this.cityName = '',
    this.currentAddress = '',
    this.isDetecting = false,
    this.isFromGps = false,
  });

  ActiveCityState copyWith({
    int? cityId,
    String? cityName,
    String? currentAddress,
    bool? isDetecting,
    bool? isFromGps,
  }) =>
      ActiveCityState(
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        currentAddress: currentAddress ?? this.currentAddress,
        isDetecting: isDetecting ?? this.isDetecting,
        isFromGps: isFromGps ?? this.isFromGps,
      );
}

class ActiveCityNotifier extends StateNotifier<ActiveCityState> {
  final ApiClient _api;
  final Ref _ref;

  ActiveCityNotifier(this._api, this._ref) : super(const ActiveCityState()) {
    _init();
  }

  Future<void> _init() async {
    // Seed from profile first so UI shows something immediately
    final user = _ref.read(authProvider).user;
    if (user != null && user.cityId != 1) {
      state = state.copyWith(
        cityId: user.cityId,
        cityName: user.cityName ?? '',
      );
    }
    // Then try GPS detection in background
    await detectFromGps();
  }

  Future<void> detectFromGps() async {
    state = state.copyWith(isDetecting: true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        state = state.copyWith(isDetecting: false);
        return;
      }

      final res = await _api.get('/cities/nearest', params: {
        'lat': pos.latitude,
        'lng': pos.longitude,
      });

      final data = res.data['data'];
      if (data == null) {
        state = state.copyWith(isDetecting: false);
        return;
      }

      final detectedId   = data['id'] as int;
      final detectedName = data['name'] as String? ?? '';

      final address = await LocationService.addressFromCoords(pos.latitude, pos.longitude);

      // Chỉ dùng GPS để hiển thị địa chỉ hiện tại — KHÔNG cập nhật city đã đăng ký
      // Vì detect GPS có thể trả về city sai khi có nhiều city cùng khu vực
      final user = _ref.read(authProvider).user;
      final registeredCityId   = user?.cityId;
      final registeredCityName = user?.cityName ?? '';

      state = state.copyWith(
        // Ưu tiên city đã đăng ký, chỉ dùng GPS city nếu chưa có city nào
        cityId:         registeredCityId ?? detectedId,
        cityName:       registeredCityId != null ? registeredCityName : detectedName,
        currentAddress: address ?? detectedName,
        isDetecting: false,
        isFromGps: true,
      );
    } catch (_) {
      state = state.copyWith(isDetecting: false);
    }
  }

  void overrideAddress(String address) {
    state = state.copyWith(currentAddress: address, isFromGps: false);
  }

  void overrideCity(CityItem city) {
    state = state.copyWith(
      cityId: city.id,
      cityName: city.name,
      isFromGps: false,
    );
    // Persist manual override to profile
    final user = _ref.read(authProvider).user;
    if (user != null) {
      _ref.read(authProvider.notifier).updateProfile(
        name: user.name,
        email: user.email,
        cityId: city.id,
        cityName: city.name,
      );
    }
  }
}

final activeCityProvider =
    StateNotifierProvider<ActiveCityNotifier, ActiveCityState>((ref) {
  return ActiveCityNotifier(ref.read(apiClientProvider), ref);
});
