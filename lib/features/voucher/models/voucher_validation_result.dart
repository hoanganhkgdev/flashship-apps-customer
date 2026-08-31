class VoucherValidationResult {
  const VoucherValidationResult({
    required this.code,
    required this.discount,
    this.discountLabel,
    this.description,
  });

  final String code;
  final int discount;
  final String? discountLabel;
  final String? description;

  factory VoucherValidationResult.fromResponse(
    dynamic response, {
    required String code,
  }) {
    final root = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    final nested = root['data'];
    final data = nested is Map ? Map<String, dynamic>.from(nested) : root;

    return VoucherValidationResult(
      code: code.trim().toUpperCase(),
      discount: _nonNegativeInt(data['discount']),
      discountLabel: _optionalString(data['discount_label']),
      description: _optionalString(data['description']),
    );
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
