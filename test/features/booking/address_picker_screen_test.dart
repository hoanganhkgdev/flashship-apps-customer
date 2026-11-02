import 'package:dio/dio.dart';
import 'package:flashship_customer/core/api/api_client.dart';
import 'package:flashship_customer/features/booking/screens/address_picker_screen.dart';
import 'package:flashship_customer/features/booking/screens/map_picker_screen.dart';
import 'package:flashship_customer/features/profile/models/address_model.dart';
import 'package:flashship_customer/features/profile/providers/addresses_provider.dart';
import 'package:flashship_customer/features/profile/providers/cities_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AddressApi implements ApiClient {
  _AddressApi(this.items);

  final List<Map<String, dynamic>> items;

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params}) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'data': path == '/customer/addresses' ? items : []},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavedAddresses extends AddressesNotifier {
  @override
  Future<List<AddressModel>> build() async => const [];
}

class _PickerHost extends StatefulWidget {
  const _PickerHost();

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  MapPickResult? result;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: () async {
                final selected =
                    await Navigator.of(context).push<MapPickResult>(
                  MaterialPageRoute(
                      builder: (_) => const AddressPickerScreen()),
                );
                if (mounted) setState(() => result = selected);
              },
              child: const Text('Mở chọn địa chỉ'),
            ),
            if (result != null)
              Text(
                  '${result!.address}|${result!.lat}|${result!.lng}|${result!.placeName}'),
          ]),
        ),
      );
}

Future<void> _openPicker(
  WidgetTester tester, {
  required List<Map<String, dynamic>> addresses,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_AddressApi(addresses)),
      addressesProvider.overrideWith(_SavedAddresses.new),
      citiesProvider.overrideWith((ref) async => <CityItem>[]),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const _PickerHost(),
    ),
  ));
  await tester.tap(find.text('Mở chọn địa chỉ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Chọn địa chỉ đã lưu trả đủ địa chỉ, tọa độ và tên địa điểm',
      (tester) async {
    await _openPicker(tester, addresses: [
      {
        'id': 1,
        'label': 'Điểm nhận test',
        'place_name': 'Văn phòng test',
        'address': '120 Lê Lợi',
        'latitude': 10.12,
        'longitude': 105.34,
      },
    ]);
    await tester.tap(find.text('Đã lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điểm nhận test').first);
    await tester.pumpAndSettle();
    expect(find.text('120 Lê Lợi|10.12|105.34|Văn phòng test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Địa chỉ đã lưu thiếu tọa độ không trả kết quả sai',
      (tester) async {
    await _openPicker(tester, addresses: [
      {'id': 2, 'label': 'Điểm chưa có tọa độ', 'address': '12 Nguyễn Huệ'},
    ]);
    await tester.tap(find.text('Đã lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điểm chưa có tọa độ').first);
    await tester.pump();
    expect(find.byType(AddressPickerScreen), findsOneWidget);
    expect(find.textContaining('chưa có tọa độ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chọn địa chỉ không tràn khi chữ lớn và bàn phím mở',
      (tester) async {
    await _openPicker(tester,
        addresses: [], size: const Size(320, 700), textScale: 1.6);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(AddressPickerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
