import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever }

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

    return Geolocator.getCurrentPosition(locationSettings: settings);
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
          'latlng':   '$lat,$lng',
          'key':      AppConstants.googleMapsApiKey,
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

  /// Shows a recovery dialog for [LocationException] — opens location
  /// settings when GPS is off, opens app settings when permission was
  /// permanently denied. Call from a catch block around [getCurrentPosition].
  static Future<void> showFailureDialog(BuildContext context, LocationException e) async {
    final (title, message, action) = switch (e.reason) {
      LocationFailure.serviceDisabled => (
        'Định vị đang tắt',
        'Vui lòng bật định vị (GPS) để sử dụng tính năng này.',
        Geolocator.openLocationSettings,
      ),
      LocationFailure.permissionDenied => (
        'Cần quyền truy cập vị trí',
        'FlashShip cần quyền vị trí để xác định điểm đón chính xác.',
        Geolocator.openAppSettings,
      ),
      LocationFailure.permissionDeniedForever => (
        'Quyền vị trí đã bị từ chối',
        'Vui lòng vào Cài đặt > FlashShip > Vị trí để bật quyền truy cập.',
        Geolocator.openAppSettings,
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
            onPressed: () { Navigator.pop(ctx); action(); },
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }
}
