import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 60,
        title: Text('Điểm thưởng',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              children: [
                // ── Points hero card ───────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Điểm tích lũy',
                                              style: TextStyle(
                                                  color:
                                                      const Color(0xFFFFD5C7),
                                                  fontSize: AppFontSize.body)),
                                          const SizedBox(height: 4),
                                          Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text('$_points',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: AppFontSize.hero,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1)),
                                                const SizedBox(width: 6),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Text('điểm',
                                                      style: TextStyle(
                                                          color: const Color(
                                                              0xFFFFD5C7),
                                                          fontSize: AppFontSize.bodyLarge)),
                                                ),
                                              ]),
                                        ]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.card),
                                    ),
                                    child: Text(_rankLabel(_points),
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: AppFontSize.caption,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                            const SizedBox(height: 14),
                            _RankProgress(points: _points),
                          ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_nextMilestone(),
                              style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: AppColors.textSecondary)),
                        ),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Stats card ────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Row(children: [
                        Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Thống kê đơn hàng',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _StatsRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Tổng đơn',
                        value: '$_totalOrders'),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _StatsRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Hoàn thành',
                        value: '$_completedOrders',
                        valueColor: AppColors.success),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _StatsRow(
                        icon: Icons.cancel_outlined,
                        label: 'Đã huỷ',
                        value: '$_cancelledOrders',
                        valueColor: AppColors.danger),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _StatsRow(
                        icon: Icons.payments_outlined,
                        label: 'Tổng chi tiêu',
                        value: _compactMoney(_totalSpent)),
                    if (_favoriteService != null) ...[
                      const Divider(
                          height: 1, indent: 56, color: AppColors.surfaceAlt),
                      _StatsRow(
                          icon: Icons.favorite_border_rounded,
                          label: 'Dịch vụ hay dùng',
                          value: _serviceLabel(_favoriteService!),
                          valueColor: AppColors.primary),
                    ],
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _StatsRow(
                        icon: Icons.trending_up_rounded,
                        label: 'Tỉ lệ hoàn thành',
                        value: _totalOrders > 0
                            ? '${(_completedOrders / _totalOrders * 100).toStringAsFixed(0)}%'
                            : '—',
                        valueColor: AppColors.success),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── How to earn card ──────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Row(children: [
                        Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Cách tích điểm',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _HowItem(Icons.check_circle_rounded, AppColors.success,
                        '+1 điểm', 'Mỗi đơn hàng hoàn thành'),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _HowItem(Icons.local_offer_rounded, AppColors.primary,
                        'Ưu đãi', 'Nhận voucher theo hạng thành viên'),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.surfaceAlt),
                    _HowItem(
                        Icons.emoji_events_rounded,
                        const Color(0xFFFF9500),
                        'Lên hạng',
                        '5 đơn → Thường xuyên · 20 → Thân thiết · 50 → VIP'),
                  ]),
                ),
              ],
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
    final (current, next, label) = switch (points) {
      < 5 => (0, 5, 'Còn ${5 - points} đơn để lên Thường xuyên'),
      < 20 => (5, 20, 'Còn ${20 - points} đơn để lên Thân thiết'),
      < 50 => (20, 50, 'Còn ${50 - points} đơn để lên VIP'),
      _ => (50, 50, 'Bạn đã đạt hạng cao nhất'),
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
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
      const SizedBox(height: 6),
      Text(label,
          style: TextStyle(color: const Color(0xFFFFD5C7), fontSize: AppFontSize.caption)),
    ]);
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _StatsRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          SizedBox(
              width: 24,
              child: Icon(icon, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: AppFontSize.bodyLarge, color: AppColors.textSecondary))),
          Text(value,
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ]),
      );
}

// ── How item ─────────────────────────────────────────────────────────────────

class _HowItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String badge, text;
  const _HowItem(this.icon, this.color, this.badge, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          SizedBox(width: 24, child: Icon(icon, size: 20, color: color)),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(badge,
                  style: TextStyle(
                      fontSize: AppFontSize.body, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(text,
                  style:
                      TextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );
}
