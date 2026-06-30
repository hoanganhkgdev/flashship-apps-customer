import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class AddressResult {
  final String display;
  final String mainText;
  final String secondaryText;
  final String placeId;
  final double? lat;
  final double? lng;

  const AddressResult({
    required this.display,
    required this.mainText,
    required this.secondaryText,
    required this.placeId,
    this.lat,
    this.lng,
  });
}

class AddressSearchService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Throws on network/API failure so callers can distinguish "lỗi kết nối"
  /// from "không có kết quả". Only ZERO_RESULTS/empty predictions return [].
  static Future<List<AddressResult>> search(
    String query, {
    double? lat,
    double? lng,
    double? circleRadius,
    String? filterKeyword,
  }) async {
    if (query.trim().length < 3) return [];

    final params = <String, dynamic>{
      'input':      query,
      'key':        AppConstants.googleMapsApiKey,
      'language':   'vi',
      'components': 'country:vn',
    };
    if (lat != null && lng != null) {
      params['location'] = '$lat,$lng';
      params['radius']   = ((circleRadius ?? 25.0) * 1000).toInt();
    }

    final res = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: params,
    );

    final status = res.data['status'] as String?;
    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') {
      throw Exception('Google Places autocomplete failed: $status');
    }

    final predictions = res.data['predictions'] as List? ?? [];
    final all = predictions.map((e) {
      final sf = e['structured_formatting'] as Map? ?? {};
      return AddressResult(
        display:       e['description'] as String? ?? '',
        mainText:      sf['main_text'] as String? ?? e['description'] as String? ?? '',
        secondaryText: sf['secondary_text'] as String? ?? '',
        placeId:       e['place_id'] as String? ?? '',
      );
    }).toList();

    if (filterKeyword != null && filterKeyword.isNotEmpty) {
      final keywords = filterKeyword.toLowerCase().split('|');
      bool matches(AddressResult r) {
        final text = '${r.display} ${r.secondaryText}'.toLowerCase();
        return keywords.any((kw) => text.contains(kw.trim()));
      }
      final filtered = all.where(matches).toList();
      if (filtered.isNotEmpty) return filtered;
    }

    return all.take(5).toList();
  }

  static Future<AddressResult?> getDetail(AddressResult result) async {
    if (result.lat != null && result.lng != null) return result;

    // Try Place Details first
    if (result.placeId.isNotEmpty) {
      try {
        final res = await _dio.get(
          'https://maps.googleapis.com/maps/api/place/details/json',
          queryParameters: {
            'place_id': result.placeId,
            'key':      AppConstants.googleMapsApiKey,
            'fields':   'formatted_address,geometry',
            'language': 'vi',
          },
        );
        if (res.data['status'] == 'OK') {
          final r   = res.data['result'] as Map?;
          final loc = r?['geometry']?['location'] as Map?;
          final lat = (loc?['lat'] as num?)?.toDouble();
          final lng = (loc?['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            return AddressResult(
              display:       r?['formatted_address'] as String? ?? result.display,
              mainText:      result.mainText,
              secondaryText: result.secondaryText,
              placeId:       result.placeId,
              lat:           lat,
              lng:           lng,
            );
          }
        }
      } catch (_) {}
    }

    // Fallback: Geocoding API by address text
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address':    result.display,
          'key':        AppConstants.googleMapsApiKey,
          'language':   'vi',
          'components': 'country:VN',
        },
      );
      if (res.data['status'] == 'OK') {
        final results = res.data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final loc = results.first['geometry']?['location'] as Map?;
          final lat = (loc?['lat'] as num?)?.toDouble();
          final lng = (loc?['lng'] as num?)?.toDouble();
          final addr = results.first['formatted_address'] as String? ?? result.display;
          if (lat != null && lng != null) {
            return AddressResult(
              display:       addr,
              mainText:      result.mainText,
              secondaryText: result.secondaryText,
              placeId:       result.placeId,
              lat:           lat,
              lng:           lng,
            );
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
