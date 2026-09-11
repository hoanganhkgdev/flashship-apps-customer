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
    final visibleOrders = active.take(2).toList();
    final remainingCount = active.length - visibleOrders.length;
    _subscribeRTDB(active.first.code);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LiquidGlass(
          borderRadius: HomeStyle.radius,
          padding: const EdgeInsets.all(4),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(children: [
                const GlassIcon(
                  icon: Icons.local_shipping_rounded,
                  color: HomeStyle.orange,
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    const Flexible(
                      child: Text(
                        'Đơn đang thực hiện',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: HomeStyle.orange.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(AppRadius.glass),
                      ),
                      child: Text('${active.length}',
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w700,
                              color: HomeStyle.orange)),
                    ),
                  ]),
                ),
                if (active.length > 1) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(_homeTabProvider.notifier).state = 1,
                    style: TextButton.styleFrom(
                      foregroundColor: HomeStyle.orange,
                      backgroundColor: HomeStyle.orange.withValues(alpha: .08),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.glass)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Xem tất cả',
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 17),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < visibleOrders.length; index++) ...[
              if (index > 0)
                const Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: HomeStyle.divider),
              HomeOrderCard(order: visibleOrders[index], compact: index > 0),
            ],
            if (remainingCount > 0)
              TextButton(
                onPressed: () => ref.read(_homeTabProvider.notifier).state = 1,
                child: Text('Còn $remainingCount đơn khác'),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class HomeOrderCard extends StatelessWidget {
  const HomeOrderCard({
    super.key,
    required this.order,
    this.compact = false,
  });
  final OrderModel order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/order/${order.code}');
    final color = AppColors.serviceColor(order.serviceType);
    final address = order.deliveryAddress ?? order.pickupAddress;
    if (compact) {
      return _CompactActiveOrder(
          order: order, color: color, address: address, onTap: open);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: HomeStyle.radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .60),
                      color.withValues(alpha: .12),
                    ],
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .80)),
                ),
                child: _ServiceGlyph(
                    type: order.serviceType, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${Fmt.serviceLabel(order.serviceType)} · ${Fmt.orderStatus(order.status)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.ink)),
                    const SizedBox(height: 3),
                    Text('#${order.code}',
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted)),
                  ])),
              const SizedBox(width: 8),
              GlassIcon(
                icon: Icons.arrow_forward_rounded,
                color: color,
                size: 36,
                iconSize: 18,
              ),
            ]),
            const SizedBox(height: 12),
            _OrderProgress(status: order.status, color: color),
            const SizedBox(height: 5),
            const Row(children: [
              Text('Đã nhận',
                  style: TextStyle(fontSize: 10, color: HomeStyle.muted)),
              Spacer(),
              Text('Đang lấy',
                  style: TextStyle(fontSize: 10, color: HomeStyle.muted)),
              Spacer(),
              Text('Đang giao',
                  style: TextStyle(fontSize: 10, color: HomeStyle.muted)),
            ]),
            if (order.pickupAddress?.trim().isNotEmpty == true ||
                order.deliveryAddress?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .65)),
                ),
                child: Column(children: [
                  if (order.pickupAddress?.trim().isNotEmpty == true)
                    _RouteLine(
                        icon: Icons.radio_button_checked_rounded,
                        color: color,
                        text: order.pickupAddress!),
                  if (order.pickupAddress?.trim().isNotEmpty == true &&
                      order.deliveryAddress?.trim().isNotEmpty == true)
                    const SizedBox(height: 7),
                  if (order.deliveryAddress?.trim().isNotEmpty == true)
                    _RouteLine(
                        icon: Icons.location_on_rounded,
                        color: AppColors.danger,
                        text: order.deliveryAddress!),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CompactActiveOrder extends StatelessWidget {
  const _CompactActiveOrder({
    required this.order,
    required this.color,
    required this.address,
    required this.onTap,
  });

  final OrderModel order;
  final Color color;
  final String? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              GlassIcon(
                icon: Fmt.serviceIcon(order.serviceType),
                color: color,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            '${Fmt.serviceLabel(order.serviceType)} · ${Fmt.orderStatus(order.status)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.ink)),
                      ),
                      Text('#${order.code}',
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ]),
                    if (address?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: HomeStyle.muted),
            ]),
          ),
        ),
      );
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFontSize.caption, color: HomeStyle.muted)),
        ),
      ]);
}

/// Milestones represent actual order status, not elapsed time or distance.
class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final step = switch (status) { 'assigned' => 1, 'processing' => 2, _ => 0 };
    return Semantics(
      label: Fmt.orderStatus(status),
      child: Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: index == step ? 12 : 9,
              height: index == step ? 12 : 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index <= step ? color : color.withValues(alpha: .16),
                border: Border.all(
                  color: index <= step
                      ? Colors.white.withValues(alpha: .9)
                      : color.withValues(alpha: .20),
                  width: 1.5,
                ),
                boxShadow: index == step
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .30),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            if (index < 2)
              Expanded(
                child: Container(
                  height: 2,
                  color: index < step ? color : color.withValues(alpha: .14),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
