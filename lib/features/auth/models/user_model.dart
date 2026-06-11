class UserModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? profilePhotoPath;
  final String? avatarUrl;
  final String userType;
  final int cityId;
  final String? cityName;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.profilePhotoPath,
    this.avatarUrl,
    this.userType = 'customer',
    this.cityId = 1,
    this.cityName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String?,
    profilePhotoPath: json['profile_photo_path'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    userType: json['user_type'] as String? ?? 'customer',
    cityId: json['city_id'] as int? ?? 1,
    cityName: json['city_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'profile_photo_path': profilePhotoPath,
    'avatar_url': avatarUrl,
    'user_type': userType, 'city_id': cityId, 'city_name': cityName,
  };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return parts.last.substring(0, 1).toUpperCase();
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
  }
}
