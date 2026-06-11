import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

class LocationService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

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
    if (pos == null) return null;
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
}
