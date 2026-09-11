import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/utils/formatters.dart';
import '../providers/pricing_provider.dart';

/// Gọi: PricingInfoSheet.show(context, serviceType: 'car')
class PricingInfoSheet extends ConsumerWidget {
  final String serviceType;
  const PricingInfoSheet({super.key, required this.serviceType});

  static void show(BuildContext context, {required String serviceType}) {
    showModalBottomSheet(
      showDragHandle: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PricingInfoSheet(serviceType: serviceType),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pricingForProvider(serviceType));
    final color = AppColors.serviceColor(serviceType);
    final maxH = MediaQuery.of(context).size.height * 0.82;

    return GlassBottomSheet(
      child: Container(
        color: Colors.transparent,
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            _Header(color: color, serviceType: serviceType),
            Flexible(
              child: async.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(
                  height: 80,
                  child: Center(child: Text('Không tải được bảng giá')),
                ),
                data: (cfg) => cfg == null
                    ? const SizedBox(
                        height: 80,
                        child: Center(child: Text('Chưa có bảng giá')),
                      )
                    : _PricingBody(cfg: cfg, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final Color color;
  final String serviceType;
  const _Header({required this.color, required this.serviceType});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          border:
              Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            GlassIcon(
                icon: Fmt.serviceIcon(serviceType),
                color: color,
                size: 40,
                iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.serviceLabel(serviceType),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSize.display,
                        color: AppColors.textPrimary)),
                Text('Bảng giá dịch vụ',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSize.bodyLarge)),
              ],
            )),
            IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20)),
          ],
        ),
      );
}

class _PricingBody extends StatelessWidget {
  final PricingConfig cfg;
  final Color color;
  const _PricingBody({required this.cfg, required this.color});

  @override
  Widget build(BuildContext context) {
    final type = cfg.configJson?['type'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      shrinkWrap: true,
      children: [
        if (type == 'slab') _SlabTable(cfg: cfg, color: color),
        if (type == 'linear') _LinearTable(cfg: cfg, color: color),
        if (type == 'tiered_linear') _TieredLinearTable(cfg: cfg, color: color),
        if (type == 'topup') _TopupTable(cfg: cfg, color: color),
        const SizedBox(height: 16),
        _NoteBox(color: color),
      ],
    );
  }
}

// ── Slab bậc thang (delivery, shopping) ───────────────────────────────────────
class _SlabTable extends StatelessWidget {
  final PricingConfig cfg;
  final Color color;
  const _SlabTable({required this.cfg, required this.color});

  @override
  Widget build(BuildContext context) {
    final slabs =
        (cfg.configJson!['slabs'] as List).cast<Map<String, dynamic>>();
    final overKm = (cfg.configJson!['over_max_per_km'] as num).toInt();
    final lastMax = (slabs.last['max_km'] as num).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Phí theo quãng đường', color),
        const SizedBox(height: 10),
        _TableHeader(left: 'Quãng đường', right: 'Phí'),
        ...slabs.asMap().entries.map((e) {
          final i = e.key;
          final slab = e.value;
          final maxKm = (slab['max_km'] as num).toDouble();
          final fee = (slab['fee'] as num).toInt();
          final prevMax =
              i == 0 ? 0.0 : (slabs[i - 1]['max_km'] as num).toDouble();
          return _TableRow(
            left: i == 0 ? '0 – ${maxKm}km' : '$prevMax – ${maxKm}km',
            right: Fmt.currency(fee),
            highlight: false,
            color: color,
          );
        }),
        _TableRow(
          left: 'Trên ${lastMax}km',
          right: '+ ${Fmt.currency(overKm)}/km',
          highlight: true,
          color: color,
        ),
      ],
    );
  }
}

// ── Tuyến tính đơn giản (motor, car) ──────────────────────────────────────────
class _LinearTable extends StatelessWidget {
  final PricingConfig cfg;
  final Color color;
  const _LinearTable({required this.cfg, required this.color});

  @override
  Widget build(BuildContext context) {
    final baseKm = (cfg.configJson!['base_km'] as num).toInt();
    final baseFee = (cfg.configJson!['base_fee'] as num).toInt();
    final perKm = (cfg.configJson!['per_km_fee'] as num).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Phí theo quãng đường', color),
        const SizedBox(height: 10),
        _TableHeader(left: 'Quãng đường', right: 'Phí'),
        _TableRow(
            left: '0 – ${baseKm}km',
            right: Fmt.currency(baseFee),
            highlight: false,
            color: color),
        _TableRow(
            left: 'Mỗi km tiếp theo',
            right: '+ ${Fmt.currency(perKm)}/km',
            highlight: true,
            color: color),
        const SizedBox(height: 16),
        _ExampleCard(color: color, rows: [
          ('3km', Fmt.currency(baseFee)),
          ('5km', Fmt.currency(baseFee + perKm * 2)),
          ('10km', Fmt.currency(baseFee + perKm * 7)),
        ]),
      ],
    );
  }
}

