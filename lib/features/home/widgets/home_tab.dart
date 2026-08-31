part of '../screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

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
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Đặt đến "${address.displayTitle}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSize.display,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 20),
                _QuickServiceRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Giao hàng',
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primarySoft,
                  onTap: () => Navigator.pop(ctx, 'delivery'),
                ),
                const Divider(height: 1, indent: 64, color: AppColors.divider),
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
    final user = ref.watch(authProvider).user;
    final cityState = ref.watch(activeCityProvider);

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

            // ── Services ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ServiceIconGrid(
                onTap: (type) => _openBooking(context, ref, type),
              ),
            ),

            // ── Đơn đang hoạt động ───────────────────────────────────────
            const SliverToBoxAdapter(child: _ActiveOrdersOverview()),

            // ── Đặt nhanh (địa chỉ đã lưu) ─────────────────────────────────
            SliverToBoxAdapter(
              child: _SavedAddressQuickRow(
                onPickAddress: (addr) =>
                    _pickAddressService(context, ref, addr),
              ),
            ),

            // ── Ưu đãi dành cho bạn ──────────────────────────────────────
            const SliverToBoxAdapter(child: _VoucherSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Chừa chỗ cho thanh bottom nav kính mờ (extendBody: true ở
            // HomeScreen) — không thì phần cuối bị nav che mất.
            SliverToBoxAdapter(
              child: SizedBox(height: BottomNav.reservedHeight(context)),
            ),
          ],
        ),
      ),
    );
  }
}
