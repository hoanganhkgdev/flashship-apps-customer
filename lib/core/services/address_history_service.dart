import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddressHistoryItem {
  final String address;
  final double lat;
  final double lng;
  final String? placeName;

  const AddressHistoryItem({
    required this.address,
    required this.lat,
    required this.lng,
    this.placeName,
  });

  Map<String, dynamic> toJson() => {
    'address': address, 'lat': lat, 'lng': lng,
    if (placeName != null) 'place_name': placeName,
  };

  factory AddressHistoryItem.fromJson(Map<String, dynamic> json) => AddressHistoryItem(
    address: json['address'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    placeName: json['place_name'] as String?,
  );
}

class AddressHistoryService {
  static const _key = 'address_history_v1';
  static const _maxItems = 10;

  static Future<List<AddressHistoryItem>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => AddressHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(AddressHistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await load();
      // Remove duplicate by address string
      list.removeWhere((e) => e.address == item.address);
      // Most recent first
      list.insert(0, item);
      final trimmed = list.take(_maxItems).toList();
      await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> remove(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await load();
      list.removeWhere((e) => e.address == address);
      await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
