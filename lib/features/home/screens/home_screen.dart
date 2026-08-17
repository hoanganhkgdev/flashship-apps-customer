import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final tab         = ref.watch(_homeTabProvider);
    final isAuth      = ref.watch(authProvider).isAuthenticated;
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
          const _NotificationsTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: tab,
        unreadCount: unreadCount,
        onTap: (i) => ref.read(_homeTabProvider.notifier).state = i,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav (driver-style)
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const _NavItem(this.on, this.off, this.label);
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTap,
  });

  static const _tabs = [
    _NavItem(Icons.home_rounded,               Icons.home_outlined,              'Trang chủ'),
    _NavItem(Icons.history_rounded,            Icons.history_outlined,           'Hoạt động'),
    _NavItem(Icons.notifications_rounded,      Icons.notifications_outlined,     'Thông báo'),
    _NavItem(Icons.person_rounded,             Icons.person_outline_rounded,     'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottom + 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab      = _tabs[i];
          final selected = i == selectedIndex;
          final showBadge = i == 2 && unreadCount > 0;
          final color = selected ? AppColors.primary : const Color(0xFF9E9E9E);

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: showBadge
                      ? Badge(
                          label: Text('$unreadCount',
                              style: const TextStyle(fontSize: 10)),
                          child: Icon(selected ? tab.on : tab.off,
                              size: 22, color: color),
                        )
                      : Icon(selected ? tab.on : tab.off,
                          size: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(tab.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: color)),
              ]),
            ),
          );
        }),
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.w700)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  void _openBooking(BuildContext ctx, WidgetRef ref, String type,
      {OrderModel? reorder}) {
    if (!ref.read(authProvider).isAuthenticated) {
      ctx.push('/login');
      return;
    }
    switch (type) {
      case 'delivery': ctx.push('/booking/delivery', extra: reorder); break;
      case 'shopping': ctx.push('/booking/shopping', extra: reorder); break;
      case 'topup':    ctx.push('/booking/topup');    break;
      default:         ctx.push('/booking/$type', extra: reorder);    break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authProvider).user;
    final cityState   = ref.watch(activeCityProvider);

    // Sync service labels từ backend vào Fmt cache
    final services = ref.watch(serviceTypeProvider).valueOrNull ?? [];
    if (services.isNotEmpty) {
      Fmt.updateServiceLabels({for (final s in services) s.key: s.label});
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await ref.read(orderListProvider.notifier).fetch();
        ref.invalidate(bannerProvider);
        ref.invalidate(addressesProvider);
        ref.read(activeCityProvider.notifier).detectFromGps();
      },
      child: ColoredBox(
        color: AppColors.background,
        child: CustomScrollView(
          slivers: [
            // ── Header (BShip style) ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                name: user?.name ?? 'Khách',
                initials: user?.initials ?? 'K',
                currentAddress: cityState.currentAddress.isNotEmpty
                    ? cityState.currentAddress
                    : cityState.cityName,
                currentPlaceName: cityState.currentPlaceName,
                isDetecting: cityState.isDetecting,
              ),
            ),

            // ── Active order banner ───────────────────────────────────────
            SliverToBoxAdapter(child: _ActiveOrderBanner()),

            // ── Services ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ServiceIconGrid(
                onTap: (type) => _openBooking(context, ref, type),
              ),
            ),

            // ── Banners carousel (full-width) ─────────────────────────────
            const SliverToBoxAdapter(child: _BannersSection()),

            // ── Ưu đãi dành cho bạn ──────────────────────────────────────
            const SliverToBoxAdapter(child: _VoucherSection()),

            // ── Đặt lại nhanh ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _QuickReorderSection(
                onReorder: (order) => _openBooking(context, ref, order.serviceType,
                    reorder: order),
              ),
            ),


            // ── Hỗ trợ ──────────────────────────────────────────────────
            const SliverToBoxAdapter(child: _SupportSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Header (BShip style) ─────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String name;
  final String initials;
  final String currentAddress;
  final String? currentPlaceName;
  final bool isDetecting;
  const _Header({
    required this.name,
    required this.initials,
    required this.currentAddress,
    this.currentPlaceName,
    required this.isDetecting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Top row: avatar/greeting + notification bell ──────
                  Row(children: [
                    // Greeting + address
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .push<MapPickResult>(
                            MaterialPageRoute(
                                builder: (_) => const AddressPickerScreen()),
                          );
                          if (result != null && context.mounted) {
                            ref
                                .read(activeCityProvider.notifier)
                                .overrideAddress(result.address,
                                    placeName: result.placeName);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 3),
                              const Text('Giao đến',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 13, color: Colors.white70),
                            ]),
                            const SizedBox(height: 3),
                            if (isDetecting)
                              const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white))
                            else if (currentPlaceName != null && currentPlaceName!.isNotEmpty) ...[
                              Text(currentPlaceName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: Colors.white, letterSpacing: -0.2)),
                              const SizedBox(height: 1),
                              Text(currentAddress.isNotEmpty
                                      ? currentAddress
                                      : 'Đang xác định vị trí...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70)),
                            ] else
                              Text(currentAddress.isNotEmpty
                                      ? currentAddress
                                      : 'Đang xác định vị trí...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: Colors.white, letterSpacing: -0.2)),
                          ],
                        ),
                      ),
                    ),

                    // Notification shortcut
                    GestureDetector(
                      onTap: () =>
                          ref.read(_homeTabProvider.notifier).state = 2,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 14),
                  const _SearchBar(),
                ],
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ── Recent address row ────────────────────────────────────────────────────────

