import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flashship_customer/features/home/screens/home_screen.dart';
import 'package:flashship_customer/features/home/widgets/bottom_nav.dart';
import 'package:flashship_customer/features/home/providers/banner_provider.dart';
import 'package:flashship_customer/features/home/providers/service_type_provider.dart';
import 'package:flashship_customer/features/home/models/banner_model.dart';
import 'package:flashship_customer/features/home/models/service_type_model.dart';
import 'package:flashship_customer/features/auth/providers/auth_provider.dart';
import 'package:flashship_customer/features/auth/models/user_model.dart';
import 'package:flashship_customer/features/order/providers/order_provider.dart';
import 'package:flashship_customer/features/order/models/order_model.dart';
import 'package:flashship_customer/features/profile/providers/active_city_provider.dart';
import 'package:flashship_customer/features/profile/providers/addresses_provider.dart';
import 'package:flashship_customer/features/profile/models/address_model.dart';
import 'package:flashship_customer/features/profile/providers/support_provider.dart';
import 'package:flashship_customer/features/notification/providers/notification_provider.dart';
import 'package:flashship_customer/features/voucher/providers/voucher_provider.dart';
import 'package:flashship_customer/features/voucher/models/voucher_model.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
      : super(const AuthState(
            user: UserModel(
                id: 1, name: 'Người dùng kiểm thử tên dài', phone: ''),
            token: 'test'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _City extends StateNotifier<ActiveCityState>
    implements ActiveCityNotifier {
  _City() : super(const ActiveCityState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Orders extends StateNotifier<OrderListState>
    implements OrderListNotifier {
  _Orders([List<OrderModel> orders = const []])
      : super(OrderListState(orders: orders, isLoading: false));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Addresses extends AddressesNotifier {
  @override
  Future<List<AddressModel>> build() async => [
        const AddressModel(
            id: 1,
            label: 'Nhà',
            address: 'Địa chỉ kiểm thử dài để kiểm tra bố cục'),
        const AddressModel(
            id: 2, label: 'Cơ quan', address: 'Văn phòng kiểm thử'),
      ];
}

class _Vouchers extends VoucherNotifier {
  @override
  Future<List<VoucherModel>> build() async => [
        VoucherModel(
            id: 1,
            code: 'TEST_ONLY',
            type: 'fixed',
            value: 10000,
            discountLabel: 'Ưu đãi kiểm thử có tiêu đề dài',
            description:
                'Mô tả kiểm thử nhiều chữ để phát hiện lỗi tràn bố cục.',
            appOnly: true,
            expiresAt: DateTime.now().add(const Duration(days: 1))),
      ];
}

const _services = [
  ServiceTypeModel(
      key: 'delivery', label: 'Giao hàng', sortOrder: 0, isActive: true),
  ServiceTypeModel(
      key: 'shopping', label: 'Mua hộ', sortOrder: 1, isActive: true),
  ServiceTypeModel(key: 'bike', label: 'Xe ôm', sortOrder: 2, isActive: true),
  ServiceTypeModel(
      key: 'motor', label: 'Lái xe máy hộ', sortOrder: 3, isActive: true),
  ServiceTypeModel(
      key: 'car', label: 'Lái xe ô tô hộ', sortOrder: 4, isActive: true),
  ServiceTypeModel(
      key: 'topup', label: 'Nạp tiền hộ', sortOrder: 5, isActive: true),
];

Future<void> _mount(WidgetTester tester, Size size, double scale,
    {bool failServices = false,
    List<OrderModel> orders = const [],
    List<SupportItem> supportItems = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
            body: const HomeTab(),
            bottomNavigationBar:
                BottomNav(currentIndex: 0, unreadCount: 2, onTap: (_) {}))),
    for (final path in ['/booking/delivery', '/profile/addresses', '/vouchers'])
      GoRoute(
          path: path, builder: (_, __) => Scaffold(body: Text('route:$path'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _Auth()),
        activeCityProvider.overrideWith((ref) => _City()),
        orderListProvider.overrideWith((ref) => _Orders(orders)),
        addressesProvider.overrideWith(_Addresses.new),
        voucherProvider.overrideWith(_Vouchers.new),
        unreadCountProvider.overrideWithValue(2),
        supportProvider.overrideWith((ref) async => supportItems),
        bannerProvider.overrideWith((ref) async => <BannerModel>[]),
        serviceTypeProvider.overrideWith((ref) async {
          if (failServices) throw StateError('test offline');
          return _services;
        }),
      ],
      child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!))));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(393, 852),
    const Size(768, 1024)
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('Home fits ${size.width} at text scale $scale',
          (tester) async {
        await _mount(tester, size, scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Chọn địa chỉ giao đến'), findsOneWidget);
        expect(find.text('Đơn đang thực hiện'), findsNothing);
        await tester.scrollUntilVisible(find.text('TEST_ONLY'), 220,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('TEST_ONLY'), findsOneWidget);
      });
    }
  }

  testWidgets('Service preserves booking route', (tester) async {
    await _mount(tester, const Size(393, 852), 1);
    await tester.ensureVisible(find.text('Giao hàng'));
    await tester.tap(find.text('Giao hàng'));
    await tester.pumpAndSettle();
    expect(find.text('route:/booking/delivery'), findsOneWidget);
  });

  testWidgets('Header remains valid during partial collapse', (tester) async {
    await _mount(tester, const Size(393, 852), 1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -8));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Chọn địa chỉ giao đến'), findsOneWidget);
  });

  testWidgets('Completed order can be reordered from Home', (tester) async {
    await _mount(
      tester,
      const Size(393, 852),
      1,
      orders: const [
        OrderModel(
          id: 7,
          code: 'DONE_7',
          serviceType: 'delivery',
          status: 'completed',
          deliveryAddress: '120 Lê Lợi',
          shippingFee: 20000,
          createdAt: '',
        ),
      ],
    );
    await tester.scrollUntilVisible(
      find.text('Đặt lại'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Đặt lại')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại đơn gần đây'), findsOneWidget);
    expect(find.text('120 Lê Lợi'), findsOneWidget);
    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    expect(find.text('route:/booking/delivery'), findsOneWidget);
  });

  testWidgets('Support channels fit on a narrow screen', (tester) async {
    await _mount(
      tester,
      const Size(320, 700),
      1.6,
      supportItems: const [
        SupportItem(
          id: 1,
          title: 'Hotline',
          subtitle: 'Hỗ trợ đơn hàng',
          type: 'hotline',
          value: '19001234',
        ),
        SupportItem(
          id: 2,
          title: 'Chat Zalo',
          subtitle: 'Nhắn tin với FlashShip',
          type: 'zalo',
          value: 'flashship',
        ),
      ],
    );
    await tester.scrollUntilVisible(
      find.text('Hotline'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bạn cần hỗ trợ?'), findsOneWidget);
    expect(find.text('Chat Zalo'), findsOneWidget);
  });

  testWidgets('Failed service load offers recovery', (tester) async {
    await _mount(tester, const Size(393, 852), 1, failServices: true);
    expect(find.text('Chưa tải được dịch vụ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('Active order uses real status and existing detail route',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: HomeOrderCard(
                  order: OrderModel(
                      id: 1,
                      code: 'TEST_ORDER',
                      serviceType: 'delivery',
                      status: 'assigned',
                      shippingFee: 10000,
                      createdAt: '')))),
      GoRoute(
          path: '/order/TEST_ORDER',
          builder: (_, __) => const Text('order detail')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Tài xế đã nhận'), findsOneWidget);
    expect(find.text('Chưa có thời gian dự kiến'), findsNothing);
    await tester.tap(find.text('Xem chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('order detail'), findsOneWidget);
  });
}
