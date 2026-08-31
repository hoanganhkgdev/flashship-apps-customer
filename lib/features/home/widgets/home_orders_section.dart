part of '../screens/home_screen.dart';

class _ActiveOrdersOverview extends ConsumerStatefulWidget {
  const _ActiveOrdersOverview();

  @override
  ConsumerState<_ActiveOrdersOverview> createState() =>
      _ActiveOrdersOverviewState();
}

class _ActiveOrdersOverviewState extends ConsumerState<_ActiveOrdersOverview> {
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
    _rtdbSub =
        FirebaseDatabase.instance.ref('orders/$code').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) {
        ref.read(orderListProvider.notifier).fetch();
        return;
      }
      final map = Map<String, dynamic>.from(data as Map);
      final status = map['status'] as String?;
      if (status == null) return;
      final orders = ref.read(orderListProvider).orders;
      final order = orders.where((o) => o.code == code).firstOrNull;
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

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderListProvider).orders;
    final active = orders.where((order) => order.isActive).toList();
    if (active.isEmpty) {
      _rtdbSub?.cancel();
      _subscribedCode = null;
      return const SizedBox.shrink();
    }
    final visibleOrders = active.take(3).toList();
    _subscribeRTDB(active.first.code);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đơn đang hoạt động',
                  style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.infoSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${active.length}',
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final order in visibleOrders) ...[
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: InkWell(
                onTap: () => context.push('/order/${order.code}'),
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${order.code}',
                              style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE5DC),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Text(
                              Fmt.orderStatus(order.status),
                              style: TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
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
                              order.deliveryAddress ??
                                  order.pickupAddress ??
                                  'Đang cập nhật địa chỉ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
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
                              '${Fmt.serviceLabel(order.serviceType)} · ${order.paymentMethod == 'cod' ? 'COD ${Fmt.currency(order.codAmount ?? 0)}' : 'Đã thanh toán'}',
                              style: TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.currency(order.shippingFee),
                            style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (order != visibleOrders.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(_homeTabProvider.notifier).state = 1,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.divider),
                backgroundColor: AppColors.surface,
              ),
              label: Text(
                'Xem tất cả đơn hàng',
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}
