import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashship_customer/core/theme/app_theme.dart';
import 'package:flashship_customer/core/widgets/liquid_glass.dart';

void main() {
  testWidgets('Glass sheet supports keyboard, scrolling and semantics', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(context: context,
            isScrollControlled: true, useSafeArea: true, showDragHandle: false,
            backgroundColor: Colors.transparent,
            builder: (context) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: GlassBottomSheet(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const TextField(),
                  for (var i = 0; i < 12; i++) ListTile(title: Text('Mục $i')),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
                ]),
              )),
            )), child: const Text('Mở'))))));
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      expect(find.text('Xong'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