class _RecentAddressRow extends ConsumerStatefulWidget {
  const _RecentAddressRow();

  @override
  ConsumerState<_RecentAddressRow> createState() => _RecentAddressRowState();
}

class _RecentAddressRowState extends ConsumerState<_RecentAddressRow> {
  List<AddressHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AddressHistoryService.load();
    if (!mounted) return;
    setState(() => _items = items.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = _items[i];
          return GestureDetector(
            onTap: () {
              ref.read(activeCityProvider.notifier).overrideAddress(item.address);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    item.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Search bar với typewriter animation ──────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  static const _fullText = 'Flash Ship có thể đưa bạn đến đâu?';
  static const _typingSpeed = Duration(milliseconds: 60);
  static const _pauseDuration = Duration(milliseconds: 1800);
  static const _erasingSpeed = Duration(milliseconds: 35);

  String _displayed = '';
  bool _typing = true;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  Future<void> _startTyping() async {
    await Future.delayed(const Duration(milliseconds: 600));
    while (mounted) {
      // Type forward
      for (var i = 0; i <= _fullText.length; i++) {
        if (!mounted) return;
        setState(() => _displayed = _fullText.substring(0, i));
        await Future.delayed(_typingSpeed);
      }
      _typing = false;
      await Future.delayed(_pauseDuration);

      // Erase backward
      for (var i = _fullText.length; i >= 0; i--) {
        if (!mounted) return;
        setState(() => _displayed = _fullText.substring(0, i));
        await Future.delayed(_erasingSpeed);
      }
      _typing = true;
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Icons.travel_explore_rounded, color: AppColors.textPrimary.withValues(alpha: 0.85), size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Text(
              _displayed,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.75)),
            ),
            // cursor nhấp nháy
            AnimatedOpacity(
              opacity: _typing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: 2, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Address chip ─────────────────────────────────────────────────────────────

// ── Service icon grid ─────────────────────────────────────────────────────────

class _ServiceIconGrid extends ConsumerWidget {
  final void Function(String type) onTap;
  const _ServiceIconGrid({required this.onTap});

  static Color _serviceColor(String key) => switch (key) {
    'delivery' => const Color(0xFFE8720C),
    'shopping' => const Color(0xFF3B82F6),
    'topup'    => const Color(0xFF10B981),
    'bike'     => const Color(0xFF8B5CF6),
    'motor'    => const Color(0xFFF59E0B),
    'car'      => const Color(0xFF06B6D4),
    _          => const Color(0xFFE8720C),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceTypeProvider).valueOrNull ?? [];
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.apps_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text('Dịch vụ',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            childAspectRatio: 1.0,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: services.map((svc) => _ServiceIconItem(
              svc: svc,
              color: _serviceColor(svc.key),
              onTap: () => onTap(svc.key),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ServiceIconItem extends StatelessWidget {
  final ServiceTypeModel svc;
  final Color color;
  final VoidCallback onTap;
  const _ServiceIconItem({required this.svc, required this.color, required this.onTap});

  static IconData _icon(String key) => switch (key) {
    'delivery' => Icons.delivery_dining_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'topup'    => Icons.account_balance_wallet_rounded,
    'bike'     => Icons.electric_bike_rounded,
    'motor'    => Icons.motorcycle_rounded,
    'car'      => Icons.directions_car_rounded,
    _          => Icons.miscellaneous_services_rounded,
  };

  static String _sub(String key) => switch (key) {
    'delivery' => 'Giao nhanh · Giá rẻ',
    'shopping' => 'Mua hộ tận nơi',
    'topup'    => 'Nạp thẻ · Ví điện tử',
    'bike'     => 'Đặt xe tức thì',
    'motor'    => 'Lái hộ xe máy',
    'car'      => 'Lái hộ ô tô',
    _          => '',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(svc.key), color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(svc.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 1),
            Text(_sub(svc.key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Banners section ───────────────────────────────────────────────────────────

class _BannersSection extends ConsumerStatefulWidget {
  const _BannersSection();

  @override
  ConsumerState<_BannersSection> createState() => _BannersSectionState();
}

class _BannersSectionState extends ConsumerState<_BannersSection> {
  final _pageCtrl = PageController(initialPage: _bigCount ~/ 2);
  Timer? _timer;
  int _current = 0;

  static const _bigCount = 10000;

  void _startTimer(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bannerProvider);

    return async.maybeWhen(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        if (_timer == null) _startTimer(banners.length);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Nổi bật',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    height: 170,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _bigCount,
                      onPageChanged: (i) =>
                          setState(() => _current = i % banners.length),
                      itemBuilder: (_, i) =>
                          _BannerCard(banner: banners[i % banners.length]),
                    ),
                  ),
                  // Dots overlay at bottom center
                  if (banners.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(banners.length, (i) {
                          final active = i == _current;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerModel banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final card = banner.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: banner.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 170,
            placeholder: (_, __) => Container(
                color: AppColors.primary.withValues(alpha: 0.06)),
            errorWidget: (_, __, ___) =>
                _BannerPlaceholder(title: banner.title),
          )
        : _BannerPlaceholder(title: banner.title);

    if (banner.linkUrl != null && banner.linkUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(banner.linkUrl!);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: card,
      );
    }
    return card;
  }
}

class _BannerPlaceholder extends StatelessWidget {
  final String? title;
  const _BannerPlaceholder({this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: title != null
          ? Text(title!, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary))
          : Icon(Icons.image_outlined, size: 40, color: AppColors.primary.withValues(alpha: 0.3)),
    );
  }
}

// ── Contact section ───────────────────────────────────────────────────────────

// ── Voucher section ───────────────────────────────────────────────────────────

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  static IconData _typeIcon(String? type) => switch (type) {
    'freeship' => Icons.local_shipping_rounded,
    'percent'  => Icons.percent_rounded,
    _          => Icons.card_giftcard_rounded,
  };

  static Color _typeColor(String? type) => switch (type) {
    'freeship' => AppColors.info,
    'percent'  => AppColors.success,
    _          => AppColors.primary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchers = ref.watch(voucherProvider).valueOrNull ?? [];
    if (vouchers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_offer_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Ưu đãi dành cho bạn',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            GestureDetector(
              onTap: () => context.push('/vouchers'),
              child: const Text('Xem tất cả',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ]),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vouchers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final v = vouchers[i];
              final color = _typeColor(v.type);
              final icon = _typeIcon(v.type);
              final isExpiringSoon = v.expiresAt != null &&
                  v.expiresAt!.difference(DateTime.now()).inDays <= 3;
              return GestureDetector(
                onTap: () => context.push('/vouchers'),
                child: Container(
                  width: 170,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, size: 16, color: color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(v.discountLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: color)),
                              ),
                            ]),
                            const Spacer(),
                            if (v.description != null)
                              Text(v.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 1,
                              child: CustomPaint(
                                painter: _DashedLinePainter(
                                    color: color.withValues(alpha: 0.35)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: v.code));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Đã sao chép mã ${v.code}')),
                                  );
                                }
                              },
                              child: Row(children: [
                                Expanded(
                                  child: Text(v.code,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                          letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded, size: 13, color: color),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      if (isExpiringSoon)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            child: const Text('Sắp hết',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  static const _dashWidth = 4.0;
  static const _dashSpace = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
          Offset(startX, 0), Offset(startX + _dashWidth, 0), paint);
      startX += _dashWidth + _dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Quick reorder section ─────────────────────────────────────────────────────

class _QuickReorderSection extends ConsumerWidget {
  final void Function(OrderModel order) onReorder;
  const _QuickReorderSection({required this.onReorder});

  static const _reorderableTypes = {'delivery', 'shopping', 'bike', 'motor', 'car'};

  static Color _serviceColor(String type) => switch (type) {
    'delivery'  => AppColors.primary,
    'shopping'  => const Color(0xFF2196F3),
    'bike'      => const Color(0xFF9C27B0),
    'motor'     => const Color(0xFFFFA726),
    'car'       => const Color(0xFF00BCD4),
    _           => AppColors.primary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderListProvider).orders;
    final recent = orders
        .where((o) =>
            (o.isCompleted || o.isCancelled) &&
            _reorderableTypes.contains(o.serviceType))
        .take(5)
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.replay_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text('Đặt lại nhanh',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final order = recent[i];
              final color = _serviceColor(order.serviceType);
              final addr = order.pickupAddress ?? order.storeName ?? '—';
              return GestureDetector(
                onTap: () => onReorder(order),
                child: Container(
                  width: 155,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider, width: 1),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -6, bottom: -6,
                        child: Icon(
                          Fmt.serviceIcon(order.serviceType),
                          size: 48,
                          color: color.withValues(alpha: 0.06),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Fmt.serviceIcon(order.serviceType),
                                size: 18, color: color,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(Fmt.serviceLabel(order.serviceType),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(addr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const Spacer(),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('Đặt lại',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: color)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Support section ───────────────────────────────────────────────────────────

class _SupportSection extends ConsumerWidget {
  const _SupportSection();

  static IconData _icon(String type) => switch (type) {
    'phone'    => Icons.phone_outlined,
    'zalo'     => Icons.chat_bubble_outline_rounded,
    'facebook' => Icons.facebook_outlined,
    'email'    => Icons.email_outlined,
    'website'  => Icons.language_rounded,
    _          => Icons.link_rounded,
  };

  static Color _color(String type) => switch (type) {
    'phone'    => const Color(0xFF30D158),
    'zalo'     => const Color(0xFF0068FF),
    'facebook' => const Color(0xFF1877F2),
    'email'    => const Color(0xFF0A84FF),
    _          => const Color(0xFF8E8E93),
  };

  static String _url(String type, String value) => switch (type) {
    'phone' => 'tel:$value',
    'email' => 'mailto:$value',
    _       => value,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(supportProvider).valueOrNull ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.headset_mic_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text('Hỗ trợ',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              final color = _color(item.type);
              final icon = _icon(item.type);
              return GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(_url(item.type, item.value));
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                child: Container(
                  width: 100,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10, top: -10,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -8, bottom: -8,
                        child: Icon(icon, size: 44,
                            color: color.withValues(alpha: 0.07)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Icon(icon,
                                  size: 16, color: color),
                            ),
                            const Spacer(),
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            if (item.subtitle != null)
                              Text(item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color:
                                          AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              width: 20, height: 3,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Active Order Banner ───────────────────────────────────────────────────────

class _ActiveOrderBanner extends ConsumerStatefulWidget {
  const _ActiveOrderBanner();

  @override
  ConsumerState<_ActiveOrderBanner> createState() => _ActiveOrderBannerState();
}

class _ActiveOrderBannerState extends ConsumerState<_ActiveOrderBanner> {
  static const _activeStatuses = {'pending', 'assigned', 'processing'};

  StreamSubscription? _rtdbSub;
  String? _subscribedCode;

  @override
  void initState() {
    super.initState();
    // FCM fallback
    NotificationService.orderStatusStream.listen((_) {
      if (mounted) ref.read(orderListProvider.notifier).fetch();
    });
  }

  void _subscribeRTDB(String code) {
    if (_subscribedCode == code) return;
    _rtdbSub?.cancel();
    _subscribedCode = code;
    _rtdbSub = FirebaseDatabase.instance
        .ref('orders/$code')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) {
        ref.read(orderListProvider.notifier).fetch();
        return;
      }
      final map    = Map<String, dynamic>.from(data as Map);
      final status = map['status'] as String?;
      if (status == null) return;
      final orders = ref.read(orderListProvider).orders;
      final order  = orders.where((o) => o.code == code).firstOrNull;
      if (order != null && order.status != status) {
        ref.read(orderListProvider.notifier).fetch();
      }
    });
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    super.dispose();
  }

  static (String, IconData) _statusInfo(String status, String type) {
    final isRide = {'bike', 'motor', 'car'}.contains(type);
    return switch (status) {
      'pending'    => ('Đang tìm tài xế...', Icons.search_rounded),
      'assigned'   => isRide
          ? ('Tài xế đang đến đón', Icons.directions_bike_rounded)
          : ('Tài xế đang đến', Icons.delivery_dining_rounded),
      'processing' => type == 'shopping'
          ? ('Đang mua hàng cho bạn', Icons.shopping_bag_outlined)
          : ('Đang lấy hàng', Icons.inventory_2_outlined),
      'on_the_way' => isRide
          ? ('Đang trong chuyến đi', Icons.directions_bike_rounded)
          : ('Đang giao hàng', Icons.local_shipping_outlined), // legacy
      _            => (status, Icons.info_outline_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderListProvider).orders;
    final active = orders.where((o) => _activeStatuses.contains(o.status)).toList();
    if (active.isEmpty) {
      _rtdbSub?.cancel();
      _subscribedCode = null;
      return const SizedBox.shrink();
    }

    final order = active.first;
    _subscribeRTDB(order.code);
    final (statusLabel, statusIcon) = _statusInfo(order.status, order.serviceType);
    final isPending = order.status == 'pending';
    final serviceColor = AppColors.serviceColor(order.serviceType);

    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: serviceColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: serviceColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(Fmt.serviceIcon(order.serviceType),
                  size: 20, color: serviceColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Fmt.serviceLabel(order.serviceType),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: serviceColor)),
              ),
              // Active orders count badge
              if (active.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('+${active.length - 1} đơn',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: serviceColor)),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: serviceColor, size: 18),
            ]),
          ),

          // Status row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(statusIcon, size: 18, color: serviceColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(statusLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              if (isPending)
                const _PulsingDot()
              else
                Text('#${order.code}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  String _selectedType = 'all';

  static const _filters = [
    ('all',       'Tất cả'),
    ('active',    'Đang chạy'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  static const _activeStatuses = ['pending', 'assigned', 'processing'];

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(orderListProvider);
    final all     = state.orders;
    final loading = state.isLoading;

    final filtered = switch (_selectedType) {
      'all'       => all.take(10).toList(),
      'active'    => all.where((o) => _activeStatuses.contains(o.status)).take(10).toList(),
      'completed' => all.where((o) => o.isCompleted).take(10).toList(),
      'cancelled' => all.where((o) => o.isCancelled).take(10).toList(),
      _           => all.take(10).toList(),
    };

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: ColoredBox(
          color: const Color(0xFFF6F6F6),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + Filter ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Hoạt động',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    if (loading)
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (key, label) = _filters[i];
                  final selected = _selectedType == key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(label,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  );
                },
              ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
                  : state.error != null
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.wifi_off_rounded,
                                  size: 34, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Text('Không thể tải dữ liệu',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: FilledButton(
                                onPressed: () =>
                                    ref.read(orderListProvider.notifier).fetch(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  textStyle: GoogleFonts.beVietnamPro(
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ]),
                        )
                      : filtered.isEmpty
                          ? _HistoryEmpty(onTryNow: () =>
                                ref.read(_homeTabProvider.notifier).state = 0)
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () async =>
                                  ref.read(orderListProvider.notifier).fetch(),
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                itemCount: filtered.length +
                                    (state.hasMore && _selectedType == 'all' ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == filtered.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: state.isLoadingMore
                                            ? const SizedBox(width: 20, height: 20,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary))
                                            : OutlinedButton.icon(
                                                onPressed: () => ref
                                                    .read(orderListProvider.notifier)
                                                    .loadMore(),
                                                icon: const Icon(
                                                    Icons.expand_more_rounded,
                                                    size: 18),
                                                label: Text('Xem thêm',
                                                    style: GoogleFonts.beVietnamPro(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.primary,
                                                  side: const BorderSide(
                                                      color: AppColors.primary),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10)),
                                                ),
                                              ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      clipBehavior: Clip.antiAlias,
                                      elevation: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: const Color(0xFFEEEEEE)),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: _OrderCard(order: filtered[i]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _HistoryEmpty extends StatelessWidget {
  final VoidCallback onTryNow;
  const _HistoryEmpty({required this.onTryNow});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 46, color: AppColors.primary.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có đơn hàng nào',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy đặt dịch vụ đầu tiên và\ntận hưởng các ưu đãi cực khủng!',
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onTryNow,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  textStyle: GoogleFonts.beVietnamPro(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: const Text('Đặt ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color _statusColor() {
    if (order.isCompleted) return AppColors.success;
    if (order.isCancelled) return AppColors.danger;
    if (order.status == 'pending') return const Color(0xFFF59E0B);
    return AppColors.primary;
  }

  String _statusLabel() {
    if (order.isCancelled) {
      return order.cancelReason == 'no_driver' ? 'Không có tài xế' : 'Đã huỷ';
    }
    return Fmt.orderStatus(order.status);
  }

  Color _iconColor() => switch (order.serviceType) {
    'delivery' => AppColors.primary,
    'shopping' => const Color(0xFF3B82F6),
    'bike'     => const Color(0xFF10B981),
    'motor'    => const Color(0xFF8B5CF6),
    'car'      => const Color(0xFF06B6D4),
    _          => const Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    DateTime? createdAt;
    try { createdAt = DateTime.parse(order.createdAt); } catch (_) {}

    final statusColor = _statusColor();
    final netFee      = order.shippingFee - order.discountAmount;
    final pickup      = order.pickupAddress ?? order.storeName ?? '—';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left accent strip ─────────────────────────────────────
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Info ────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Text(Fmt.serviceLabel(order.serviceType),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: 8),
                        Text(Fmt.currency(netFee),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _iconColor())),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(pickup,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        // Status dot badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(_statusLabel(),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ]),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Text(Fmt.timeAgo(createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ],
                  ),
                ),
              ]),

            ],
          ),
        ),
      ),
        ],
      ),
        ),
    ),
  );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends ConsumerStatefulWidget {
  const _NotificationsTab();

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fetch khi tab này được khởi tạo (lần đầu mở tab)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchFromServer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh khi app resume về foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationProvider.notifier).fetchFromServer();
    }
  }

  String _dateLabel(DateTime dt) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(dt.year, dt.month, dt.day);
    if (!d.isBefore(today))     return 'Hôm nay';
    if (!d.isBefore(yesterday)) return 'Hôm qua';
    return 'Trước đó';
  }

  @override
  Widget build(BuildContext context) {
    final notifState  = ref.watch(notificationProvider);
    final items       = notifState.items;
    final unreadCount = items.where((n) => !n.isRead).length;

    // Build grouped list
    final listItems = <Widget>[];
    String? lastLabel;
    for (final item in items) {
      final label = _dateLabel(item.createdAt);
      if (label != lastLabel) {
        lastLabel = label;
        listItems.add(_NotifSectionHeader(label));
      }
      listItems.add(_NotifTile(
        item: item,
        onTap: () {
          ref.read(notificationProvider.notifier).markRead(item.id);
          if (item.orderCode != null) {
            context.push('/order/${item.orderCode}');
          }
        },
        onDismiss: () =>
            ref.read(notificationProvider.notifier).delete(item.id),
      ));
    }

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: ColoredBox(
          color: const Color(0xFFF6F6F6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────
              ColoredBox(
                color: Colors.white,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Thông báo',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$unreadCount',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ],
                        const Spacer(),
                        if (unreadCount > 0)
                          GestureDetector(
                            onTap: () => ref
                                .read(notificationProvider.notifier)
                                .markAllRead(),
                            child: Text('Đọc tất cả',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                ]),
              ),

              // ── List / Empty ─────────────────────────────────────────
              Expanded(
                child: items.isEmpty
                    ? const _NotifEmpty()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref
                            .read(notificationProvider.notifier)
                            .fetchFromServer(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 32),
                          itemCount: listItems.length,
                          itemBuilder: (_, i) => listItems[i],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _NotifSectionHeader extends StatelessWidget {
  final String label;
  const _NotifSectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2)),
  );
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifTile(
      {required this.item, required this.onTap, required this.onDismiss});

  Color get _accentColor => item.orderCode != null
      ? AppColors.primary
      : const Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent strip
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: item.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.3)),
                            ),
                            const SizedBox(width: 8),
                            Text(Fmt.timeAgo(item.createdAt),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(item.body,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (item.orderCode != null) ...[
                          const SizedBox(height: 6),
                          Text('Xem đơn #${item.orderCode}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ],
                    ),
                  ),

                  // Unread dot
                  if (!item.isRead) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
        ),
      ),
    ),
  );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _NotifEmpty extends StatelessWidget {
  const _NotifEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              size: 44, color: Color(0xFFBBBBBB)),
        ),
        const SizedBox(height: 20),
        Text('Chưa có thông báo nào',
            style: GoogleFonts.beVietnamPro(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Thông báo đơn hàng sẽ xuất hiện ở đây',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();
  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  String _version = '';
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportProvider.future).ignore();
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn tài khoản và toàn bộ dữ liệu của bạn. '
          'Không thể hoàn tác sau khi xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa tài khoản',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).delete('/customer/account');
    } catch (_) {}
    if (!mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user            = ref.watch(authProvider).user;
    final orders          = ref.watch(orderListProvider).orders;
    final vouchers        = ref.watch(voucherProvider).valueOrNull ?? [];
    final topPadding      = MediaQuery.of(context).padding.top;
    final completedOrders = orders.where((o) => o.isCompleted).length;

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Header ────────────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient bg
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 80),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: ClipOval(
                            child: user?.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: user!.avatarUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        _AvatarText(text: user.initials, fontSize: 30),
                                    errorWidget: (_, __, ___) =>
                                        _AvatarText(text: user.initials, fontSize: 30),
                                  )
                                : _AvatarText(text: user?.initials ?? 'U', fontSize: 30),
                          ),
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: GestureDetector(
                            onTap: () => context.push('/profile/edit'),
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 13, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      user?.name ?? 'Khách hàng',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.phone ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MemberBadge(completedOrders: completedOrders),
                  ],
                ),
              ),

              // Stats card — nổi lên đè lên gradient
              Positioned(
                left: 16, right: 16,
                bottom: -44,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                        value: '$completedOrders',
                        label: 'Đơn xong',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        onTap: () => context.push('/stats'),
                      ),
                      _StatDivider(),
                      _StatItem(
                        value: '${vouchers.length}',
                        label: 'Ưu đãi',
                        icon: Icons.local_offer_outlined,
                        color: AppColors.info,
                        onTap: () => context.push('/vouchers'),
                      ),
                      _StatDivider(),
                      _StatItem(
                        value: user?.cityName ?? '—',
                        label: 'Khu vực',
                        icon: Icons.location_on_outlined,
                        color: AppColors.primary,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 56),

          // ── Tài khoản ─────────────────────────────────────────────────
          _SettingsSection(
            header: 'Tài khoản của tôi',
            rows: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFFF6B35),
                label: 'Chỉnh sửa thông tin',
                onTap: () => context.push('/profile/edit'),
              ),
              _SettingsRow(
                icon: Icons.location_on_outlined,
                iconBg: const Color(0xFF3B82F6),
                label: 'Địa chỉ đã lưu',
                onTap: () => context.push('/profile/addresses'),
              ),
              _SettingsRow(
                icon: Icons.star_border_rounded,
                iconBg: const Color(0xFFF59E0B),
                label: 'Điểm thưởng',
                trailing: Text('$completedOrders điểm',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                onTap: () => context.push('/stats'),
              ),
              _SettingsRow(
                icon: Icons.local_offer_outlined,
                iconBg: const Color(0xFF10B981),
                label: 'Ưu đãi của bạn',
                trailing: vouchers.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${vouchers.length}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      )
                    : null,
                onTap: () => context.push('/vouchers'),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                iconBg: const Color(0xFF8B5CF6),
                label: 'Đổi mật khẩu',
                onTap: () => context.push('/profile/change-password'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Hỗ trợ & Pháp lý ─────────────────────────────────────────
          _SettingsSection(
            header: 'Pháp lý',
            rows: [
              _SettingsRow(
                icon: Icons.shield_outlined,
                iconBg: const Color(0xFF6366F1),
                label: 'Chính sách quyền riêng tư',
                onTap: () => context.push('/legal/privacy-policy?title=Chính sách quyền riêng tư'),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFF64748B),
                label: 'Điều khoản sử dụng',
                onTap: () => context.push('/legal/terms-of-service?title=Điều khoản sử dụng'),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFF94A3B8),
                label: 'Phiên bản',
                trailing: Text(
                  _version.isEmpty ? '...' : _version,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Đăng xuất + Xóa tài khoản ────────────────────────────────
          _SettingsSection(
            rows: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconBg: AppColors.danger.withValues(alpha: 0.15),
                iconColor: AppColors.danger,
                label: 'Đăng xuất',
                labelColor: AppColors.danger,
                showChevron: false,
                onTap: _confirmLogout,
              ),
              _SettingsRow(
                icon: Icons.delete_forever_outlined,
                iconBg: AppColors.danger.withValues(alpha: 0.15),
                iconColor: AppColors.danger,
                label: _deleting ? 'Đang xóa...' : 'Xóa tài khoản',
                labelColor: AppColors.danger,
                showChevron: false,
                onTap: _deleting ? null : _confirmDelete,
              ),
            ],
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Avatar text fallback ──────────────────────────────────────────────────────

class _AvatarText extends StatelessWidget {
  final String text;
  final double fontSize;
  const _AvatarText({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white),
    ),
  );
}

// ── Member badge ──────────────────────────────────────────────────────────────

class _MemberBadge extends StatelessWidget {
  final int completedOrders;
  const _MemberBadge({required this.completedOrders});

  (IconData, String) get _tier => switch (completedOrders) {
    >= 50 => (Icons.workspace_premium_rounded, 'Khách VIP'),
    >= 20 => (Icons.diamond_rounded,           'Thân thiết'),
    >= 5  => (Icons.star_rounded,              'Thường xuyên'),
    _     => (Icons.person_outline_rounded,    'Thành viên mới'),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _tier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ]),
    );
  }
}

// ── Settings section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String? header;
  final List<_SettingsRow> rows;
  const _SettingsSection({this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            header!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final isLast = i == rows.length - 1;
              return Column(children: [
                row,
                if (!isLast)
                  const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFEEEEEE),
      );
}

// ── Single settings row ───────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconBg;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.iconBg,
    this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconBg ?? const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  size: 18,
                  color: iconColor ?? Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? AppColors.textPrimary)),
            ),
            if (trailing != null) trailing!
            else if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFD0D0D5), size: 20),
          ]),
        ),
      ),
    );
  }
}

