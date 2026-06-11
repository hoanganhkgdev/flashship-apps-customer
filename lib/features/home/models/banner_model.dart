import '../../../core/constants/app_constants.dart';

class BannerModel {
  final int id;
  final String? title;
  final String? imageUrl;
  final String? linkUrl;

  const BannerModel({
    required this.id,
    this.title,
    this.imageUrl,
    this.linkUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> j) {
    final raw = j['image_path'] as String?;
    String? imageUrl;
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http')) {
        imageUrl = raw;
      } else {
        final base = AppConstants.baseUrl.replaceAll('/api', '');
        imageUrl = '$base/storage/$raw';
      }
    }
    return BannerModel(
      id:       j['id'] as int,
      title:    j['title'] as String?,
      imageUrl: imageUrl,
      linkUrl:  j['link_url'] as String?,
    );
  }
}
