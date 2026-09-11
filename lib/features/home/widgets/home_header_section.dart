part of '../screens/home_screen.dart';

/// Ghim header cố định trên cùng như một app bar thật — nội dung cuộn bên
/// dưới sẽ bị lớp kính mờ của header khúc xạ qua.
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  const _StickyHeaderDelegate(this.height);

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const _Header();

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.height != height;
}

class _Header extends ConsumerWidget {
  const _Header();

  Future<void> _pickAddress(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result != null && context.mounted) {
      ref
          .read(activeCityProvider.notifier)
          .overrideAddress(result.address, placeName: result.placeName);
    }
  }

  Future<void> _searchServices(BuildContext context, WidgetRef ref) async {
    final services = ref.read(serviceTypeProvider).valueOrNull ?? [];
    var query = '';
    final selected = await showModalBottomSheet<String>(
      showDragHandle: false,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) {
        final matches = services
            .where((s) => s.label.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return GlassBottomSheet(
            child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Tìm dịch vụ', prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() => query = value)),
            const SizedBox(height: 12),
            Flexible(
                child: ListView(shrinkWrap: true, children: [
              if (matches.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Không tìm thấy dịch vụ phù hợp')),
              for (final service in matches)
                ListTile(
                    title: Text(service.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheetContext, service.key)),
            ])),
          ]),
        ));
      }),
    );
    if (selected != null && context.mounted) {
      const HomeTab()._openBooking(context, ref, selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points =
        ref.watch(orderListProvider).orders.where((o) => o.isCompleted).length;
    final cityState = ref.watch(activeCityProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: LiquidGlass(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                            label: 'Flashship',
                            image: true,
                            child: ExcludeSemantics(
                                child: SizedBox(
                                    height: 40,
                                    child: Image.asset(
                                        'assets/images/logo-n.png',
                                        fit: BoxFit.contain,
                                        alignment: Alignment.centerLeft))))),
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                      label: 'Tìm dịch vụ',
                      button: true,
                      child: IconButton(
                        tooltip: 'Tìm dịch vụ',
                        onPressed: () => _searchServices(context, ref),
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(38),
                          backgroundColor: Colors.white.withValues(alpha: .34),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: .78)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.search_rounded,
                            color: HomeStyle.muted, size: 20),
                      )),
                  const SizedBox(width: 8),
                  Semantics(
                      label: 'Điểm thưởng: $points điểm',
                      button: true,
                      child: InkWell(
                        onTap: () {
                          if (!ref.read(authProvider).isAuthenticated) {
                            context.push('/login');
                            return;
                          }
                          context.push('/stats');
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: .58),
                                  HomeStyle.orange.withValues(alpha: .12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .78))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded,
                                color: HomeStyle.orange, size: 17),
                            const SizedBox(width: 5),
                            Text('$points',
                                style: const TextStyle(
                                    fontSize: AppFontSize.caption,
                                    fontWeight: FontWeight.w700,
                                    color: HomeStyle.orange)),
                          ]),
                        ),
                      )),
                ]),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickAddress(context, ref),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .30),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .72)),
                      ),
                      child: Row(children: [
                        const GlassIcon(
                          icon: Icons.location_on_rounded,
                          color: HomeStyle.orange,
                          size: 28,
                          iconSize: 16,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                            child: cityState.isDetecting
                                ? const Text('Đang xác định vị trí…',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14, color: HomeStyle.muted))
                                : Text(
                                    cityState.currentPlaceName?.isNotEmpty ==
                                            true
                                        ? '${cityState.currentPlaceName}${cityState.currentAddress.isNotEmpty ? ' · ${cityState.currentAddress}' : ''}'
                                        : cityState.currentAddress.isNotEmpty
                                            ? cityState.currentAddress
                                            : 'Chọn địa chỉ giao đến',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: AppFontSize.body,
                                        fontWeight: FontWeight.w600,
                                        color: HomeStyle.ink))),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 19, color: HomeStyle.muted),
                      ]),
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
