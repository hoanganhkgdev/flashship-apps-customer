import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';

class VoucherListScreen extends ConsumerWidget {
  const VoucherListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voucherProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ưu đãi của bạn',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2)),
        error: (_, __) => _ErrorState(onRetry: () => ref.refresh(voucherProvider)),
        data: (vouchers) {
          if (vouchers.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(voucherProvider),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                Container(
                  color: Colors.white,
                  child: Column(
                    children: vouchers.asMap().entries.map((e) {
                      final i = e.key;
                      return Column(children: [
                        _VoucherRow(voucher: e.value),
                        if (i < vouchers.length - 1)
                          const Divider(height: 1, indent: 60,
                              color: Color(0xFFF5F5F5)),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Voucher row (Grab-style flat) ──────────────────────────────────────────────

class _VoucherRow extends StatelessWidget {
  final VoucherModel voucher;
  const _VoucherRow({required this.voucher});

  Color get _color => switch (voucher.type) {
    'freeship' => AppColors.info,
    'percent'  => AppColors.success,
    _          => AppColors.primary,
  };

  IconData get _icon => switch (voucher.type) {
    'freeship' => Icons.local_shipping_outlined,
    'percent'  => Icons.percent_rounded,
    _          => Icons.discount_outlined,
  };

  bool get _expiringSoon =>
      voucher.expiresAt != null &&
      voucher.expiresAt!.difference(DateTime.now()).inDays <= 3;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copyCode(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Icon
          SizedBox(width: 28,
              child: Icon(_icon, size: 24, color: _color)),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // Discount badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(voucher.discountLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (_expiringSoon) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Sắp hết hạn',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.danger,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                if (voucher.description != null)
                  Text(voucher.description!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  if (voucher.minOrderValue != null)
                    _Tag('Tối thiểu ${Fmt.currency(voucher.minOrderValue!)}'),
                  if (voucher.expiresAt != null)
                    _Tag('HSD: ${Fmt.date(voucher.expiresAt!)}'),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Code + copy
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(voucher.code,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      letterSpacing: 0.5, color: _color)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, size: 11,
                    color: AppColors.textSecondary),
                const SizedBox(width: 2),
                const Text('Sao chép',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ],
          ),
        ]),
      ),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: voucher.code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã sao chép mã ${voucher.code}'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.success,
    ));
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle),
        child: const Icon(Icons.discount_outlined, size: 38,
            color: AppColors.primary),
      ),
      const SizedBox(height: 16),
      const Text('Chưa có ưu đãi nào',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Ưu đãi mới sẽ xuất hiện tại đây',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 48,
          color: AppColors.textSecondary),
      const SizedBox(height: 12),
      const Text('Không tải được ưu đãi',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );
}
