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
    final filtered = byStatus.where((order) {
      if (query.isEmpty) return true;
      return order.code.toLowerCase().contains(query) ||
          (order.pickupAddress?.toLowerCase().contains(query) ?? false) ||
          (order.deliveryAddress?.toLowerCase().contains(query) ?? false) ||
          Fmt.serviceLabel(order.serviceType).toLowerCase().contains(query);
    }).toList();

    return LiquidBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header + Filter ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Lịch sử đơn',
                          style: TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
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
                            backgroundColor:
                                Colors.white.withValues(alpha: .45),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: .8)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.glass),
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
                          fillColor: Colors.white.withValues(alpha: .45),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Theo dõi hành trình và xem lại các đơn của bạn',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted),
                    ),
                    const SizedBox(height: 16),
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
                                    ? AppColors.primary.withValues(alpha: .16)
                                    : Colors.white.withValues(alpha: .42),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: .3)
                                      : Colors.white.withValues(alpha: .8),
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
                                            ? AppColors.primary
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
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () async =>
                                ref.read(orderListProvider.notifier).fetch(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(16, 12, 16,
                                  32 + BottomNav.reservedHeight(context)),
                              itemCount:
                                  (filtered.isEmpty ? 1 : filtered.length) +
                                      (state.hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (filtered.isEmpty && i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 32),
                                    child: _HistoryEmpty(
                                      isFiltered: query.isNotEmpty ||
                                          _selectedType != 'all',
                                      onTryNow: () => ref
                                          .read(_homeTabProvider.notifier)
                                          .state = 0,
                                    ),
                                  );
                                }
                                if (i ==
                                    (filtered.isEmpty ? 1 : filtered.length)) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Center(
                                      child: state.isLoadingMore
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary))
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
                                                      fontSize:
                                                          AppFontSize.body,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primary,
                                                side: const BorderSide(
                                                    color: AppColors.primary),
                                              ),
                                            ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
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
  final bool isFiltered;
  const _HistoryEmpty({required this.onTryNow, this.isFiltered = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlassIcon(
                icon: Icons.receipt_long_rounded,
                color: HomeStyle.orange,
                size: 72,
                iconSize: 34),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'Không có đơn phù hợp' : 'Chưa có đơn hàng nào',
              style: TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Thử đổi trạng thái hoặc từ khóa tìm kiếm.'
                  : 'Các đơn bạn đặt sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFontSize.body,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
            const SizedBox(height: 28),
            if (!isFiltered)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: onTryNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    textStyle: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600),
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

    return LiquidGlass(
      borderRadius: HomeStyle.radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/order/${order.code}'),
          borderRadius: HomeStyle.radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GlassIcon(
                    icon: Fmt.serviceIcon(order.serviceType),
                    color: _iconColor(),
                    size: 42,
                    iconSize: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('#${order.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w700,
                              color: HomeStyle.ink)),
                      const SizedBox(height: 4),
                      Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text:
                                    '${Fmt.serviceLabel(order.serviceType)} · ',
                                style: const TextStyle(color: HomeStyle.muted)),
                            TextSpan(
                                text: _statusLabel(),
                                style: TextStyle(color: statusColor)),
                          ]),
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600)),
                    ])),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: HomeStyle.muted, size: 20),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .35),
                  borderRadius: HomeStyle.radius,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .65)),
                ),
                child: Column(children: [
                  _addressRow(Icons.radio_button_checked_rounded,
                      HomeStyle.orange, 'Điểm lấy', pickup),
                  if (order.deliveryAddress?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    _addressRow(Icons.location_on_rounded, AppColors.info,
                        'Điểm giao', order.deliveryAddress!),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: HomeStyle.muted),
                const SizedBox(width: 5),
                Expanded(
                    child: Text(
                        createdAt != null ? Fmt.timeAgo(createdAt) : '—',
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted))),
                const SizedBox(width: 8),
                Text(Fmt.currency(totalFee),
                    style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w800,
                      color: order.isCancelled
                          ? HomeStyle.muted
                          : HomeStyle.orange,
                      decoration: order.isCancelled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String label, String address) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: AppFontSize.caption, color: HomeStyle.muted)),
        const SizedBox(height: 2),
        Text(address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: AppFontSize.body,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: HomeStyle.ink)),
      ])),
    ]);
  }
}
