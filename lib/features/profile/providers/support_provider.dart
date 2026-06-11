import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class SupportItem {
  final int id;
  final String title;
  final String? subtitle;
  final String type;
  final String value;
  final String? color;

  const SupportItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.value,
    this.color,
  });

  factory SupportItem.fromJson(Map<String, dynamic> j) => SupportItem(
    id:       j['id'] as int,
    title:    j['title'] as String,
    subtitle: j['subtitle'] as String?,
    type:     j['type'] as String,
    value:    j['value'] as String,
    color:    j['color'] as String?,
  );
}

final supportProvider = FutureProvider<List<SupportItem>>((ref) async {
  try {
    final res = await ref.read(apiClientProvider).get('/customer/support');
    final list = (res.data['data'] as List? ?? []);
    return list.map((e) => SupportItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});
