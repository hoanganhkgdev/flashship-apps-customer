part of '../screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  void _openBooking(BuildContext ctx, WidgetRef ref, String type,
      {OrderModel? reorder, AddressModel? destAddress}) {
    if (!ref.read(authProvider).isAuthenticated) {
      ctx.push('/login');
      return;
    }
    // destAddress: dựng OrderModel tối giản chỉ set điểm đến, tái dùng cơ chế
    // prefill reorderFrom sẵn có trong các booking screen (id/code/status/... không dùng tới).
    final extra = destAddress != null
        ? OrderModel(
            id: 0,
            code: '',
            serviceType: type,
            status: 'draft',
            shippingFee: 0,
            createdAt: '',
            deliveryAddress: destAddress.address,
            deliveryLat: destAddress.latitude,
            deliveryLng: destAddress.longitude,
          )
        : reorder;
    switch (type) {
      case 'delivery':
        ctx.push('/booking/delivery', extra: extra);
        break;
      case 'shopping':
        ctx.push('/booking/shopping', extra: extra);
        break;
      case 'topup':
        ctx.push('/booking/topup');
        break;
      default:
        ctx.push('/booking/$type', extra: extra);
        break;
    }
  }

  Future<void> _pickAddressService(
      BuildContext context, WidgetRef ref, AddressModel address) async {
    final type = await showModalBottomSheet<String>(
      showDragHandle: false,
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => GlassBottomSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomeStyle.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Đặt đến "${address.displayTitle}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeStyle.title),
                ),
                const SizedBox(height: 20),
                _QuickServiceRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Giao hàng',
                  iconColor: HomeStyle.orange,
                  iconBackground: HomeStyle.peach,
                  onTap: () => Navigator.pop(ctx, 'delivery'),
                ),
                const Divider(height: 1, indent: 64, color: HomeStyle.divider),
                _QuickServiceRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Mua hộ',
                  iconColor: const Color(0xFF00B5B7),
                  iconBackground: const Color(0xFFE0F7F5),
                  onTap: () => Navigator.pop(ctx, 'shopping'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    _openBooking(context, ref, type, destAddress: address);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync service labels từ backend vào Fmt cache
    final services = ref.watch(serviceTypeProvider).valueOrNull ?? [];
    if (services.isNotEmpty) {
      Fmt.updateServiceLabels({for (final s in services) s.key: s.label});
    }

    final serviceKey = GlobalKey();
    return RefreshIndicator(
      color: HomeStyle.orange,
      onRefresh: () async {
        await ref.read(orderListProvider.notifier).fetch();
        ref.invalidate(bannerProvider);
        ref.invalidate(addressesProvider);
        ref.read(activeCityProvider.notifier).detectFromGps();
      },
      child: ColoredBox(
        color: HomeStyle.background,
        child: SafeArea(
          top: false,
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header (app bar cố định) ──────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  MediaQuery.paddingOf(context).top,
                  MediaQuery.textScalerOf(context).scale(16).clamp(16, 22) / 16,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Đơn đang hoạt động: ưu tiên cao nhất khi có đơn ──────────
              const SliverToBoxAdapter(child: _ActiveOrdersOverview()),

              // ── Services ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _ServiceIconGrid(
                  key: serviceKey,
                  onTap: (type) => _openBooking(context, ref, type),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: _BannersSection(onBook: () {
                  final target = serviceKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(target,
                        duration: const Duration(milliseconds: 350));
                  }
                }),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Đặt lại từ các đơn đã hoàn thành gần đây ─────────────────
              SliverToBoxAdapter(
                child: _RecentOrdersSection(
                  onReorder: (order) => _openBooking(
                    context,
                    ref,
                    order.serviceType,
                    reorder: order,
                  ),
                ),
              ),

              // ── Đặt nhanh (địa chỉ đã lưu) ─────────────────────────────────
              SliverToBoxAdapter(
                child: _SavedAddressQuickRow(
                  onPickAddress: (addr) =>
                      _pickAddressService(context, ref, addr),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Ưu đãi dành cho bạn ──────────────────────────────────────
              const SliverToBoxAdapter(child: _VoucherSection()),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Kênh hỗ trợ nhanh ────────────────────────────────────────
              const SliverToBoxAdapter(child: _HomeSupportSection()),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // The scaffold already reserves space for bottom navigation.
              SliverToBoxAdapter(
                child: SizedBox(height: BottomNav.reservedHeight(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
