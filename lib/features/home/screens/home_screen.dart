import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottom + 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
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
                showBadge
                    ? Badge(
                        label: Text('$unreadCount',
                            style: const TextStyle(fontSize: 10)),
                        child: Icon(selected ? tab.on : tab.off,
                            size: 24, color: color),
                      )
                    : Icon(selected ? tab.on : tab.off,
                        size: 24, color: color),
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
  final bool isDetecting;
  const _Header({
    required this.name,
    required this.initials,
    required this.currentAddress,
    required this.isDetecting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Decorative circles ─────────────────────────────────────────
          Positioned(top: -30, right: -30,
              child: _HeaderCircle(140, 0.08)),
          Positioned(top: 60, right: 80,
              child: _HeaderCircle(60, 0.05)),

          // ── Content ────────────────────────────────────────────────────
          SafeArea(
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
                                    .overrideAddress(result.address);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào, $name',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                isDetecting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Colors.white))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              currentAddress.isNotEmpty
                                                  ? currentAddress
                                                  : 'Đang xác định vị trí...',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Colors.white,
                                              size: 18),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ),

                        // Points badge (toggle style)
                        GestureDetector(
                          onTap: () => context.push('/stats'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                '${ref.watch(orderListProvider).orders.where((o) => o.isCompleted).length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.attach_money_rounded,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _HeaderCircle(this.size, this.opacity);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
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
        borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceTypeProvider).valueOrNull ?? [];
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Dịch vụ',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const cols  = 4;
              final itemW = constraints.maxWidth / cols;
              return Wrap(
                children: services.map((svc) => SizedBox(
                  width: itemW,
                  child: _ServiceIconItem(
                    svc: svc,
                    onTap: () => onTap(svc.key),
                  ),
                )).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ServiceIconItem extends StatelessWidget {
  final ServiceTypeModel svc;
  final VoidCallback onTap;
  const _ServiceIconItem({required this.svc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ServiceIcon(svc: svc),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    svc.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  final ServiceTypeModel svc;
  const _ServiceIcon({required this.svc});

  @override
  Widget build(BuildContext context) {
    if (svc.iconUrl != null && svc.iconUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: svc.iconUrl!,
        width: 56, height: 56,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(width: 56, height: 56),
        errorWidget: (_, __, ___) => const Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
          size: 48,
        ),
      );
    }
    return const SizedBox(width: 56, height: 56);
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
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Nổi bật',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
          ),

          // Banner carousel with overlay dots (Grab style)
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
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Ưu đãi dành cho bạn',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
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
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vouchers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final v = vouchers[i];
              final isExpiringSoon = v.expiresAt != null &&
                  v.expiresAt!.difference(DateTime.now()).inDays <= 3;
              final color = switch (v.type) {
                'freeship' => AppColors.info,
                'percent'  => AppColors.success,
                _          => AppColors.primary,
              };
              return GestureDetector(
                onTap: () => context.push('/vouchers'),
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2), width: 1),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top: discount badge
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(v.discountLabel,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        const Spacer(),
                        if (isExpiringSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Sắp hết',
                                style: TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w600,
                                    color: AppColors.danger)),
                          ),
                      ]),

                      // Bottom: description + code
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (v.description != null)
                            Text(v.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500,
                                    color: color)),
                          const SizedBox(height: 2),
                          Text(v.code,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5)),
                        ],
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

// ── Quick reorder section ─────────────────────────────────────────────────────

class _QuickReorderSection extends ConsumerWidget {
  final void Function(OrderModel order) onReorder;
  const _QuickReorderSection({required this.onReorder});

