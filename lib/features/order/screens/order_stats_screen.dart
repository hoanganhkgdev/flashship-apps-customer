import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../home/widgets/home_style.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class OrderStatsScreen extends ConsumerStatefulWidget {
  const OrderStatsScreen({super.key});

  @override
  ConsumerState<OrderStatsScreen> createState() => _State();
}

class _State extends ConsumerState<OrderStatsScreen> {
  bool _loading = true;
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  int _totalSpent = 0;
  String? _favoriteService;
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/customer/orders', params: {'per_page': 200});
      final body = res.data;
      final raw = body is List
          ? body
          : body is Map
              ? body['data']
              : null;
      final data = raw is List ? raw : const <dynamic>[];
      final orders = data
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final completed = orders.where((o) => o.isCompleted).toList();
      final spent = completed.fold<int>(0, (s, o) => s + o.shippingFee.toInt());

      final typeCounts = <String, int>{};
      for (final o in completed) {
        typeCounts[o.serviceType] = (typeCounts[o.serviceType] ?? 0) + 1;
      }
      final favEntry = typeCounts.entries.isEmpty
          ? null
          : typeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);

      if (mounted) {
        setState(() {
          _totalOrders = orders.length;
          _completedOrders = completed.length;
          _cancelledOrders = orders.where((o) => o.isCancelled).length;
          _totalSpent = spent;
          _favoriteService = favEntry?.key;
          _points = completed.length;
          _loading = false;
        });
      }
    } catch (_) {
      final orders = ref.read(orderListProvider).orders;
      final completed = orders.where((o) => o.isCompleted).toList();
      if (mounted) {
        setState(() {
          _totalOrders = orders.length;
          _completedOrders = completed.length;
          _cancelledOrders = orders.where((o) => o.isCancelled).length;
          _totalSpent = completed.fold(0, (s, o) => s + o.shippingFee.toInt());
          _points = completed.length;
          _loading = false;
        });
      }
    }
  }

  String _serviceLabel(String type) => switch (type) {
        'delivery' => 'Giao hàng',
        'shopping' => 'Mua hộ',
        'topup' => 'Nạp thẻ',
        'bike' => 'Xe ôm',
        'motor' => 'Lái xe máy',
        'car' => 'Lái xe hơi',
        _ => type,
      };

  String _rankLabel(int pts) {
    if (pts >= 50) return 'Khách VIP';
    if (pts >= 20) return 'Thân thiết';
    if (pts >= 5) return 'Thường xuyên';
    return 'Thành viên mới';
  }

  @override
  Widget build(BuildContext context) {
    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .45),
                    side: BorderSide(color: Colors.white.withValues(alpha: .8)),
                    shape:
                        RoundedRectangleBorder(borderRadius: HomeStyle.radius),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Điểm thưởng',
                          style: TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      SizedBox(height: 4),
                      Text('Tích điểm qua mỗi đơn hoàn thành',
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ])),
              ]),
            ),
            Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                    : RefreshIndicator(
                        onRefresh: _loadStats,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          children: [
                            // ── Points hero card ───────────────────────────────────────
                            LiquidGlass(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const GlassIcon(
                                        icon: Icons.stars_rounded,
                                        color: HomeStyle.orange,
                                        size: 36,
                                        iconSize: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                        child: Text('Điểm tích lũy',
                                            style: TextStyle(
                                                fontSize: AppFontSize.bodyLarge,
                                                fontWeight: FontWeight.w700,
                                                color: HomeStyle.ink))),
                                  ]),
                                  const SizedBox(height: 16),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                            child: Text.rich(
                                          TextSpan(children: [
                                            TextSpan(
                                                text: '$_points',
                                                style: const TextStyle(
                                                    fontSize: 44,
                                                    height: 1.1,
                                                    fontWeight: FontWeight.w800,
                                                    color: HomeStyle.orange)),
                                            const TextSpan(
                                                text: ' điểm',
                                                style: TextStyle(
                                                    fontSize: AppFontSize.body,
                                                    color: HomeStyle.muted)),
                                          ]),
                                        )),
                                        const SizedBox(width: 12),
                                        Flexible(
                                            child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: HomeStyle.orange
                                                  .withValues(alpha: .09),
                                              borderRadius: HomeStyle.radius,
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: .8)),
                                            ),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .workspace_premium_rounded,
                                                      size: 18,
                                                      color: HomeStyle.orange),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                      child: Text(
                                                          _rankLabel(_points),
                                                          style: const TextStyle(
                                                              fontSize:
                                                                  AppFontSize
                                                                      .caption,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: HomeStyle
                                                                  .orange))),
                                                ]),
                                          ),
                                        )),
                                      ]),
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: .35),
                                      borderRadius: HomeStyle.radius,
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: .65)),
                                    ),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_nextMilestone(),
                                              style: const TextStyle(
                                                  fontSize: AppFontSize.caption,
                                                  fontWeight: FontWeight.w600,
                                                  color: HomeStyle.ink)),
                                          const SizedBox(height: 10),
                                          _RankProgress(points: _points),
                                          const SizedBox(height: 12),
                                          Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (final milestone in [
                                                  5,
                                                  20,
                                                  50
                                                ]) ...[
                                                  if (milestone != 5)
                                                    const SizedBox(width: 8),
                                                  Expanded(
                                                      child: Column(children: [
                                                    Icon(
                                                        _points >= milestone
                                                            ? Icons
                                                                .check_circle_rounded
                                                            : Icons
                                                                .radio_button_unchecked_rounded,
                                                        size: 16,
                                                        color: _points >=
                                                                milestone
                                                            ? HomeStyle.orange
                                                            : HomeStyle.muted),
                                                    const SizedBox(height: 5),
                                                    Text('$milestone điểm',
                                                        style: TextStyle(
                                                            fontSize:
                                                                AppFontSize
                                                                    .caption,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: _points >=
                                                                    milestone
                                                                ? HomeStyle
                                                                    .orange
                                                                : HomeStyle
                                                                    .ink)),
                                                    const SizedBox(height: 2),
                                                    Text(_rankLabel(milestone),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize:
                                                                AppFontSize
                                                                    .caption,
                                                            color: HomeStyle
                                                                .muted)),
                                                  ])),
                                                ],
                                              ]),
                                        ]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ── Stats card ────────────────────────────────────────────
                            LiquidGlass(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(children: [
                                      GlassIcon(
                                          icon: Icons.bar_chart_rounded,
                                          color: HomeStyle.orange,
                                          size: 36,
                                          iconSize: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                          child: Text('Thống kê đơn hàng',
                                              style: TextStyle(
                                                  fontSize:
                                                      AppFontSize.bodyLarge,
                                                  fontWeight: FontWeight.w700,
                                                  color: HomeStyle.ink))),
                                    ]),
                                    const SizedBox(height: 14),
                                    IntrinsicHeight(
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                          Expanded(
                                              child: _OrderMetric(
                                                  label: 'Tổng đơn',
                                                  value: _totalOrders,
                                                  icon: Icons
                                                      .receipt_long_rounded,
                                                  color: HomeStyle.orange)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: _OrderMetric(
                                                  label: 'Hoàn thành',
                                                  value: _completedOrders,
                                                  icon: Icons
                                                      .check_circle_outline_rounded,
                                                  color: AppColors.success)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: _OrderMetric(
                                                  label: 'Đã hủy',
                                                  value: _cancelledOrders,
                                                  icon: Icons.cancel_outlined,
                                                  color: AppColors.danger)),
                                        ])),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: HomeStyle.orange
                                            .withValues(alpha: .07),
                                        borderRadius: HomeStyle.radius,
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: .75)),
                                      ),
                                      child: Row(children: [
                                        const GlassIcon(
                                            icon: Icons.payments_outlined,
                                            color: HomeStyle.orange,
                                            size: 36,
                                            iconSize: 19),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              const Text('Tổng chi tiêu',
                                                  style: TextStyle(
                                                      fontSize:
                                                          AppFontSize.caption,
                                                      color: HomeStyle.muted)),
                                              const SizedBox(height: 3),
                                              Text(_compactMoney(_totalSpent),
                                                  style: const TextStyle(
                                                      fontSize:
                                                          AppFontSize.title,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: HomeStyle.orange)),
                                            ])),
                                      ]),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(children: [
                                      const Expanded(
                                          child: Text('Tỉ lệ hoàn thành',
                                              style: TextStyle(
                                                  fontSize: AppFontSize.caption,
                                                  color: HomeStyle.muted))),
                                      Text(
                                          _totalOrders > 0
                                              ? '${(_completedOrders / _totalOrders * 100).toStringAsFixed(0)}%'
                                              : '—',
                                          style: const TextStyle(
                                              fontSize: AppFontSize.body,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success)),
                                    ]),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                        borderRadius: HomeStyle.radius,
                                        child: LinearProgressIndicator(
                                          value: _totalOrders > 0
                                              ? (_completedOrders /
                                                      _totalOrders)
                                                  .clamp(0.0, 1.0)
                                              : 0,
                                          minHeight: 5,
                                          color: AppColors.success,
                                          backgroundColor: AppColors.success
                                              .withValues(alpha: .1),
                                        )),
                                    if (_favoriteService != null) ...[
                                      const SizedBox(height: 14),
                                      Row(children: [
                                        const Icon(
                                            Icons.favorite_border_rounded,
                                            size: 16,
                                            color: HomeStyle.orange),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                            child: Text('Dịch vụ hay dùng',
                                                style: TextStyle(
                                                    fontSize:
                                                        AppFontSize.caption,
                                                    color: HomeStyle.muted))),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: Text(
                                                _serviceLabel(
                                                    _favoriteService!),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    fontSize:
                                                        AppFontSize.caption,
                                                    fontWeight: FontWeight.w600,
                                                    color: HomeStyle.ink))),
                                      ]),
                                    ],
                                  ]),
                            ),
                            const SizedBox(height: 12),

                            // ── How to earn card ──────────────────────────────────────
                            LiquidGlass(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(children: [
                                      GlassIcon(
                                          icon: Icons.auto_awesome_rounded,
                                          color: HomeStyle.orange,
                                          size: 36,
                                          iconSize: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                          child: Text('Cách tích điểm',
                                              style: TextStyle(
                                                  fontSize:
                                                      AppFontSize.bodyLarge,
                                                  fontWeight: FontWeight.w700,
                                                  color: HomeStyle.ink))),
                                    ]),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: .07),
                                        borderRadius: HomeStyle.radius,
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: .75)),
                                      ),
                                      child: Row(children: [
                                        const GlassIcon(
                                            icon: Icons
                                                .check_circle_outline_rounded,
                                            color: AppColors.success,
                                            size: 34,
                                            iconSize: 18),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                            child: Text('Mỗi đơn hoàn thành',
                                                style: TextStyle(
                                                    fontSize: AppFontSize.body,
                                                    fontWeight: FontWeight.w600,
                                                    color: HomeStyle.ink))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withValues(alpha: .12),
                                              borderRadius: HomeStyle.radius),
                                          child: const Text('+1 điểm',
                                              style: TextStyle(
                                                  fontSize: AppFontSize.body,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.success)),
                                        ),
                                      ]),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text('Các mốc lên hạng',
                                        style: TextStyle(
                                            fontSize: AppFontSize.body,
                                            fontWeight: FontWeight.w600,
                                            color: HomeStyle.ink)),
                                    const SizedBox(height: 10),
                                    IntrinsicHeight(
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                          for (final milestone in [
                                            5,
                                            20,
                                            50
                                          ]) ...[
                                            if (milestone != 5)
                                              const SizedBox(width: 8),
                                            Expanded(
                                                child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: .35),
                                                borderRadius: HomeStyle.radius,
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: .7)),
                                              ),
                                              child: Column(children: [
                                                Text('$milestone điểm',
                                                    style: const TextStyle(
                                                        fontSize:
                                                            AppFontSize.body,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            HomeStyle.orange)),
                                                const SizedBox(height: 4),
                                                Text(_rankLabel(milestone),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize:
                                                            AppFontSize.caption,
                                                        color:
                                                            HomeStyle.muted)),
                                              ]),
                                            )),
                                          ],
                                        ])),
                                    const SizedBox(height: 14),
                                    const Row(children: [
                                      GlassIcon(
                                          icon: Icons.local_offer_outlined,
                                          color: HomeStyle.orange,
                                          size: 30,
                                          iconSize: 16),
                                      SizedBox(width: 10),
                                      Expanded(
                                          child: Text(
                                              'Nhận voucher theo hạng thành viên',
                                              style: TextStyle(
                                                  fontSize: AppFontSize.caption,
                                                  height: 1.4,
                                                  color: HomeStyle.muted))),
                                    ]),
                                  ]),
                            ),
                          ],
                        ),
                      )),
          ]),
        ),
      ),
    );
  }

  String _nextMilestone() {
    if (_points >= 50) return 'Bạn đã đạt hạng cao nhất — Khách VIP!';
    if (_points >= 20) return 'Còn ${50 - _points} đơn để lên hạng Khách VIP';
    if (_points >= 5) return 'Còn ${20 - _points} đơn để lên hạng Thân thiết';
    return 'Còn ${5 - _points} đơn để lên hạng Thường xuyên';
  }

  String _compactMoney(int value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      final text = millions == millions.roundToDouble()
          ? millions.toStringAsFixed(0)
          : millions.toStringAsFixed(1).replaceAll('.', ',');
      return '${text}tr đ';
    }
    return Fmt.currency(value);
  }
}

// ── Rank progress bar ─────────────────────────────────────────────────────────

class _RankProgress extends StatelessWidget {
  final int points;
  const _RankProgress({required this.points});

  @override
  Widget build(BuildContext context) {
    final (current, next) = switch (points) {
      < 5 => (0, 5),
      < 20 => (5, 20),
      < 50 => (20, 50),
      _ => (50, 50),
    };

    final progress = next > current
        ? ((points - current) / (next - current)).clamp(0.0, 1.0)
        : 1.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: HomeStyle.orange.withValues(alpha: .12),
          valueColor: const AlwaysStoppedAnimation<Color>(HomeStyle.orange),
        ),
      ),
    ]);
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _OrderMetric extends StatelessWidget {
  const _OrderMetric(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .35),
          borderRadius: HomeStyle.radius,
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
        ),
        child: Column(children: [
          GlassIcon(icon: icon, color: color, size: 30, iconSize: 16),
          const SizedBox(height: 8),
          Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.caption, color: HomeStyle.muted)),
        ]),
      );
}
