class AddressModel {
  final int id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> j) => AddressModel(
    id:        j['id'] as int,
    label:     j['label'] as String? ?? '',
    address:   j['address'] as String? ?? '',
    latitude:  (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    isDefault: j['is_default'] as bool? ?? false,
  );
}
