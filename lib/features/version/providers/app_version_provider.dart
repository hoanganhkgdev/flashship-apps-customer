import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_constants.dart';

class AppVersionState {
  final bool isChecked;
  final bool needsForceUpdate;
  final String? storeUrl;
  final String message;

  const AppVersionState({
    this.isChecked = false,
    this.needsForceUpdate = false,
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

      debugPrint('[VersionCheck] current=$current, API response=$data');

      final rawForce = data['force_update'];
      final forceUpdate = rawForce == true ||
          rawForce == 1 ||
          rawForce == '1' ||
          rawForce == 'true';
      final forceMessage = data['force_message'] as String? ?? '';
      final androidUrl = data['android_url'] as String?;
      final iosUrl = data['ios_url'] as String?;
      final configuredUrl = Platform.isIOS ? iosUrl : androidUrl;
      final storeUrl = configuredUrl?.trim().isNotEmpty == true
          ? configuredUrl
          : Platform.isIOS
              ? 'https://apps.apple.com/vn/app/flash-ship-%C4%91%E1%BA%B7t-%C4%91%C6%A1n/id6768362686'
              : 'https://play.google.com/store/apps/details?id=vn.flashship.customer';

      final platformMinKey =
          Platform.isIOS ? 'ios_min_version' : 'android_min_version';
      final minVersion =
          data[platformMinKey]?.toString().trim().isNotEmpty == true
              ? data[platformMinKey].toString()
              : data['min_version']?.toString() ?? '1.0.0';

      final needsForce = forceUpdate && _isOlderThan(current, minVersion);
      debugPrint(
          '[VersionCheck] forceUpdate=$forceUpdate, minVersion=$minVersion, needsForce=$needsForce');

      state = AppVersionState(
        isChecked: true,
        needsForceUpdate: needsForce,
        storeUrl: storeUrl,
        message: forceMessage.isNotEmpty
            ? forceMessage
            : 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
      );
    } catch (_) {
      // Network error → allow user through
      state = const AppVersionState(isChecked: true);
    }
  }

  // Returns true if a < b; hỗ trợ cả "1.2", "1.2.3+45", "1.2.3-beta".
  bool _isOlderThan(String a, String b) {
    final av = _parse(a);
    final bv = _parse(b);
    final length = av.length > bv.length ? av.length : bv.length;
    for (var i = 0; i < length; i++) {
      final aPart = i < av.length ? av[i] : 0;
      final bPart = i < bv.length ? bv[i] : 0;
      if (aPart < bPart) return true;
      if (aPart > bPart) return false;
    }
    return false;
  }

  List<int> _parse(String v) {
    final semanticVersion = v.trim().split('+').first.split('-').first;
    return semanticVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}

final appVersionProvider =
    StateNotifierProvider<AppVersionNotifier, AppVersionState>(
  (ref) => AppVersionNotifier(),
);