// ── Tuyến tính 2 bậc (bike) ───────────────────────────────────────────────────
class _TieredLinearTable extends StatelessWidget {
  final PricingConfig cfg;
  final Color color;
  const _TieredLinearTable({required this.cfg, required this.color});

  @override
  Widget build(BuildContext context) {
    final baseKm = (cfg.configJson!['base_km'] as num).toDouble();
    final baseFee = (cfg.configJson!['base_fee'] as num).toInt();
    final perKm = (cfg.configJson!['per_km_fee'] as num).toInt();
    final higherFrom = (cfg.configJson!['higher_from_km'] as num).toDouble();
    final higherPerKm = (cfg.configJson!['higher_per_km_fee'] as num).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Phí theo quãng đường', color),
        const SizedBox(height: 10),
        _TableHeader(left: 'Quãng đường', right: 'Phí'),
        _TableRow(
            left: '0 – ${baseKm.toInt()}km',
            right: Fmt.currency(baseFee),
            highlight: false,
            color: color),
        _TableRow(
            left: '${baseKm.toInt()} – ${higherFrom.toInt()}km',
            right: '+ ${Fmt.currency(perKm)}/km',
            highlight: false,
            color: color),
        _TableRow(
            left: 'Trên ${higherFrom.toInt()}km',
            right: '+ ${Fmt.currency(higherPerKm)}/km',
            highlight: true,
            color: color), // ignore: unnecessary_brace_in_string_interps
      ],
    );
  }
}

// ── Nạp tiền (topup) ──────────────────────────────────────────────────────────
class _TopupTable extends StatelessWidget {
  final PricingConfig cfg;
  final Color color;
  const _TopupTable({required this.cfg, required this.color});

  @override
  Widget build(BuildContext context) {
    final tiers =
        (cfg.configJson!['tiers'] as List).cast<Map<String, dynamic>>();
    final perUnit = (cfg.configJson!['over_max_per_unit'] as num).toInt();
    final step = (cfg.configJson!['over_max_fee_step'] as num).toInt();
    final lastAmount = (tiers.last['max_amount'] as num).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Phí theo số tiền nạp', color),
        const SizedBox(height: 10),
        _TableHeader(left: 'Số tiền nạp', right: 'Phí'),
        ...tiers.asMap().entries.map((e) {
          final i = e.key;
          final tier = e.value;
          final maxAmount = (tier['max_amount'] as num).toInt();
          final fee = (tier['fee'] as num).toInt();
          final prevAmount =
              i == 0 ? 0 : (tiers[i - 1]['max_amount'] as num).toInt();
          return _TableRow(
            left: i == 0
                ? 'Dưới ${Fmt.shortAmount(maxAmount)}'
                : '${Fmt.shortAmount(prevAmount)} – ${Fmt.shortAmount(maxAmount)}',
            right: Fmt.currency(fee),
            highlight: false,
            color: color,
          );
        }),
        _TableRow(
          left:
              'Trên ${Fmt.shortAmount(lastAmount)}\n(mỗi ${Fmt.shortAmount(perUnit)})',
          right: '+ ${Fmt.currency(step)}',
          highlight: true,
          color: color,
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, this.color);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppFontSize.bodyLarge,
            color: color),
      );
}

class _TableHeader extends StatelessWidget {
  final String left, right;
  const _TableHeader({required this.left, required this.right});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
        child: Row(
          children: [
            Expanded(
                child: Text(left.toUpperCase(),
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600))),
            Text(right.toUpperCase(),
                style: TextStyle(
                    fontSize: AppFontSize.caption,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _TableRow extends StatelessWidget {
  final String left, right;
  final bool highlight;
  final Color color;
  const _TableRow(
      {required this.left,
      required this.right,
      required this.highlight,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              highlight ? color.withValues(alpha: 0.055) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: highlight
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(left,
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight:
                            highlight ? FontWeight.w600 : FontWeight.w600,
                        color: AppColors.textPrimary))),
            Text(right,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: highlight ? color : AppColors.textPrimary)),
          ],
        ),
      );
}

class _ExampleCard extends StatelessWidget {
  final Color color;
  final List<(String, String)> rows;
  const _ExampleCard({required this.color, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ví dụ tính phí',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSize.caption,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(r.$1,
                          style: const TextStyle(
                              fontSize: AppFontSize.body, color: Colors.grey)),
                      const Spacer(),
                      Text(r.$2,
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                )),
          ],
        ),
      );
}

class _NoteBox extends StatelessWidget {
  final Color color;
  const _NoteBox({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Phí được tính theo khoảng cách đường thực tế. '
                'Giá cuối cùng hiển thị khi bạn chọn điểm đến.',
                style: TextStyle(
                    fontSize: AppFontSize.body,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}
