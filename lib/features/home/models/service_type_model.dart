class ServiceTypeModel {
  final String key;
  final String label;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  const ServiceTypeModel({
    required this.key,
    required this.label,
    this.iconUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory ServiceTypeModel.fromJson(Map<String, dynamic> json) {
    return ServiceTypeModel(
      key: json['key'] as String,
      label: json['label'] as String,
      iconUrl: json['icon_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}
