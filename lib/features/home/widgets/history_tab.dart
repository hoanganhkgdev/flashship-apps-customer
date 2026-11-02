part of '../screens/home_screen.dart';

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  String _filter = 'all';
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  static const _filters = [
    ('all', 'Tất cả'),
    ('active', 'Đang thực hiện'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderListProvider);
    final query = _searchCtrl.text.trim().toLowerCase();
    final orders = state.orders.where((order) {
      final statusMatches = switch (_filter) {
        'active' => order.isActive,
        'completed' => order.isCompleted,
        'cancelled' => order.isCancelled,
        _ => true,
      };
      if (!statusMatches) return false;
      if (query.isEmpty) return true;
      return order.code.toLowerCase().contains(query) ||
          (order.pickupAddress?.toLowerCase().contains(query) ?? false) ||
          (order.deliveryAddress?.toLowerCase().contains(query) ?? false) ||
          Fmt.serviceLabel(order.serviceType).toLowerCase().contains(query);
    }).toList();

    return ColoredBox(
      color: HomeStyle.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(children: [
          _OrdersHeader(
            searching: _searching,
            loading: state.isLoading,
            controller: _searchCtrl,
            selected: _filter,
            onToggleSearch: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
            onChanged: () => setState(() {}),
            onFilter: (value) => setState(() => _filter = value),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: HomeStyle.orange))
                : state.error != null
                    ? _OrdersError(
                        onRetry: () =>
                            ref.read(orderListProvider.notifier).fetch())
                    : RefreshIndicator(
                        color: HomeStyle.orange,
                        onRefresh: () async =>
                            ref.read(orderListProvider.notifier).fetch(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 18, 16,
                              32 + BottomNav.reservedHeight(context)),
                          children: [
                            if (orders.isEmpty)
                              _HistoryEmpty(
                                filtered: query.isNotEmpty || _filter != 'all',
                                onBook: () => ref
                                    .read(_homeTabProvider.notifier)
                                    .state = 0,
                              )
                            else
                              ..._sections(orders),
                            if (state.hasMore)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: state.isLoadingMore
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: HomeStyle.orange))
                                      : OutlinedButton.icon(
                                          onPressed: () => ref
                                              .read(orderListProvider.notifier)
                                              .loadMore(),
                                          icon: const Icon(
                                              Icons.expand_more_rounded,
                                              size: 18),
                                          label: const Text('Xem thêm'),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _sections(List<OrderModel> orders) {
    final result = <Widget>[];
    final active = orders.where((o) => o.isActive).toList();
    if (active.isNotEmpty) {
      result.add(_GroupTitle(
          label: 'Đang thực hiện',
          count: active.length,
          icon: Icons.local_shipping_rounded));
      result.add(const SizedBox(height: 10));
      for (final order in active) {
        result.add(_OrderCard(order: order, active: true));
        result.add(const SizedBox(height: 12));
      }
    }
    final groups = <String, List<OrderModel>>{};
    for (final order in orders.where((o) => !o.isActive)) {
      final date = DateTime.tryParse(order.createdAt)?.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day =
          date == null ? null : DateTime(date.year, date.month, date.day);
      final label = day == today
          ? 'Hôm nay'
          : day != null && today.difference(day).inDays < 7
              ? 'Tuần này'
              : 'Trước đó';
      groups.putIfAbsent(label, () => []).add(order);
    }
    for (final label in ['Hôm nay', 'Tuần này', 'Trước đó']) {
      final group = groups[label];
      if (group == null) continue;
      result.add(Padding(
        padding: EdgeInsets.only(top: result.isEmpty ? 0 : 8),
        child: _GroupTitle(label: label, count: group.length),
      ));
      result.add(const SizedBox(height: 10));
      for (final order in group) {
        result.add(_OrderCard(order: order));
        result.add(const SizedBox(height: 10));
      }
    }
    return result;
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.searching,
    required this.loading,
    required this.controller,
    required this.selected,
    required this.onToggleSearch,
    required this.onChanged,
    required this.onFilter,
  });
  final bool searching;
  final bool loading;
  final TextEditingController controller;
  final String selected;
  final VoidCallback onToggleSearch;
  final VoidCallback onChanged;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Đơn '),
                          TextSpan(
                              text: 'hàng',
                              style: TextStyle(color: HomeStyle.orange)),
                        ]),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.4,
                            color: HomeStyle.ink),
                      ),
                      SizedBox(height: 5),
                      Text('Theo dõi đơn và đặt lại khi cần',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              height: 1.35,
                              color: HomeStyle.muted)),
                    ]),
              ),
              const SizedBox(width: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: HomeStyle.orange)),
                )
              else
                IconButton(
                  tooltip: searching ? 'Đóng tìm kiếm' : 'Tìm đơn',
                  onPressed: onToggleSearch,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(44),
                    backgroundColor: HomeStyle.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: Icon(
                      searching ? Icons.close_rounded : Icons.search_rounded,
                      color: Colors.white,
                      size: 21),
                ),
            ]),
            if (searching) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  hintText: 'Tìm mã đơn hoặc địa chỉ...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: HomeStyle.muted),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .9),
                  border: border(const Color(0xFFFFD1BF)),
                  enabledBorder: border(const Color(0xFFFFD1BF)),
                  focusedBorder: border(HomeStyle.orange),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 44 +
                  (MediaQuery.textScalerOf(context).scale(12) - 12)
                      .clamp(0.0, double.infinity),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _HistoryTabState._filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (key, label) = _HistoryTabState._filters[i];
                  final chosen = selected == key;
                  return ChoiceChip(
                    selected: chosen,
                    showCheckmark: false,
                    onSelected: (_) => onFilter(key),
                    label: Text(label),
                    labelStyle: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: chosen ? Colors.white : HomeStyle.muted),
                    selectedColor: HomeStyle.orange,
                    backgroundColor: Colors.white.withValues(alpha: .76),
                    side: BorderSide(
                        color: chosen
                            ? HomeStyle.orange
                            : const Color(0xFFFFD1BF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.label,
    required this.count,
    this.icon = Icons.calendar_today_rounded,
  });
  final String label;
  final int count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: HomeStyle.peach, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: HomeStyle.orange),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w800,
                  color: HomeStyle.ink)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: HomeStyle.card,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: HomeStyle.divider)),
          child: Text('$count đơn',
              style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.muted)),
        ),
      ]);
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.active = false});
  final OrderModel order;
  final bool active;

  void _reorder(BuildContext context) {
    final path = switch (order.serviceType) {
      'delivery' => '/booking/delivery',
      'shopping' => '/booking/shopping',
      'topup' => '/booking/topup',
      final type => '/booking/$type',
    };
    context.push(path, extra: order.serviceType == 'topup' ? null : order);
  }

  @override
  Widget build(BuildContext context) {
    if (active) return HomeOrderCard(order: order);
    final serviceColor = AppColors.serviceColor(order.serviceType);
    final pickup = order.pickupAddress ?? order.storeName ?? 'Chưa cập nhật';
    final delivery = order.deliveryAddress ?? 'Chưa cập nhật điểm giao';
    final date = DateTime.tryParse(order.createdAt)?.toLocal();
    return Material(
      color: Colors.transparent,
      borderRadius: HomeStyle.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        borderRadius: HomeStyle.cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeStyle.card,
            borderRadius: HomeStyle.cardRadius,
            border: Border.all(color: HomeStyle.divider),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(3),
                child: _ServiceGlyph(
                    type: order.serviceType, color: serviceColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.serviceLabel(order.serviceType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      const SizedBox(height: 3),
                      Text('#${order.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ]),
              ),
              const SizedBox(width: 8),
              _StatusPill(order: order),
            ]),
            const SizedBox(height: 14),
            _RouteSummary(pickup: pickup, delivery: delivery),
            const SizedBox(height: 13),
            const Divider(height: 1, color: HomeStyle.divider),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: HomeStyle.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(date == null ? '—' : Fmt.timeAgo(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSize.caption, color: HomeStyle.muted)),
              ),
              Text(Fmt.currency(order.shippingFee),
                  style: const TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink)),
            ]),
            if (order.isCompleted) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _reorder(context),
                  style: TextButton.styleFrom(
                      foregroundColor: HomeStyle.orange,
                      backgroundColor: HomeStyle.peach,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      )),
                  icon: const Icon(Icons.replay_rounded, size: 17),
                  label: const Text('Đặt lại',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.order});
  final OrderModel order;
  @override
  Widget build(BuildContext context) {
    final color = order.isCompleted
        ? AppColors.success
        : order.isCancelled
            ? AppColors.danger
            : order.status == 'pending'
                ? AppColors.warning
                : HomeStyle.orange;
    final label = order.isCancelled && order.cancelReason == 'no_driver'
        ? 'Không có tài xế'
        : Fmt.orderStatus(order.status);
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.pickup, required this.delivery});
  final String pickup;
  final String delivery;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: HomeStyle.cardMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(children: [
          Semantics(
            label: 'Điểm đi',
            child: _RouteLine(
              icon: Icons.radio_button_checked_rounded,
              color: HomeStyle.orange,
              text: pickup,
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Điểm đến',
            child: _RouteLine(
              icon: Icons.location_on_outlined,
              color: AppColors.info,
              text: delivery,
              maxLines: 2,
            ),
          ),
        ]),
      );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.filtered, required this.onBook});
  final bool filtered;
  final VoidCallback onBook;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 46, 32, 20),
        child: Column(children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(24)),
            child: Icon(
                filtered
                    ? Icons.manage_search_rounded
                    : Icons.receipt_long_rounded,
                size: 36,
                color: HomeStyle.orange),
          ),
          const SizedBox(height: 20),
          Text(filtered ? 'Không có đơn phù hợp' : 'Chưa có đơn hàng nào',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w800,
                  color: HomeStyle.ink)),
          const SizedBox(height: 8),
          Text(
              filtered
                  ? 'Thử đổi trạng thái hoặc từ khóa tìm kiếm.'
                  : 'Đơn hàng bạn đặt sẽ được lưu và theo dõi tại đây.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.body,
                  height: 1.5,
                  color: HomeStyle.muted)),
          if (!filtered) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                      elevation: 0, backgroundColor: HomeStyle.orange),
                  child: const Text('Đặt đơn ngay',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ),
          ],
        ]),
      );
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: HomeStyle.card,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: HomeStyle.divider)),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 34, color: HomeStyle.muted)),
          const SizedBox(height: 16),
          const Text('Không thể tải đơn hàng',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.ink)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  elevation: 0, backgroundColor: HomeStyle.orange),
              child: const Text('Thử lại')),
        ]),
      );
}
