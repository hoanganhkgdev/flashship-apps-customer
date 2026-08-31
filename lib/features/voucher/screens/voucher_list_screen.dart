import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        title: Text('Ưu đãi của tôi',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(children: [
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
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
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            children:
                ['Khả dụng', 'Đã dùng', 'Hết hạn'].asMap().entries.map((entry) {
              final active = entry.key == selected;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(entry.key),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
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
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(
            width: 88,
            color: accent.withValues(alpha: disabled ? .06 : .09),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(height: 8),
              Text(voucher.discountLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                  8,
                  (_) =>
                      Container(width: 1, height: 4, color: AppColors.divider)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(voucher.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                              color: AppColors.textPrimary)),
                    ),
                    if (expiringSoon)
                      const _StatusChip(
                          label: 'Sắp hết', color: AppColors.danger)
                    else if (voucher.appOnly)
                      const _StatusChip(
                          label: 'Chỉ trên app', color: AppColors.primary),
                  ]),
                  const SizedBox(height: 5),
                  Text(
                    voucher.description?.isNotEmpty == true
                        ? voucher.description!
                        : voucher.minOrderValue != null
                            ? 'Áp dụng cho đơn từ ${Fmt.currency(voucher.minOrderValue!)}'
                            : 'Áp dụng cho dịch vụ Flash Ship',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        height: 1.35,
                        color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: Text(
                        voucher.expiresAt == null
                            ? 'Không giới hạn thời gian'
                            : 'HSD: ${Fmt.date(voucher.expiresAt!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (disabled)
                      _StatusChip(
                        label: disabledLabel,
                        color: voucher.hasBeenUsed
                            ? AppColors.textSecondary
                            : AppColors.danger,
                      )
                    else
                      SizedBox(
                        height: 34,
                        child: FilledButton(
                          onPressed: onUse,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(84, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Dùng ngay'),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
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
          const Icon(Icons.confirmation_number_outlined,
              size: 52, color: Color(0xFFBEB5B0)),
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
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('Không tải được ưu đãi',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600)),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
