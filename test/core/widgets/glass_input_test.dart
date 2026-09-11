import 'package:flashship_customer/core/theme/app_theme.dart';
import 'package:flashship_customer/core/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glass inputs retain focus, validation and multiline layout',
      (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(inputDecorationTheme: AppTheme.glassInputDecoration),
      home: Scaffold(
        body: LiquidBackdrop(
          child: Center(
            child: SizedBox(
              width: 320,
              child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Vui lòng nhập số điện thoại người nhận để tiếp tục'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    enabled: false,
                    decoration: InputDecoration(labelText: 'Không khả dụng'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập số điện thoại người nhận để tiếp tục'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField), '0901234567');
    expect(form.currentState!.validate(), isTrue);
    await tester.pumpAndSettle();
    final notes = find.byType(TextField).at(1);
    await tester.enterText(notes, 'Giao tại sảnh\nGọi trước khi đến');
    await tester.pumpAndSettle();
    expect(find.text('Giao tại sảnh\nGọi trước khi đến'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
