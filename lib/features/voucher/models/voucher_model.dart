class VoucherModel {
  final int id;
  final String code;
  final String type;
  final int value;
  final String? description;
  final String discountLabel;
  final int? minOrderValue;
  final int? maxDiscount;
  final List<String>? serviceTypes;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final int usedCountByUser;
  final int? perUserLimit;
  final String status;
  final bool appOnly;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.discountLabel,
    this.description,
    this.minOrderValue,
    this.maxDiscount,
    this.serviceTypes,
    this.expiresAt,
    this.usedAt,
    this.usedCountByUser = 0,
    this.perUserLimit,
    this.status = 'available',
    this.appOnly = false,
  });

  // `usedAt` is usage history, not proof that the voucher is exhausted.
  // A reusable voucher can have a latest usage while the API still marks it
  // available because the customer has remaining uses.
  bool get isUsed => status == 'used';
  bool get isExpired =>
      status == 'expired' ||
      (status != 'used' &&
          expiresAt != null &&
          !expiresAt!.isAfter(DateTime.now()));
  bool get isAvailable => status == 'available' && !isExpired;
  bool get hasBeenUsed => usedCountByUser > 0 || usedAt != null;

  String get usageLabel => perUserLimit == null
      ? 'Đã dùng $usedCountByUser lần'
      : 'Đã dùng $usedCountByUser/$perUserLimit lần';

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
  }

  static DateTime? _date(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  factory VoucherModel.fromJson(Map<String, dynamic> j) => VoucherModel(
        id: _int(j['id']),
        code: j['code']?.toString() ?? '',
        type: j['type']?.toString() ?? 'fixed',
        value: _int(j['value']),
        discountLabel: j['discount_label']?.toString() ?? '',
        description: j['description']?.toString(),
        minOrderValue:
            j['min_order_value'] == null ? null : _int(j['min_order_value']),
        maxDiscount: j['max_discount'] == null ? null : _int(j['max_discount']),
        serviceTypes: (j['service_types'] as List?)
            ?.map((value) => value.toString())
            .toList(),
        expiresAt: _date(j['expires_at']),
        usedAt: _date(j['used_at'] ??
            (_bool(j['is_used']) || j['status'] == 'used'
                ? DateTime.now().toIso8601String()
                : null)),
        usedCountByUser: _int(j['used_count_by_user']),
        perUserLimit:
            j['per_user_limit'] == null ? null : _int(j['per_user_limit']),
        status: j['status']?.toString() ?? 'available',
        appOnly: _bool(j['app_only']),
      );
}
