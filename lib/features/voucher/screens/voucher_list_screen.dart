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
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 60,
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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: vouchers.length,
              itemBuilder: (ctx, i) => _VoucherCard(voucher: vouchers[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Voucher card ──────────────────────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  const _VoucherCard({required this.voucher});

  Color get _color => switch (voucher.type) {
    'freeship' => AppColors.info,
    'percent'  => AppColors.success,
    _          => AppColors.primary,
  };

  IconData get _icon => switch (voucher.type) {
    'freeship' => Icons.local_shipping_rounded,
    'percent'  => Icons.percent_rounded,
    _          => Icons.discount_rounded,
  };

  bool get _expiringSoon =>
      voucher.expiresAt != null &&
      voucher.expiresAt!.difference(DateTime.now()).inDays <= 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _copyCode(context),
          child: Column(children: [
            // ── Top: icon + info ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon, color: _color, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges row
                        Row(children: [
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
                                color: AppColors.danger.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Sắp hết hạn',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.danger,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ]),

                        if (voucher.description != null) ...[
                          const SizedBox(height: 5),
                          Text(voucher.description!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],

                        const SizedBox(height: 4),
                        Wrap(spacing: 10, runSpacing: 0, children: [
                          if (voucher.minOrderValue != null)
                            _CondText(
                                'Tối thiểu ${Fmt.currency(voucher.minOrderValue!)}'),
                          if (voucher.expiresAt != null)
                            _CondText('HSD ${Fmt.date(voucher.expiresAt!)}'),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider ───────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),

            // ── Bottom: code + copy ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                Icon(Icons.confirmation_number_outlined,
                    size: 14, color: _color),
                const SizedBox(width: 6),
                Text(voucher.code,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        letterSpacing: 0.8, color: _color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Sao chép',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _color)),
                ),
              ]),
            ),
          ]),
        ),
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

class _CondText extends StatelessWidget {
  final String text;
  const _CondText(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.discount_rounded, size: 40,
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
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.wifi_off_rounded, size: 40,
            color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      const Text('Không tải được ưu đãi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      TextButton(
        onPressed: onRetry,
        child: const Text('Thử lại',
            style: TextStyle(color: AppColors.primary,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}
