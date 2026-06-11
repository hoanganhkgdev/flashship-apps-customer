import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/service_type_model.dart';

final serviceTypeProvider = FutureProvider<List<ServiceTypeModel>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/service-types');
  final list = (res.data['data'] ?? res.data) as List? ?? [];
  return list.cast<Map<String, dynamic>>().map(ServiceTypeModel.fromJson).toList();
});
