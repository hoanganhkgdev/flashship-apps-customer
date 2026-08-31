import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class CityItem {
  final int id;
  final String name;
  final double? lat;
  final double? lng;
  const CityItem({required this.id, required this.name, this.lat, this.lng});

  // Backend serialize cột decimal ra JSON dạng chuỗi (vd "10.0125000"),
  // không phải số — ép kiểu num trực tiếp sẽ crash, phải parse qua String.
  static double? _parseCoord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory CityItem.fromJson(Map<String, dynamic> j) => CityItem(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        lat: _parseCoord(j['lat']),
        lng: _parseCoord(j['lng']),
      );
}

final citiesProvider = FutureProvider<List<CityItem>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/cities');
  final list = (res.data['data'] ?? res.data) as List;
  return list.cast<Map<String, dynamic>>().map(CityItem.fromJson).toList();
});
