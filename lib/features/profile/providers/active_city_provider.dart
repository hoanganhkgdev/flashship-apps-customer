import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'cities_provider.dart';

class ActiveCityState {
  final int? cityId;
  final String cityName;
  final String currentAddress;
  final String? currentPlaceName;
  final bool isDetecting;
  final bool isFromGps;

  const ActiveCityState({
    this.cityId,
    this.cityName = '',
    this.currentAddress = '',
    this.currentPlaceName,
    this.isDetecting = false,
    this.isFromGps = false,
  });

  /// Tên hiển thị: placeName nếu có, fallback về currentAddress
  String get displayAddress => (currentPlaceName?.isNotEmpty == true)
      ? currentPlaceName!
      : currentAddress;

  ActiveCityState copyWith({
    int? cityId,
    String? cityName,
    String? currentAddress,
    String? currentPlaceName,
    bool? isDetecting,
    bool? isFromGps,
    bool clearPlaceName = false,
  }) =>
      ActiveCityState(
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        currentAddress: currentAddress ?? this.currentAddress,
        currentPlaceName:
            clearPlaceName ? null : (currentPlaceName ?? this.currentPlaceName),
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
    // Then try GPS detection in background (nó tự seed cityId đã đăng ký
    // trước tiên, đồng bộ, nên UI có ngay dữ liệu dù GPS chưa xong).
    await detectFromGps();
  }

  Future<void> detectFromGps() async {
    state = state.copyWith(isDetecting: true);
    // Luôn đảm bảo có cityId/cityName khu vực đã đăng ký làm baseline TRƯỚC
    // khi thử GPS — nếu GPS lỗi (chưa cấp quyền, giả lập không có vị trí...)
    // thì các tính năng phụ thuộc khu vực (vd lọc gợi ý địa chỉ) vẫn có
    // cityId đúng để dùng, thay vì bị bỏ trống vĩnh viễn như trước.
    if (state.cityId == null) {
      final regUser = _ref.read(authProvider).user;
      if (regUser?.cityId != null) {
        state = state.copyWith(
          cityId: regUser!.cityId,
          cityName:
              (regUser.cityName?.isNotEmpty == true) ? regUser.cityName : null,
        );
      }
    }
    try {
      final Position pos;
      try {
        pos = await LocationService.getCurrentPosition();
      } on LocationException {
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

      final detectedId = data['id'] as int;
      final detectedName = data['name'] as String? ?? '';

      final address =
          await LocationService.addressFromCoords(pos.latitude, pos.longitude);

      // Chỉ dùng GPS để hiển thị địa chỉ hiện tại — KHÔNG cập nhật city đã đăng ký
      // Vì detect GPS có thể trả về city sai khi có nhiều city cùng khu vực
      final user = _ref.read(authProvider).user;
      final registeredCityId = user?.cityId;
      final registeredCityName = user?.cityName ?? '';

      state = state.copyWith(
        cityId: registeredCityId ?? detectedId,
        // Chuỗi rỗng không phải null nên copyWith sẽ GHI ĐÈ tên đã seed
        // trước đó nếu truyền thẳng '' — chỉ truyền khi thật sự có tên.
        cityName: registeredCityId != null
            ? (registeredCityName.isNotEmpty ? registeredCityName : null)
            : detectedName,
        currentAddress: address ?? detectedName,
        clearPlaceName: true,
        isDetecting: false,
        isFromGps: true,
      );
    } catch (_) {
      state = state.copyWith(isDetecting: false);
    }
  }

  void overrideAddress(String address, {String? placeName}) {
    state = state.copyWith(
      currentAddress: address,
      currentPlaceName: placeName,
      clearPlaceName: placeName == null,
      isFromGps: false,
    );
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