  static const _reorderableTypes = {'delivery', 'shopping', 'bike', 'motor', 'car'};

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
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Đặt lại nhanh',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: recent.asMap().entries.map((e) {
              final i     = e.key;
              final order = e.value;
              final addr  = order.pickupAddress ?? order.storeName ?? '—';
              return Column(children: [
                InkWell(
                  onTap: () => onReorder(order),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(children: [
                      SizedBox(
                        width: 24,
                        child: Icon(Fmt.serviceIcon(order.serviceType),
                            size: 20, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Fmt.serviceLabel(order.serviceType),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(addr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Đặt lại',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ]),
                  ),
                ),
                if (i < recent.length - 1)
                  const Divider(height: 1, indent: 58, color: Color(0xFFF5F5F5)),
              ]);
            }).toList(),
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

    return GestureDetector(
      onTap: () => context.push('/order/${order.code}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(Fmt.serviceIcon(order.serviceType),
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Fmt.serviceLabel(order.serviceType),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              // Active orders count badge
              if (active.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('+${active.length - 1} đơn',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 18),
            ]),
          ),

          // Status row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(statusIcon, size: 18, color: AppColors.primary),
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
    ('all',      'Tất cả'),
    ('active',   'Trong chuyến'),
    ('delivery', 'Lấy Hộ'),
    ('shopping', 'Mua Hộ'),
    ('bike',     'Xe Ôm'),
    ('motor',    'Lái Xe Máy'),
    ('car',      'Lái Xe Hơi'),
  ];

  static const _activeStatuses = ['pending', 'assigned', 'processing'];

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(orderListProvider);
    final all     = state.orders;
    final loading = state.isLoading;

    final filtered = switch (_selectedType) {
      'all'    => all.take(10).toList(),
      'active' => all.where((o) => _activeStatuses.contains(o.status)).take(10).toList(),
      _        => all.where((o) => o.serviceType == _selectedType).take(10).toList(),
    };

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Hoạt động',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (loading)
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 12),

