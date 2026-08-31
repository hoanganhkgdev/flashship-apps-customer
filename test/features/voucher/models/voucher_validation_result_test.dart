import 'package:flashship_customer/features/voucher/models/voucher_validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoucherValidationResult.fromResponse', () {
    test('normalizes code and parses a direct response', () {
      final result = VoucherValidationResult.fromResponse(
        {
          'discount': '25000',
          'discount_label': 'Giảm 25K',
          'description': ' Ưu đãi giao hàng ',
        },
        code: ' freeship25 ',
      );

      expect(result.code, 'FREESHIP25');
      expect(result.discount, 25000);
      expect(result.discountLabel, 'Giảm 25K');
      expect(result.description, 'Ưu đãi giao hàng');
    });

    test('supports a response wrapped in data', () {
      final result = VoucherValidationResult.fromResponse(
        {
          'data': {'discount': 12000.9}
        },
        code: 'sale',
      );

      expect(result.discount, 12000);
    });

    test('does not allow malformed or negative discounts', () {
      expect(
        VoucherValidationResult.fromResponse(
          {'discount': -10},
          code: 'sale',
        ).discount,
        0,
      );
      expect(
        VoucherValidationResult.fromResponse('invalid', code: 'sale').discount,
        0,
      );
    });
  });
}
