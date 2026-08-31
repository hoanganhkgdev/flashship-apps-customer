import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notification/models/notification_item.dart';
import '../../../features/notification/providers/notification_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/order/providers/order_provider.dart';
import '../../../features/profile/models/address_model.dart';
import '../../../features/profile/providers/addresses_provider.dart';
import '../../../core/services/address_history_service.dart';
import '../../../features/profile/providers/active_city_provider.dart';
import '../../booking/screens/address_picker_screen.dart';
import '../../booking/screens/map_picker_screen.dart';

import '../models/banner_model.dart';
import '../models/service_type_model.dart';
import '../providers/banner_provider.dart';
import '../providers/service_type_provider.dart';
import '../../voucher/providers/voucher_provider.dart';
import '../../../features/profile/providers/support_provider.dart';
import '../../../features/notification/screens/notification_inbox_screen.dart';
import '../widgets/bottom_nav.dart';

part '../widgets/home_tab.dart';
part '../widgets/home_header_section.dart';
part '../widgets/home_orders_section.dart';
part '../widgets/home_banners_section.dart';
part '../widgets/home_voucher_section.dart';
part '../widgets/home_address_section.dart';
part '../widgets/history_tab.dart';
part '../widgets/profile_tab.dart';

final _homeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.onOrderTap = (code) {
      if (mounted) context.push('/order/$code');
    };
    NotificationService.onIncomingNotification = ({
      required String title,
      required String body,
      String? orderCode,
    }) {
      final item = NotificationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        orderCode: orderCode,
        createdAt: DateTime.now(),
      );
      ref.read(notificationProvider.notifier).add(item);
      // Fetch server để đồng bộ ngay
      ref.read(notificationProvider.notifier).fetchFromServer();
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderListProvider.notifier).fetch();
      NotificationService.init();
      ref.read(activeCityProvider.notifier).detectFromGps();
      // Subscribe RTDB để nhận notification realtime
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        ref.read(notificationProvider.notifier).subscribeRTDB(userId);
      }
    });
  }

  @override
  void dispose() {
    NotificationService.onOrderTap = null;
    NotificationService.onIncomingNotification = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_homeTabProvider);
    final isAuth = ref.watch(authProvider).isAuthenticated;
    final unreadCount = ref.watch(unreadCountProvider);

    if (!isAuth) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const _HomeTab(),
        bottomNavigationBar: _GuestBottomBar(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: tab,
        children: [
          const _HomeTab(),
          const _HistoryTab(),
          const NotificationInboxScreen(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: tab,
        unreadCount: unreadCount,
        onTap: (i) => ref.read(_homeTabProvider.notifier).state = i,
      ),
    );
  }
}

class _GuestBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.push('/register'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Đăng ký',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 0,
            ),
            child: const Text('Đăng nhập',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