                // Filter chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
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
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(label,
                                style: TextStyle(
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
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
                : state.error != null
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text('Không thể tải dữ liệu'),
                          TextButton(
                            onPressed: () => ref.read(orderListProvider.notifier).fetch(),
                            child: const Text('Thử lại'),
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
                            child: ListView(
                              padding: const EdgeInsets.only(top: 8, bottom: 32),
                              children: [
                                Container(
                                  color: Colors.white,
                                  child: Column(
                                    children: filtered.asMap().entries.map((e) {
                                      final i = e.key;
                                      return Column(children: [
                                        _OrderCard(order: e.value),
                                        if (i < filtered.length - 1)
                                          const Divider(height: 1, indent: 60,
                                              color: Color(0xFFF5F5F5)),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                                // Xem thêm
                                if (state.hasMore && _selectedType == 'all')
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: state.isLoadingMore
                                          ? const SizedBox(width: 20, height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary))
                                          : TextButton.icon(
                                              onPressed: () => ref
                                                  .read(orderListProvider.notifier)
                                                  .loadMore(),
                                              icon: const Icon(
                                                  Icons.expand_more_rounded,
                                                  size: 18),
                                              label: const Text('Xem thêm'),
                                              style: TextButton.styleFrom(
                                                  foregroundColor: AppColors.primary),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
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
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_rounded,
                size: 80,
                color: AppColors.primary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Bạn đã thử dịch vụ của Flash Ship chưa?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thử sử dụng các dịch vụ cùng các ưu đãi cực khủng',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTryNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Trải nghiệm ngay',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    DateTime? createdAt;
    try { createdAt = DateTime.parse(order.createdAt); } catch (_) {}

    final statusColor = _statusColor();
    final netFee      = order.shippingFee - order.discountAmount;
    final pickup      = order.pickupAddress ?? order.storeName ?? '—';

    return InkWell(
      onTap: () => context.push('/order/${order.code}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Service icon
          SizedBox(
            width: 40,
            child: Icon(Fmt.serviceIcon(order.serviceType),
                size: 26, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(Fmt.serviceLabel(order.serviceType),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Text(Fmt.currency(netFee),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 3),
                Text(pickup,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_statusLabel(),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(Fmt.timeAgo(createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  if ((order.isCompleted || order.isCancelled) &&
                      order.serviceType != 'topup') ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _reorder(context),
                      child: const Text('Đặt lại',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _reorder(BuildContext context) {
    switch (order.serviceType) {
      case 'delivery':
        context.push('/booking/delivery', extra: order);
      case 'shopping':
        context.push('/booking/shopping', extra: order);
      case 'bike':
      case 'motor':
      case 'car':
        context.push('/booking/${order.serviceType}', extra: order);
      default:
        context.push('/booking/delivery', extra: order);
    }
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

  @override
  Widget build(BuildContext context) {
    final notifState  = ref.watch(notificationProvider);
    final items       = notifState.items;
    final unreadCount = items.where((n) => !n.isRead).length;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Thông báo',
                    style: TextStyle(
                        fontSize: 26,
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
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
                const Spacer(),
                if (unreadCount > 0)
                  GestureDetector(
                    onTap: () =>
                        ref.read(notificationProvider.notifier).markAllRead(),
                    child: const Text('Đọc tất cả',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
              ],
            ),
          ),

          // ── List / Empty ──────────────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? const _NotifEmpty()
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: [
                      Container(
                        color: Colors.white,
                        child: Column(
                          children: items.asMap().entries.map((e) {
                            final i    = e.key;
                            final item = e.value;
                            return Column(children: [
                              _NotifTile(
                                item: item,
                                onTap: () {
                                  ref.read(notificationProvider.notifier)
                                      .markRead(item.id);
                                  if (item.orderCode != null) {
                                    context.push('/order/${item.orderCode}');
                                  }
                                },
                                onDismiss: () => ref
                                    .read(notificationProvider.notifier)
                                    .delete(item.id),
                              ),
                              if (i < items.length - 1)
                                const Divider(height: 1, indent: 54,
                                    color: Color(0xFFF5F5F5)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifTile(
      {required this.item, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isOrder = item.orderCode != null;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: AppColors.danger.withValues(alpha: 0.08),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: item.isRead
              ? Colors.white
              : AppColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: (isOrder ? AppColors.primary
                    : const Color(0xFF8B5CF6)).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOrder ? Icons.local_shipping_outlined : Icons.campaign_outlined,
                size: 20,
                color: isOrder ? AppColors.primary : const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(item.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w500 : FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3)),
                    ),
                    const SizedBox(width: 8),
                    Text(Fmt.timeAgo(item.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 3),
                  Text(item.body,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (isOrder) ...[
                    const SizedBox(height: 5),
                    Text('Xem đơn #${item.orderCode}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
          ]),
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
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications_none_rounded,
              size: 48, color: Color(0xFFBBBBBB)),
        ),
        const SizedBox(height: 20),
        const Text('Chưa có thông báo nào',
            style: TextStyle(
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

  void _showSupport() {
    final items = ref.read(supportProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Hỗ trợ khách hàng',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            if (items.isEmpty)
              InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(children: [
                    SizedBox(width: 24,
                        child: Icon(Icons.phone_outlined, size: 22,
                            color: AppColors.textSecondary)),
                    SizedBox(width: 16),
                    Expanded(child: Text('Hotline hỗ trợ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                    Text('Liên hệ quản trị viên',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
              )
            else
              ...items.asMap().entries.map((e) {
                final i    = e.key;
                final item = e.value;
                final icon  = _supportIcon(item.type);
                final color = _supportColor(item.type);
                final url   = _supportUrl(item.type, item.value);
                return Column(children: [
                  InkWell(
                    onTap: () { Navigator.pop(ctx); _openUrl(url); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(children: [
                        SizedBox(width: 24,
                            child: Icon(icon, size: 22, color: color)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            if (item.subtitle != null)
                              Text(item.subtitle!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ],
                        )),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: Color(0xFFD0D0D5)),
                      ]),
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 60,
                        color: Color(0xFFF5F5F5)),
                ]);
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _supportIcon(String type) => switch (type) {
    'phone'    => Icons.phone_outlined,
    'zalo'     => Icons.chat_bubble_outline_rounded,
    'facebook' => Icons.facebook_outlined,
    'email'    => Icons.email_outlined,
    'website'  => Icons.language_rounded,
    _          => Icons.link_rounded,
  };

  Color _supportColor(String type) => switch (type) {
    'phone'    => const Color(0xFF30D158),
    'zalo'     => const Color(0xFF0068FF),
    'facebook' => const Color(0xFF1877F2),
    'email'    => const Color(0xFF0A84FF),
    _          => const Color(0xFF8E8E93),
  };

  String _supportUrl(String type, String value) => switch (type) {
    'phone' => 'tel:$value',
    'email' => 'mailto:$value',
    _       => value,
  };

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  @override
  Widget build(BuildContext context) {
    final user       = ref.watch(authProvider).user;
    final orders     = ref.watch(orderListProvider).orders;
    final vouchers   = ref.watch(voucherProvider).valueOrNull ?? [];
    final topPadding = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Profile header ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8720C), Color(0xFFFF9A3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 24),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _ProfileHeaderPainter())),
                Center(child: Column(children: [
                  // Avatar lớn căn giữa
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: ClipOval(
                      child: user?.avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user!.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  _AvatarText(text: user.initials, fontSize: 32),
                              errorWidget: (_, __, ___) =>
                                  _AvatarText(text: user.initials, fontSize: 32),
                            )
                          : _AvatarText(text: user?.initials ?? 'U', fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tên
                  Text(user?.name ?? 'Khách hàng',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  // Số điện thoại
                  Text(user?.phone ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 10),
                  // Hạng thành viên + khu vực
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _MemberBadge(completedOrders: orders.where((o) => o.isCompleted).length),
                    if (user?.cityName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.location_on_rounded,
                              size: 12, color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(width: 3),
                          Text(user!.cityName!,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9))),
                        ]),
                      ),
                    ],
                  ]),
                ])),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Tài khoản ─────────────────────────────────────────────────
          _SettingsSection(
            header: 'Tài khoản',
            rows: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                label: 'Chỉnh sửa thông tin',
                onTap: () => context.push('/profile/edit'),
              ),
              _SettingsRow(
                icon: Icons.location_on_outlined,
                label: 'Địa chỉ đã lưu',
                onTap: () => context.push('/profile/addresses'),
              ),
              _SettingsRow(
                icon: Icons.star_border_rounded,
                label: 'Điểm thưởng',
                trailing: orders.isNotEmpty
                    ? Text('${orders.where((o) => o.isCompleted).length} điểm',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary))
                    : null,
                onTap: () => context.push('/stats'),
              ),
              _SettingsRow(
                icon: Icons.local_offer_outlined,
                label: 'Ưu đãi của bạn',
                trailing: vouchers.isNotEmpty
                    ? Text('${vouchers.length}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary))
                    : null,
                onTap: () => context.push('/vouchers'),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: 'Đổi mật khẩu',
                onTap: () => context.push('/profile/change-password'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Hỗ trợ & Pháp lý ─────────────────────────────────────────
          _SettingsSection(
            header: 'Hỗ trợ & Pháp lý',
            rows: [
              _SettingsRow(
                icon: Icons.headset_mic_outlined,
                label: 'Hỗ trợ khách hàng',
                onTap: _showSupport,
              ),
              _SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Chính sách quyền riêng tư',
                onTap: () => context.push('/legal/privacy-policy?title=Chính sách quyền riêng tư'),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'Điều khoản sử dụng',
                onTap: () => context.push('/legal/terms-of-service?title=Điều khoản sử dụng'),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
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

          const SizedBox(height: 8),

          // ── Đăng xuất + Xóa tài khoản ────────────────────────────────
          _SettingsSection(
            rows: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.danger,
                label: 'Đăng xuất',
                labelColor: AppColors.danger,
                showChevron: false,
                onTap: _confirmLogout,
              ),
              _SettingsRow(
                icon: Icons.delete_forever_outlined,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.95)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95))),
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
          child: Row(children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(header!,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        ),
      Container(
        color: Colors.white,
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
    ]);
  }
}

// ── Single settings row (Grab-style) ─────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(children: [
            SizedBox(
              width: 24,
              child: Icon(icon,
                  size: 22,
                  color: iconColor ?? AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
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

// ── Profile header decorative painter ─────────────────────────────────────────

class _ProfileHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);

    // Large circle — bottom right
    canvas.drawCircle(
      Offset(size.width + 10, size.height + 20),
      110,
      paint,
    );

    // Medium circle — top right
    canvas.drawCircle(
      Offset(size.width - 30, -20),
      70,
      paint,
    );

    // Small circle — left center
    canvas.drawCircle(
      Offset(-20, size.height * 0.5),
      45,
      paint..color = Colors.white.withValues(alpha: 0.06),
    );

    // Tiny circle — top left
    canvas.drawCircle(
      Offset(size.width * 0.35, 18),
      18,
      paint..color = Colors.white.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
