part of '../screens/home_screen.dart';

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
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  static const _filters = [
    ('all', 'Tất cả'),
    ('pending', 'Chờ xử lý'),
    ('active', 'Đang xử lý'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  static const _activeStatuses = ['pending', 'assigned', 'processing'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderListProvider);
    final all = state.orders;
    final loading = state.isLoading;

    final byStatus = switch (_selectedType) {
      'all' => all,
      'pending' => all.where((o) => o.status == 'pending').toList(),
      'active' => all
          .where((o) =>
              _activeStatuses.contains(o.status) && o.status != 'pending')
          .toList(),
      'completed' => all.where((o) => o.isCompleted).toList(),
      'cancelled' => all.where((o) => o.isCancelled).toList(),
      _ => all,
    };
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = byStatus
        .where((order) {
          if (query.isEmpty) return true;
          return order.code.toLowerCase().contains(query) ||
              (order.pickupAddress?.toLowerCase().contains(query) ?? false) ||
              (order.deliveryAddress?.toLowerCase().contains(query) ?? false) ||
              Fmt.serviceLabel(order.serviceType).toLowerCase().contains(query);
        })
        .take(10)
        .toList();

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header + Filter ──────────────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Hoạt động',
                          style: TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      if (loading)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                      else
                        IconButton(
                          onPressed: () => setState(() {
                            _searching = !_searching;
                            if (!_searching) _searchCtrl.clear();
                          }),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(42, 42),
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          icon: Icon(
                            _searching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ]),
                    if (_searching) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tìm mã đơn hoặc địa chỉ...',
                          hintStyle: TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            color: AppColors.textTertiary,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textTertiary,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                ),
                              ),
                              child: Center(
                                child: Text(label,
                                    style: TextStyle(
                                        fontSize: AppFontSize.body,
                                        fontWeight: selected
                                            ? FontWeight.w600
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
              const Divider(height: 1, color: AppColors.divider),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                    : state.error != null
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.card),
                                    ),
                                    child: const Icon(Icons.wifi_off_rounded,
                                        size: 34,
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Không thể tải dữ liệu',
                                      style: TextStyle(
                                          fontSize: AppFontSize.bodyLarge,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 40,
                                    child: FilledButton(
                                      onPressed: () => ref
                                          .read(orderListProvider.notifier)
                                          .fetch(),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        textStyle: TextStyle(
                                            fontSize: AppFontSize.body,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      child: const Text('Thử lại'),
                                    ),
                                  ),
                                ]),
                          )
                        : filtered.isEmpty
                            ? _HistoryEmpty(
                                onTryNow: () => ref
                                    .read(_homeTabProvider.notifier)
                                    .state = 0)
                            : RefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: () async => ref
                                    .read(orderListProvider.notifier)
                                    .fetch(),
                                child: ListView.builder(
                                  padding: EdgeInsets.fromLTRB(16, 12, 16,
                                      32 + BottomNav.reservedHeight(context)),
                                  itemCount: filtered.length +
                                      (state.hasMore && _selectedType == 'all'
                                          ? 1
                                          : 0),
                                  itemBuilder: (_, i) {
                                    if (i == filtered.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Center(
                                          child: state.isLoadingMore
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppColors
                                                              .primary))
                                              : OutlinedButton.icon(
                                                  onPressed: () => ref
                                                      .read(orderListProvider
                                                          .notifier)
                                                      .loadMore(),
                                                  icon: const Icon(
                                                      Icons.expand_more_rounded,
                                                      size: 18),
                                                  label: Text('Xem thêm',
                                                      style: TextStyle(
                                                          fontSize: AppFontSize.body,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.primary,
                                                    side: const BorderSide(
                                                        color:
                                                            AppColors.primary),
                                                  ),
                                                ),
                                        ),
                                      );
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _OrderCard(order: filtered[i]),
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
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 46, color: AppColors.primary.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có đơn hàng nào',
              style: TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy đặt dịch vụ đầu tiên và\ntận hưởng các ưu đãi cực khủng!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onTryNow,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  textStyle:
                      TextStyle(fontSize: AppFontSize.bodyLarge, fontWeight: FontWeight.w600),
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
    if (order.status == 'pending') return AppColors.warning;
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
        'shopping' => AppColors.info,
        'bike' => AppColors.success,
        'motor' => const Color(0xFF8B5CF6),
        'car' => const Color(0xFF06B6D4),
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(order.createdAt);
    } catch (_) {}

    final statusColor = _statusColor();
    // `shipping_fee` từ API đã là tổng tiền sau khi áp dụng voucher.
    // Không trừ `discount_amount` lần nữa, nếu không đơn có voucher sẽ
    // hiển thị thiếu tiền (thường thành 0đ).
    final totalFee = order.shippingFee;
    final pickup = order.pickupAddress ?? order.storeName ?? '—';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/order/${order.code}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _iconColor().withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Fmt.serviceIcon(order.serviceType),
                      size: 21,
                      color: _iconColor(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${Fmt.serviceLabel(order.serviceType)} · #${order.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: order.isCancelled
                            ? const Color(0xFFBEB5B0)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      order.isCancelled && order.cancelReason != null
                          ? order.cancelReason!
                          : pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w500,
                        color: order.isCancelled
                            ? const Color(0xFFBEB5B0)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(color: AppColors.divider),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      createdAt != null ? Fmt.timeAgo(createdAt) : '—',
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  Text(
                    Fmt.currency(totalFee),
                    style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: order.isCancelled
                          ? const Color(0xFFBEB5B0)
                          : AppColors.primary,
                      decoration: order.isCancelled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
