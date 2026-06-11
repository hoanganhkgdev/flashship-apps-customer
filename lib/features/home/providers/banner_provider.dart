import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/banner_model.dart';

final bannerProvider = FutureProvider<List<BannerModel>>((ref) async {
  final res  = await ref.read(apiClientProvider).get('/banners');
  final list = (res.data['data'] ?? res.data) as List? ?? [];
  return list.cast<Map<String, dynamic>>().map(BannerModel.fromJson).toList();
});
