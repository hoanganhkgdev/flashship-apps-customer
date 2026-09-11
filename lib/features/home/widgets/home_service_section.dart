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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: LiquidGlass(
        borderRadius: HomeStyle.radius,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                GlassIcon(
                  icon: Icons.grid_view_rounded,
                  color: HomeStyle.orange,
                  size: 34,
                  iconSize: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bạn cần gì hôm nay?',
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Chọn dịch vụ để bắt đầu',
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (services.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: state.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: HomeStyle.orange))
                    : Column(children: [
                        Text(
                            state.hasError
                                ? 'Chưa tải được dịch vụ'
                                : 'Chưa có dịch vụ khả dụng',
                            style: const TextStyle(color: HomeStyle.muted)),
                        if (state.hasError)
                          TextButton(
                              onPressed: () =>
                                  ref.invalidate(serviceTypeProvider),
                              child: const Text('Thử lại')),
                      ]),
              )
            else
              LayoutBuilder(builder: (context, constraints) {
                final width = (constraints.maxWidth - 16) / 3;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final service in services)
                    SizedBox(
                        width: width,
                        child: _ServiceIconItem(
                            svc: service, onTap: () => onTap(service.key))),
                ]);
              }),
          ],
        ),
      ),
    );
  }
}

class _ServiceIconItem extends StatelessWidget {
  final ServiceTypeModel svc;
  final VoidCallback onTap;
  const _ServiceIconItem({required this.svc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.serviceColor(svc.key);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: HomeStyle.radius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          decoration: BoxDecoration(
            borderRadius: HomeStyle.radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .42),
                color.withValues(alpha: .07),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .68)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: svc.iconUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: svc.iconUrl!,
                          fit: BoxFit.contain,
                          placeholder: (_, __) =>
                              _ServiceGlyph(type: svc.key, color: color),
                          errorWidget: (_, __, ___) =>
                              _ServiceGlyph(type: svc.key, color: color))
                      : _ServiceGlyph(type: svc.key, color: color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                svc.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
