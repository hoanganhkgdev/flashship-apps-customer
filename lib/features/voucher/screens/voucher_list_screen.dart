import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../home/widgets/home_style.dart';
import '../../../core/utils/formatters.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';

class VoucherListScreen extends ConsumerStatefulWidget {
  const VoucherListScreen({super.key});

  @override
  ConsumerState<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends ConsumerState<VoucherListScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(voucherProvider);
    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(children: [
              IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => context.pop(),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .45),
                      shape: RoundedRectangleBorder(
                          borderRadius: HomeStyle.radius)),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Ưu đãi của bạn',
                        style: TextStyle(
                            fontSize: AppFontSize.display,
                            fontWeight: FontWeight.w800,
                            color: HomeStyle.ink)),
                    SizedBox(height: 4),
                    Text('Chọn ưu đãi cho đơn hàng tiếp theo',
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted)),
                  ])),
            ]),
          ),
          _VoucherTabs(
            selected: _tab,
            onSelected: (value) => setState(() => _tab = value),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) =>
                  _ErrorState(onRetry: () => ref.invalidate(voucherProvider)),
              data: (all) {
                final vouchers = switch (_tab) {
                  0 => all.where((v) => v.isAvailable).toList(),
                  1 => all.where((v) => v.hasBeenUsed).toList(),
                  _ => all.where((v) => v.isExpired).toList(),
                };
                if (vouchers.isEmpty) return _EmptyState(tab: _tab);
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(voucherProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: vouchers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _VoucherCard(
                      voucher: vouchers[index],
                      disabled: _tab != 0,
                      disabledLabel:
                          _tab == 1 ? vouchers[index].usageLabel : 'Hết hạn',
                      onUse: () => _useVoucher(context, vouchers[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ])),
      ),
    );
  }

  void _useVoucher(BuildContext context, VoucherModel voucher) {
    final types = voucher.serviceTypes ?? const <String>[];
    if (types.length == 1) {
      final type = types.first;
      if (type == 'delivery') {
        context.push('/booking/delivery');
      } else if (type == 'shopping') {
        context.push('/booking/shopping');
      } else if (type == 'topup') {
        context.push('/booking/topup');
      } else {
        context.push('/booking/$type');
      }
      return;
    }
    context.go('/home');
  }
}

class _VoucherTabs extends StatelessWidget {
  const _VoucherTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          child: Row(
            children:
                ['Khả dụng', 'Đã dùng', 'Hết hạn'].asMap().entries.map((entry) {
              final active = entry.key == selected;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(entry.key),
                  borderRadius: BorderRadius.circular(AppRadius.glass),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? HomeStyle.orange.withValues(alpha: .14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.glass),
                      border:
                          active ? Border.all(color: AppColors.divider) : null,
                    ),
                    child: Text(entry.value,
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? AppColors.primary
                                : AppColors.textSecondary)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.disabled,
    required this.disabledLabel,
    required this.onUse,
  });
  final VoucherModel voucher;
  final bool disabled;
  final String disabledLabel;
  final VoidCallback onUse;

  Color get color => switch (voucher.type) {
        'freeship' => AppColors.accent2,
        'percent' => AppColors.primary,
        _ => AppColors.success,
      };
  IconData get icon => switch (voucher.type) {
        'freeship' => Icons.local_shipping_outlined,
        'percent' => Icons.percent_rounded,
        _ => Icons.card_giftcard_rounded,
      };
  bool get expiringSoon =>
      voucher.expiresAt != null &&
      voucher.expiresAt!.isAfter(DateTime.now()) &&
      voucher.expiresAt!.difference(DateTime.now()).inDays <= 3;

  @override
  Widget build(BuildContext context) {
    final accent = disabled ? AppColors.textSecondary : color;
    return LiquidGlass(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GlassIcon(icon: icon, color: accent, size: 42, iconSize: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(voucher.discountLabel,
                    style: TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        color: accent)),
                const SizedBox(height: 3),
                Text(voucher.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                        color: HomeStyle.ink)),
              ])),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .35),
              borderRadius: HomeStyle.radius,
              border: Border.all(color: Colors.white.withValues(alpha: .65))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                voucher.description?.isNotEmpty == true
                    ? voucher.description!
                    : 'Áp dụng cho dịch vụ Flash Ship',
                style: const TextStyle(
                    fontSize: AppFontSize.body,
                    height: 1.4,
                    color: HomeStyle.ink)),
            if (voucher.minOrderValue != null ||
                voucher.maxDiscount != null) ...[
              const SizedBox(height: 5),
              Text(
                  [
                    if (voucher.minOrderValue != null)
                      'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}',
                    if (voucher.maxDiscount != null)
                      'Giảm tối đa ${Fmt.currency(voucher.maxDiscount!)}',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: AppFontSize.caption, color: HomeStyle.muted)),
            ],
            if (expiringSoon || voucher.appOnly) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (expiringSoon)
                  const _StatusChip(
                      label: 'Sắp hết hạn', color: AppColors.danger),
                if (voucher.appOnly)
                  const _StatusChip(
                      label: 'Chỉ trên app', color: HomeStyle.orange),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 14, color: HomeStyle.muted),
          const SizedBox(width: 5),
          Expanded(
              child: Text(
                  voucher.expiresAt == null
                      ? 'Không giới hạn thời gian'
                      : 'HSD: ${Fmt.date(voucher.expiresAt!)}',
                  style: const TextStyle(
                      fontSize: AppFontSize.caption, color: HomeStyle.muted))),
          const SizedBox(width: 8),
          if (disabled)
            Flexible(
                child: _StatusChip(
                    label: disabledLabel,
                    color:
                        voucher.isExpired ? AppColors.danger : HomeStyle.muted))
          else
            FilledButton(
              onPressed: onUse,
              style: FilledButton.styleFrom(
                minimumSize: const Size(84, 40),
                backgroundColor: accent.withValues(alpha: .13),
                foregroundColor: accent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: HomeStyle.radius,
                    side: BorderSide(color: accent.withValues(alpha: .18))),
              ),
              child: const Text('Dùng ngay',
                  style: TextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.glass),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const GlassIcon(
              icon: Icons.confirmation_number_outlined,
              size: 72,
              iconSize: 34,
              color: HomeStyle.orange),
          const SizedBox(height: 14),
          Text(
            switch (tab) {
              0 => 'Chưa có ưu đãi khả dụng',
              1 => 'Chưa có ưu đãi đã dùng',
              _ => 'Chưa có ưu đãi hết hạn',
            },
            style: TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const GlassIcon(
              icon: Icons.wifi_off_rounded,
              size: 64,
              iconSize: 28,
              color: HomeStyle.muted),
          const SizedBox(height: 12),
          Text('Không tải được ưu đãi',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600)),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
