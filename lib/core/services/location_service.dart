import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
}

class LocationException implements Exception {
  final LocationFailure reason;
  const LocationException(this.reason);
}

class LocationService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Throws [LocationException] when location is unavailable so callers can
  /// show the right recovery action (open location settings vs open app settings).
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(LocationFailure.permissionDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            forceLocationManager: false,
            timeLimit: const Duration(seconds: 10),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.best,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            timeLimit: const Duration(seconds: 10),
          );

    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } on TimeoutException {
      // geolocator_apple forwards the native timeLimit as a Dart
      // TimeoutException. Convert it to the service's typed failure so every
      // caller can recover consistently instead of crashing the isolate.
      throw const LocationException(LocationFailure.timedOut);
    }
  }

  static Future<String?> getCurrentAddress() async {
    final pos = await getCurrentPosition();
    return addressFromCoords(pos.latitude, pos.longitude);
  }

  static Future<String?> addressFromCoords(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': AppConstants.googleMapsApiKey,
          'language': 'vi',
        },
      );
      final results = res.data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final raw = results.first['formatted_address'] as String?;
      return raw;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the current GPS position and resolves it to a human-readable
  /// address, showing the recovery dialog on failure. Returns null when
  /// location couldn't be obtained or the widget was unmounted mid-flight.
  static Future<(Position, String?)?> resolveCurrentLocation(
    BuildContext context,
  ) async {
    final Position pos;
    try {
      pos = await getCurrentPosition();
    } on LocationException catch (e) {
      if (!context.mounted) return null;
      if (e.reason == LocationFailure.timedOut) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa xác định được vị trí. Bạn có thể chọn địa chỉ thủ công.',
            ),
          ),
        );
      } else {
        await showFailureDialog(context, e);
      }
      return null;
    } catch (_) {
      // Native location implementations can also surface platform-specific
      // errors. Location prefill is optional, so leave the field empty and
      // let the user choose an address instead of failing the booking screen.
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lấy vị trí hiện tại. Vui lòng chọn địa chỉ thủ công.',
            ),
          ),
        );
      }
      return null;
    }
    if (!context.mounted) return null;
    final addr = await addressFromCoords(pos.latitude, pos.longitude);
    if (!context.mounted) return null;
    return (pos, addr);
  }

  /// Shows a recovery dialog for [LocationException] — opens location
  /// settings when GPS is off, opens app settings when permission was
  /// permanently denied. Call from a catch block around [getCurrentPosition].
  static Future<void> showFailureDialog(
      BuildContext context, LocationException e) async {
    final (title, message, action) = switch (e.reason) {
      LocationFailure.serviceDisabled => (
          'Định vị đang tắt',
          'Vui lòng bật định vị (GPS) để sử dụng tính năng này.',
          Geolocator.openLocationSettings,
        ),
      LocationFailure.permissionDenied => (
          'Cần quyền truy cập vị trí',
          'Flash Ship cần quyền vị trí để xác định điểm đón chính xác.',
          Geolocator.openAppSettings,
        ),
      LocationFailure.permissionDeniedForever => (
          'Quyền vị trí đã bị từ chối',
          'Vui lòng vào Cài đặt > Flash Ship > Vị trí để bật quyền truy cập.',
          Geolocator.openAppSettings,
        ),
      // Timeout is handled non-modally in [resolveCurrentLocation]. Keep this
      // branch exhaustive for direct callers of this dialog helper.
      LocationFailure.timedOut => (
          'Chưa xác định được vị trí',
          'Tín hiệu GPS phản hồi quá chậm. Vui lòng thử lại hoặc chọn địa chỉ thủ công.',
          Geolocator.openLocationSettings,
        ),
    };

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              action();
            },
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }
}
