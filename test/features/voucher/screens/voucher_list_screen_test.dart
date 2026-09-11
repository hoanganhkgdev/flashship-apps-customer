import 'package:flutter/material.dart';
import 'package:flashship_customer/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashship_customer/features/voucher/models/voucher_model.dart';
import 'package:flashship_customer/features/voucher/providers/voucher_provider.dart';
import 'package:flashship_customer/features/voucher/screens/voucher_list_screen.dart';

class _Vouchers extends VoucherNotifier {
  @override
  Future<List<VoucherModel>> build() async => [
        for (var i = 0; i < 12; i++)
          VoucherModel(
              id: i,
              code: 'VOUCHER$i',
              type: 'fixed',
              value: 10000,
              discountLabel: 'Giảm 10.000đ',
              usedCountByUser: i.isEven ? 1 : 0,
              status: i > 8 ? 'expired' : 'available'),
      ];
}

void main() {
  testWidgets('Voucher semantics survive scrolling and changing tabs',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [voucherProvider.overrideWith(_Vouchers.new)],
      child: MaterialApp(theme: AppTheme.light, home: const VoucherListScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['Đã dùng', 'Hết hạn', 'Khả dụng']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
}
