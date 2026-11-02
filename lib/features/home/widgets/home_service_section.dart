part of '../screens/home_screen.dart';

class _ServiceIconGrid extends ConsumerWidget {
  final void Function(String type) onTap;
  const _ServiceIconGrid({super.key, required this.onTap});

  static const _order = [
    'delivery',
    'shopping',
    'bike',
    'motor',
    'car',
    'topup'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceTypeProvider);
    final services = [...?state.valueOrNull];
    // Only rearrange the existing API items; never fabricate unavailable services.
    services.sort((a, b) {
      final ai = _order.indexOf(a.key);
      final bi = _order.indexOf(b.key);
      return (ai < 0 ? _order.length : ai)
          .compareTo(bi < 0 ? _order.length : bi);
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(text: 'Bạn cần gì '),
                          TextSpan(
                            text: 'hôm nay?',
                            style: TextStyle(color: HomeStyle.orange),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.25,
                        color: HomeStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: HomeStyle.orange,
                          ),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Chọn dịch vụ, đặt ngay',
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
            ],
          ),
          const SizedBox(height: 14),
          if (services.isEmpty && state.isLoading)
            const _ServiceGridSkeleton()
          else if (services.isEmpty)
            _ServiceEmptyState(
              hasError: state.hasError,
              onRetry: () => ref.invalidate(serviceTypeProvider),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              const spacing = 10.0;
              final columns = constraints.maxWidth < 328 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? 2
                  : 3;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(spacing: spacing, runSpacing: 10, children: [
                for (final service in services)
                  SizedBox(
                    width: width,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _ServiceIconItem(
                        svc: service,
                        onTap: () => onTap(service.key),
                      ),
                    ),
                  ),
              ]);
            }),
        ],
      ),
    );
  }
}

class _ServiceGridSkeleton extends StatelessWidget {
  const _ServiceGridSkeleton();

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth < 328 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 2
            : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: List.generate(
            6,
            (_) => SizedBox(
              width: width,
              height: width,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeStyle.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: HomeStyle.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF3),
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFF3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: 42,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
}

class _ServiceEmptyState extends StatelessWidget {
  const _ServiceEmptyState({
    required this.hasError,
    required this.onRetry,
  });

  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: HomeStyle.cardRadius,
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Row(children: [
          const GlassIcon(
            icon: Icons.cloud_off_outlined,
            color: HomeStyle.muted,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasError ? 'Chưa tải được dịch vụ' : 'Chưa có dịch vụ khả dụng',
              style: const TextStyle(
                fontSize: AppFontSize.body,
                color: HomeStyle.muted,
              ),
            ),
          ),
          if (hasError)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}

class _ServiceIconItem extends StatefulWidget {
  final ServiceTypeModel svc;
  final VoidCallback onTap;
  const _ServiceIconItem({required this.svc, required this.onTap});

  @override
  State<_ServiceIconItem> createState() => _ServiceIconItemState();
}

class _ServiceIconItemState extends State<_ServiceIconItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.svc;
    final color = AppColors.serviceColor(service.key);
    return Semantics(
      button: true,
      label: 'Đặt dịch vụ ${service.label}',
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (_pressed != value) setState(() => _pressed = value);
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Ink(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: _pressed ? color.withValues(alpha: .07) : HomeStyle.card,
                border: Border.all(
                  color: _pressed
                      ? color.withValues(alpha: .28)
                      : HomeStyle.divider,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: SizedBox.square(
                              dimension: 72,
                              child: service.iconUrl?.isNotEmpty == true
                                  ? CachedNetworkImage(
                                      imageUrl: service.iconUrl!,
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) => _ServiceGlyph(
                                          type: service.key, color: color),
                                      errorWidget: (_, __, ___) =>
                                          _ServiceGlyph(
                                              type: service.key, color: color),
                                    )
                                  : _ServiceGlyph(
                                      type: service.key, color: color),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: ExcludeSemantics(
                            child: Text(
                              service.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: AppFontSize.caption,
                                height: 1.16,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: ExcludeSemantics(
                            child: Text(
                              _serviceDescription(service.key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                color: HomeStyle.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _serviceDescription(String type) => switch (type) {
      'delivery' => 'Giao tận nơi',
      'shopping' => 'Mua giúp bạn',
      'bike' => 'Đặt chuyến đi',
      'motor' => 'Lái xe giúp bạn',
      'car' => 'An tâm về nhà',
      'topup' => 'Giao dịch nhanh',
      _ => 'Đặt ngay hôm nay',
    };

/// Icon 3D minh hoạ theo từng loại dịch vụ — dùng chung cho lưới dịch vụ và
/// card đơn đang thực hiện. Rơi về icon Material phẳng khi chưa có ảnh 3D
/// cho loại dịch vụ đó (tránh vỡ layout khi backend thêm dịch vụ mới).
class _ServiceGlyph extends StatelessWidget {
  const _ServiceGlyph(
      {required this.type, required this.color, this.size = 26});
  final String type;
  final Color color;
  final double size;

  static const _assets = {
    'delivery': 'assets/images/home_v2_delivery.png',
    'shopping': 'assets/images/home_v2_shopping.png',
    'bike': 'assets/images/home_v2_bike.png',
    'motor': 'assets/images/home_v2_motor.png',
    'car': 'assets/images/home_v2_car.png',
    'topup': 'assets/images/home_v2_topup.png',
  };

  static IconData _fallbackIcon(String type) => switch (type) {
        'shopping' => Icons.shopping_bag_rounded,
        'bike' => Icons.pedal_bike_rounded,
        'motor' => Icons.two_wheeler_rounded,
        'car' => Icons.directions_car_filled_rounded,
        'topup' => Icons.account_balance_wallet_rounded,
        _ => Icons.local_shipping_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[type];
    if (asset == null) {
      return Icon(_fallbackIcon(type), color: color, size: size);
    }
    return Image.asset(asset, fit: BoxFit.contain, excludeFromSemantics: true);
  }
}
