part of '../screens/home_screen.dart';

/// Header cố định, ưu tiên vị trí giao nhận vì đây là dữ liệu người dùng cần
/// kiểm tra trước khi chọn bất kỳ dịch vụ nào.
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final double textScale;
  const _StickyHeaderDelegate(this.topPadding, this.textScale);

  // Chiều cao hàng địa chỉ / hàng chào theo cỡ chữ hệ thống, tránh bị cắt chữ.
  static const _addressRow = 56.0;
  static const _greetingRow = 48.0;
  static const _gap = 10.0;

  @override
  double get minExtent => topPadding + _gap * 2 + _addressRow * textScale;
  @override
  double get maxExtent => minExtent + (_greetingRow + _gap) * textScale;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // A pinned persistent header must always fill the extent assigned by the
    // sliver, otherwise layoutExtent can exceed paintExtent during a small scroll.
    final span = maxExtent - minExtent;
    final collapse = span <= 0 ? 1.0 : (shrinkOffset / span).clamp(0.0, 1.0);
    return SizedBox.expand(
      child: _Header(collapse: collapse, textScale: textScale),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
      oldDelegate.textScale != textScale;
}

class _Header extends ConsumerWidget {
  const _Header({required this.collapse, required this.textScale});

  /// 0 = mở rộng (có hàng chào), 1 = thu gọn (chỉ còn hàng địa chỉ).
  final double collapse;
  final double textScale;

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
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeStyle.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tìm dịch vụ',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: HomeStyle.muted),
                  filled: true,
                  fillColor: HomeStyle.cardMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: HomeStyle.orange, width: 1.5),
                  ),
                ),
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
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: HomeStyle.muted),
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
    final authState = ref.watch(authProvider);
    final user = authState.user;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9DE),
          border: Border(
            bottom: BorderSide(
              color: Color.lerp(
                const Color(0xFFFFE9DE),
                const Color(0xFFFFD7C7),
                collapse,
              )!,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Hàng chào thu dần khi cuộn thay vì đổi bố cục đột ngột.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1 - collapse,
                    child: Opacity(
                      opacity: 1 - collapse,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 10 * textScale),
                        child: SizedBox(
                          height: 48 * textScale,
                          child: Row(children: [
                            Expanded(
                              child: _HeaderGreeting(
                                name: user?.name.trim() ?? '',
                                isAuthenticated: authState.isAuthenticated,
                                onTap: () {
                                  if (authState.isAuthenticated) {
                                    ref.read(_homeTabProvider.notifier).state =
                                        3;
                                  } else {
                                    context.push('/login');
                                  }
                                },
                              ),
                            ),
                            _HeaderPointsChip(
                              points: points,
                              onTap: () {
                                if (!ref.read(authProvider).isAuthenticated) {
                                  context.push('/login');
                                  return;
                                }
                                context.push('/stats');
                              },
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: _HeaderAddressButton(
                      cityState: cityState,
                      height: 56 * textScale,
                      onTap: () => _pickAddress(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderSearchButton(
                    height: 56 * textScale,
                    onTap: () => _searchServices(context, ref),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderGreeting extends StatelessWidget {
  const _HeaderGreeting({
    required this.name,
    required this.isAuthenticated,
    required this.onTap,
  });

  final String name;
  final bool isAuthenticated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'Khách hàng';
    return Semantics(
      label: isAuthenticated
          ? 'Xin chào, $displayName'
          : 'Xin chào, đăng nhập để đặt dịch vụ',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xin chào,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.caption,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: HomeStyle.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAuthenticated ? displayName : 'Đăng nhập để đặt dịch vụ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSize.titleLarge,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.ink,
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

class _HeaderSearchButton extends StatelessWidget {
  const _HeaderSearchButton({required this.onTap, required this.height});

  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tìm dịch vụ',
        button: true,
        child: IconButton(
          tooltip: 'Tìm dịch vụ',
          onPressed: onTap,
          style: IconButton.styleFrom(
            fixedSize: Size(48, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: HomeStyle.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      );
}

class _HeaderPointsChip extends StatelessWidget {
  const _HeaderPointsChip({required this.points, required this.onTap});

  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Điểm thưởng: $points điểm',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Ink(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .70),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(
                  Icons.star_rounded,
                  color: HomeStyle.orange,
                  size: 17,
                ),
                const SizedBox(width: 5),
                Text(
                  '$points điểm',
                  style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.orange,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _HeaderAddressButton extends StatelessWidget {
  const _HeaderAddressButton({
    required this.cityState,
    required this.onTap,
    required this.height,
  });

  final ActiveCityState cityState;
  final VoidCallback onTap;
  final double height;

  String get _address {
    if (cityState.currentPlaceName?.isNotEmpty == true) {
      return '${cityState.currentPlaceName}${cityState.currentAddress.isNotEmpty ? ' · ${cityState.currentAddress}' : ''}';
    }
    if (cityState.currentAddress.isNotEmpty) return cityState.currentAddress;
    return 'Chọn địa chỉ giao đến';
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: cityState.isDetecting ? 'Đang xác định vị trí' : _address,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Ink(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HomeStyle.peach,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: HomeStyle.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: cityState.isDetecting
                      ? const Row(children: [
                          SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HomeStyle.orange,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đang xác định vị trí…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSize.body,
                                color: HomeStyle.muted,
                              ),
                            ),
                          ),
                        ])
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Địa chỉ nhận hàng',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.1,
                                color: HomeStyle.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.ink,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: HomeStyle.muted,
                ),
              ]),
            ),
          ),
        ),
      );
}
