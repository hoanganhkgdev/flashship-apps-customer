import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9DE),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Quay lại',
                      onPressed: () => context.pop(),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: HomeStyle.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: HomeStyle.ink)),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Ưu đãi của bạn',
                            style: TextStyle(
                                fontSize: AppFontSize.title,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink)),
                        SizedBox(height: 3),
                        Text('Sao chép mã, chọn ưu đãi khi đặt đơn',
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                color: HomeStyle.muted)),
                      ])),
                ]),
                const SizedBox(height: 12),
                _VoucherTabs(
                  selected: _tab,
                  onSelected: (value) => setState(() => _tab = value),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: HomeStyle.orange)),
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
                color: HomeStyle.orange,
                onRefresh: () async => ref.invalidate(voucherProvider),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      ]),
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
  Widget build(BuildContext context) => Row(children: [
        for (final entry
            in ['Khả dụng', 'Đã dùng', 'Hết hạn'].asMap().entries) ...[
          if (entry.key > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: entry.key == selected,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(entry.key),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Ink(
                    height: 44 +
                        (MediaQuery.textScalerOf(context).scale(12) - 12)
                                .clamp(0.0, double.infinity) *
                            2,
                    decoration: BoxDecoration(
                      color: entry.key == selected
                          ? HomeStyle.orange
                          : Colors.white.withValues(alpha: .76),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: entry.key == selected
                            ? HomeStyle.orange
                            : const Color(0xFFFFD1BF),
                      ),
                    ),
                    child: Center(
                      child: Text(entry.value,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: entry.key == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: entry.key == selected
                                  ? Colors.white
                                  : HomeStyle.muted)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]);
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
        'percent' => HomeStyle.orange,
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
    final accent = disabled ? HomeStyle.muted : color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: HomeStyle.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
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
                ])),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
            decoration: BoxDecoration(
              color: HomeStyle.cardMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(voucher.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                        color: HomeStyle.ink,
                      ))),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Sao chép mã ưu đãi',
                onPressed: disabled
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: voucher.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Đã sao chép mã ưu đãi')),
                        );
                      },
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(40),
                  backgroundColor: accent.withValues(alpha: .08),
                  disabledBackgroundColor: HomeStyle.cardMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: Icon(Icons.copy_rounded, size: 18, color: accent),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
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
              if (voucher.serviceTypes?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                    'Dịch vụ: ${voucher.serviceTypes!.map(Fmt.serviceLabel).join(', ')}',
                    style: const TextStyle(
                      fontSize: AppFontSize.caption,
                      height: 1.4,
                      color: HomeStyle.muted,
                    )),
              ],
              if ((!disabled && expiringSoon) || voucher.appOnly) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (!disabled && expiringSoon)
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
          const Divider(height: 1, color: HomeStyle.divider),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule_rounded,
                size: 14, color: HomeStyle.muted),
            const SizedBox(width: 5),
            Expanded(
                child: Text(
                    voucher.expiresAt == null
                        ? 'Không giới hạn thời gian'
                        : 'HSD: ${Fmt.date(voucher.expiresAt!)}',
                    style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        color: HomeStyle.muted))),
            const SizedBox(width: 8),
            if (disabled)
              Flexible(
                  child: _StatusChip(
                      label: disabledLabel,
                      color: voucher.isExpired
                          ? AppColors.danger
                          : HomeStyle.muted))
            else
              FilledButton(
                onPressed: onUse,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 44),
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Đặt dịch vụ',
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
        ]),
      ),
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
          borderRadius: BorderRadius.circular(AppRadius.full),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: HomeStyle.peach,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                size: 34, color: HomeStyle.orange),
          ),
          const SizedBox(height: 14),
          Text(
            switch (tab) {
              0 => 'Chưa có ưu đãi khả dụng',
              1 => 'Chưa có ưu đãi đã dùng',
              _ => 'Chưa có ưu đãi hết hạn',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            switch (tab) {
              0 => 'Ưu đãi mới sẽ được cập nhật tại đây.',
              1 => 'Các ưu đãi bạn đã sử dụng sẽ xuất hiện tại đây.',
              _ => 'Các ưu đãi hết hạn sẽ xuất hiện tại đây.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: AppFontSize.body, color: HomeStyle.muted),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: HomeStyle.cardMuted,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: HomeStyle.divider),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 32, color: HomeStyle.muted),
          ),
          const SizedBox(height: 12),
          Text('Không tải được ưu đãi',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600)),
          TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: HomeStyle.orange),
              child: const Text('Thử lại')),
        ]),
      );
}
