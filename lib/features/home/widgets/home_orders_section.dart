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
    final active = orders.where((order) => order.isActive).toList()
      ..sort((a, b) {
        int priority(String status) => switch (status) {
              'processing' => 0,
              'assigned' => 1,
              _ => 2,
            };
        return priority(a.status).compareTo(priority(b.status));
      });
    if (active.isEmpty) {
      _rtdbSub?.cancel();
      _subscribedCode = null;
      return const SizedBox.shrink();
    }
    _subscribeRTDB(active.first.code);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeStyle.orangeLight, HomeStyle.orange],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Đơn '),
                        TextSpan(
                          text: 'đang thực hiện',
                          style: TextStyle(color: HomeStyle.orange),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                      color: HomeStyle.ink,
                    ),
                  ),
                  SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.route_rounded,
                          size: 15,
                          color: HomeStyle.orange,
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Theo dõi trạng thái đơn',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            height: 1.25,
                            color: HomeStyle.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${active.length}',
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: HomeStyle.orange,
                ),
              ),
            ),
            if (active.length > 1) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => ref.read(_homeTabProvider.notifier).state = 1,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Xem tất cả'),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          HomeOrderCard(order: active.first),
        ],
      ),
    );
  }
}

class _RecentOrdersSection extends ConsumerWidget {
  const _RecentOrdersSection({required this.onReorder});

  final ValueChanged<OrderModel> onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref
        .watch(orderListProvider)
        .orders
        .where((order) => order.isCompleted)
        .take(2)
        .toList();
    if (completed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeStyle.orangeLight, HomeStyle.orange],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Đặt lại đơn '),
                        TextSpan(
                          text: 'gần đây',
                          style: TextStyle(color: HomeStyle.orange),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                      color: HomeStyle.ink,
                    ),
                  ),
                  SizedBox(height: 5),
                  Row(children: [
                    Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: HomeStyle.orange,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Đặt nhanh từ đơn đã hoàn thành',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          height: 1.25,
                          color: HomeStyle.muted,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: HomeStyle.cardRadius,
              border: Border.all(color: HomeStyle.divider),
              boxShadow: HomeStyle.shadow,
            ),
            child: Column(children: [
              for (var index = 0; index < completed.length; index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: HomeStyle.divider,
                  ),
                _RecentOrderTile(
                  order: completed[index],
                  onTap: () => onReorder(completed[index]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.serviceColor(order.serviceType);
    final pickup = order.pickupAddress?.trim();
    final delivery = order.deliveryAddress?.trim();
    final createdAt = DateTime.tryParse(order.createdAt);
    final timeLabel = createdAt == null ? null : Fmt.timeAgo(createdAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: _ServiceGlyph(
                  type: order.serviceType,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.serviceLabel(order.serviceType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700,
                        color: HomeStyle.ink,
                      ),
                    ),
                    if (timeLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: Text(
                            timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Đặt lại',
                  style: TextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ]),
            if (pickup?.isNotEmpty == true || delivery?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              if (pickup?.isNotEmpty == true)
                Semantics(
                  label: 'Điểm đi',
                  child: _RouteLine(
                    icon: Icons.radio_button_checked_rounded,
                    color: HomeStyle.orange,
                    text: pickup!,
                    maxLines: 2,
                  ),
                ),
              if (pickup?.isNotEmpty == true && delivery?.isNotEmpty == true)
                const SizedBox(height: 7),
              if (delivery?.isNotEmpty == true)
                Semantics(
                  label: 'Điểm đến',
                  child: _RouteLine(
                    icon: Icons.location_on_outlined,
                    color: AppColors.info,
                    text: delivery!,
                    maxLines: 2,
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

class HomeOrderCard extends StatelessWidget {
  const HomeOrderCard({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/order/${order.code}');
    final color = AppColors.serviceColor(order.serviceType);
    final statusColor = switch (order.status) {
      'assigned' => AppColors.info,
      'processing' => AppColors.success,
      _ => HomeStyle.orange,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: open,
        borderRadius: HomeStyle.cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: HomeStyle.cardRadius,
            color: Colors.white,
            border: Border.all(color: HomeStyle.divider),
            boxShadow: HomeStyle.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _ServiceGlyph(
                    type: order.serviceType,
                    color: color,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fmt.serviceLabel(order.serviceType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w800,
                          color: HomeStyle.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '#${order.code}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width < 360 ? 108 : 136,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      Fmt.orderStatus(order.status),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ]),
              if (order.pickupAddress?.trim().isNotEmpty == true ||
                  order.deliveryAddress?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                  decoration: BoxDecoration(
                    color: HomeStyle.cardMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    if (order.pickupAddress?.trim().isNotEmpty == true)
                      _RouteLine(
                        icon: Icons.radio_button_checked_rounded,
                        color: color,
                        text: order.pickupAddress!,
                      ),
                    if (order.pickupAddress?.trim().isNotEmpty == true &&
                        order.deliveryAddress?.trim().isNotEmpty == true)
                      const SizedBox(height: 8),
                    if (order.deliveryAddress?.trim().isNotEmpty == true)
                      _RouteLine(
                        icon: Icons.location_on_rounded,
                        color: AppColors.danger,
                        text: order.deliveryAddress!,
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: HomeStyle.divider),
              const SizedBox(height: 8),
              _ActiveOrderFooter(order: order, color: color, onTrack: open),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderFooter extends StatelessWidget {
  const _ActiveOrderFooter({
    required this.order,
    required this.color,
    required this.onTrack,
  });

  final OrderModel order;
  final Color color;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final driver = switch (order.status) {
      'pending' => 'Đang kết nối tài xế',
      _ when order.driverName?.trim().isNotEmpty == true => order.driverName!,
      'assigned' => 'Tài xế đã nhận đơn',
      _ => Fmt.orderStatus(order.status),
    };
    final compact = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) > 15;
    final driverInfo = Row(children: [
      Icon(Icons.person_rounded, size: 17, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          driver,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w600,
            color: HomeStyle.ink,
          ),
        ),
      ),
    ]);
    final fee = Text(
      Fmt.currency(order.shippingFee),
      maxLines: 1,
      style: const TextStyle(
        fontSize: AppFontSize.body,
        fontWeight: FontWeight.w800,
        color: HomeStyle.ink,
      ),
    );
    final button = TextButton.icon(
      onPressed: onTrack,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: .10),
        minimumSize: Size(compact ? double.infinity : 0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: const Text('Xem chi tiết'),
    );
    if (compact) {
      return Column(children: [
        Row(children: [
          Expanded(child: driverInfo),
          const SizedBox(width: 8),
          fee
        ]),
        const SizedBox(height: 9),
        button,
      ]);
    }
    return Row(children: [
      Expanded(child: driverInfo),
      const SizedBox(width: 10),
      fee,
      const SizedBox(width: 10),
      button,
    ]);
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
    this.maxLines = 1,
  });

  final IconData icon;
  final Color color;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFontSize.caption, color: HomeStyle.muted)),
        ),
      ]);
}
