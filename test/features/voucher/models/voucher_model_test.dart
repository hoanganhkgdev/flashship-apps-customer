import 'package:flashship_customer/features/voucher/models/voucher_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoucherModel availability', () {
    test('stays available after a use when API says uses remain', () {
      final voucher = VoucherModel.fromJson({
        'id': 1,
        'code': 'MULTI10',
        'type': 'fixed',
        'value': 10000,
        'discount_label': '-10.000đ',
        'used_at': '2026-08-30T10:00:00+07:00',
        'used_count_by_user': 2,
        'status': 'available',
      });

      expect(voucher.usedAt, isNotNull);
      expect(voucher.isAvailable, isTrue);
      expect(voucher.isUsed, isFalse);
      expect(voucher.hasBeenUsed, isTrue);
      expect(voucher.usageLabel, 'Đã dùng 2 lần');
    });

    test('is used only after API says the per-user limit was reached', () {
      final voucher = VoucherModel.fromJson({
        'id': 1,
        'code': 'ONCE',
        'type': 'fixed',
        'value': 10000,
        'discount_label': '-10.000đ',
        'used_at': '2026-08-30T10:00:00+07:00',
        'used_count_by_user': 3,
        'per_user_limit': 3,
        'status': 'used',
      });

      expect(voucher.isAvailable, isFalse);
      expect(voucher.isUsed, isTrue);
      expect(voucher.usageLabel, 'Đã dùng 3/3 lần');
    });
  });
}
