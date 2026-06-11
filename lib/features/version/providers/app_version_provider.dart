import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_constants.dart';

class AppVersionState {
  final bool isChecked;
  final bool needsForceUpdate;
  final bool needsSoftUpdate;
  final String? storeUrl;
  final String message;

  const AppVersionState({
    this.isChecked      = false,
    this.needsForceUpdate = false,
    this.needsSoftUpdate  = false,
    this.storeUrl,
    this.message = 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
  });
}

class AppVersionNotifier extends StateNotifier<AppVersionState> {
  AppVersionNotifier() : super(const AppVersionState());

  Future<void> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.0.1"

      final res = await Dio().get(
        '${AppConstants.baseUrl}/app-version',
        queryParameters: {'platform': 'customer'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = res.data as Map<String, dynamic>;

      final minVersion     = data['min_version']    as String? ?? '1.0.0';
      final latestVersion  = data['latest_version'] as String? ?? '1.0.0';
      final forceUpdate    = data['force_update']   as bool?   ?? false;
      final forceMessage   = data['force_message']  as String? ?? '';
      final androidUrl     = data['android_url']    as String?;
      final iosUrl         = data['ios_url']        as String?;
      final storeUrl       = Platform.isIOS ? iosUrl : androidUrl;

      final needsForce = forceUpdate && _isOlderThan(current, minVersion);
      final needsSoft  = !needsForce && _isOlderThan(current, latestVersion);

      state = AppVersionState(
        isChecked:        true,
        needsForceUpdate: needsForce,
        needsSoftUpdate:  needsSoft,
        storeUrl:         storeUrl,
        message:          forceMessage.isNotEmpty
            ? forceMessage
            : 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
      );
    } catch (_) {
      // Network error → allow user through
      state = const AppVersionState(isChecked: true);
    }
  }

  // Returns true if a < b  (e.g. "1.0.0" < "1.0.1")
  bool _isOlderThan(String a, String b) {
    final av = _parse(a);
    final bv = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (av[i] < bv[i]) return true;
      if (av[i] > bv[i]) return false;
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) { parts.add(0); }
    return parts;
  }
}

final appVersionProvider =
    StateNotifierProvider<AppVersionNotifier, AppVersionState>(
  (ref) => AppVersionNotifier(),
);
