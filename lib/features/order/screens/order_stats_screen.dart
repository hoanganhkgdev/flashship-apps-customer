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
  bool    _loading         = true;
  int     _totalOrders     = 0;
  int     _completedOrders = 0;
  int     _cancelledOrders = 0;
  int     _totalSpent      = 0;
  String? _favoriteService;
  int     _points          = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ref.read(apiClientProvider)
          .get('/customer/orders', params: {'per_page': 200});
      final data   = res.data['data'] as List? ?? [];
      final orders = data.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();

      final completed = orders.where((o) => o.isCompleted).toList();
      final spent     = completed.fold<int>(0, (s, o) => s + o.shippingFee.toInt());

      final typeCounts = <String, int>{};
      for (final o in completed) {
        typeCounts[o.serviceType] = (typeCounts[o.serviceType] ?? 0) + 1;
      }
      final favEntry = typeCounts.entries.isEmpty ? null
          : typeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);

      if (mounted) {
        setState(() {
          _totalOrders     = orders.length;
          _completedOrders = completed.length;
          _cancelledOrders = orders.where((o) => o.isCancelled).length;
          _totalSpent      = spent;
          _favoriteService = favEntry?.key;
          _points          = completed.length;
          _loading         = false;
        });
      }
    } catch (_) {
      final orders    = ref.read(orderListProvider).orders;
      final completed = orders.where((o) => o.isCompleted).toList();
      if (mounted) {
        setState(() {
          _totalOrders     = orders.length;
          _completedOrders = completed.length;
          _cancelledOrders = orders.where((o) => o.isCancelled).length;
          _totalSpent      = completed.fold(0, (s, o) => s + o.shippingFee.toInt());
          _points          = completed.length;
          _loading         = false;
        });
      }
    }
  }

  String _serviceLabel(String type) => switch (type) {
    'delivery' => 'Lấy hộ',
    'shopping' => 'Mua hộ',
    'topup'    => 'Nạp tiền',
    'bike'     => 'Xe ôm',
    'motor'    => 'Lái xe máy',
    'car'      => 'Lái xe hơi',
    _          => type,
  };

  String _rankLabel(int pts) {
    if (pts >= 50) return 'Khách VIP';
    if (pts >= 20) return 'Thân thiết';
    if (pts >= 5)  return 'Thường xuyên';
    return 'Thành viên mới';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Điểm thưởng',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2))
          : ListView(
              padding: EdgeInsets.zero,
              children: [

                // ── Points header ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8720C), Color(0xFFFF9A3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Điểm tích lũy',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$_points',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 56,
                              fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('điểm',
                            style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_rankLabel(_points),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _RankProgress(points: _points),
                  ]),
                ),

                const SizedBox(height: 8),

                // ── Section header: Thống kê ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(children: [
                    Container(width: 4, height: 18,
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text('Thống kê',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ]),
                ),
                Container(
                  color: Colors.white,
                  child: Column(children: [
                    _StatsRow(icon: Icons.receipt_long_outlined,
                        label: 'Tổng đơn', value: '$_totalOrders'),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                    _StatsRow(icon: Icons.check_circle_outline_rounded,
                        label: 'Hoàn thành', value: '$_completedOrders',
                        valueColor: AppColors.success),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                    _StatsRow(icon: Icons.cancel_outlined,
                        label: 'Đã huỷ', value: '$_cancelledOrders',
                        valueColor: AppColors.danger),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                    _StatsRow(icon: Icons.payments_outlined,
                        label: 'Tổng chi tiêu',
                        value: Fmt.currency(_totalSpent)),
                    if (_favoriteService != null) ...[
                      const Divider(height: 1, indent: 56,
                          color: Color(0xFFF5F5F5)),
                      _StatsRow(icon: Icons.favorite_border_rounded,
                          label: 'Dịch vụ hay dùng',
                          value: _serviceLabel(_favoriteService!),
                          valueColor: AppColors.primary),
                    ],
                    const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                    _StatsRow(icon: Icons.trending_up_rounded,
                        label: 'Tỉ lệ hoàn thành',
                        value: _totalOrders > 0
                            ? '${(_completedOrders / _totalOrders * 100).toStringAsFixed(0)}%'
                            : '—',
                        valueColor: AppColors.success),
                  ]),
                ),

                const SizedBox(height: 8),

                // ── Section header: Cách tích điểm ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(children: [
                    Container(width: 4, height: 18,
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text('Cách tích điểm',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ]),
                ),
                Container(
                  color: Colors.white,
                  child: Column(children: [
                    _HowItem(Icons.check_circle_rounded, AppColors.success,
                        '+1 điểm', 'Mỗi đơn hoàn thành'),
                    const Divider(height: 1, indent: 56,
                        color: Color(0xFFF5F5F5)),
                    _HowItem(Icons.local_offer_rounded, AppColors.primary,
                        'Ưu đãi', 'Nhận voucher theo hạng thành viên'),
                    const Divider(height: 1, indent: 56,
                        color: Color(0xFFF5F5F5)),
                    _HowItem(Icons.emoji_events_rounded, const Color(0xFFFF9500),
                        'Lên hạng',
                        '5 đơn → Thường xuyên · 20 → Thân thiết · 50 → VIP'),
                  ]),
                ),

                const SizedBox(height: 48),
              ],
            ),
    );
  }
}

// ── Rank progress bar ─────────────────────────────────────────────────────────

class _RankProgress extends StatelessWidget {
  final int points;
  const _RankProgress({required this.points});

  @override
  Widget build(BuildContext context) {
    final (current, next, label) = switch (points) {
      < 5  => (0, 5,   'Còn ${5 - points} đơn để lên Thường xuyên'),
      < 20 => (5, 20,  'Còn ${20 - points} đơn để lên Thân thiết'),
      < 50 => (20, 50, 'Còn ${50 - points} đơn để lên VIP'),
      _    => (50, 50, 'Bạn đã đạt hạng cao nhất'),
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
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _StatsRow({required this.icon, required this.label,
      required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      SizedBox(width: 24,
          child: Icon(icon, size: 20, color: AppColors.textSecondary)),
      const SizedBox(width: 16),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
      Text(value, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
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
      SizedBox(width: 24,
          child: Icon(icon, size: 20, color: color)),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(badge, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    ]),
  );
}
