part of '../screens/home_screen.dart';

// ── Contact section ───────────────────────────────────────────────────────────

// ── Voucher section ───────────────────────────────────────────────────────────

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  static IconData _typeIcon(String? type) => switch (type) {
        'freeship' => Icons.local_shipping_rounded,
        'percent' => Icons.percent_rounded,
        _ => Icons.card_giftcard_rounded,
      };

  static Color _typeColor(String? type) => switch (type) {
        'freeship' => AppColors.accent2,
        'percent' => AppColors.primary,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchers = ref.watch(voucherProvider).valueOrNull ?? [];
    if (vouchers.isEmpty) return const SizedBox.shrink();
    // Voucher appOnly lên đầu danh sách, giữ nguyên thứ tự tương đối trong mỗi nhóm
    final sorted = [
      ...vouchers.where((v) => v.appOnly),
      ...vouchers.where((v) => !v.appOnly),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.local_offer_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ưu đãi dành cho bạn',
                  style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            GestureDetector(
              onTap: () => context.push('/vouchers'),
              child: const Text('Xem tất cả',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ]),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final v = sorted[i];
              final color = _typeColor(v.type);
              final icon = _typeIcon(v.type);
              final isExpiringSoon = v.expiresAt != null &&
                  v.expiresAt!.difference(DateTime.now()).inDays <= 3;
              return GestureDetector(
                onTap: () => context.push('/vouchers'),
                child: Container(
                  width: 210,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.divider, width: 1),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(icon, size: 16, color: color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(v.discountLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppFontSize.bodyLarge,
                                        fontWeight: FontWeight.w600,
                                        color: color)),
                              ),
                            ]),
                            const Spacer(),
                            if (v.description != null)
                              Text(v.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: AppFontSize.body,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 1,
                              child: CustomPaint(
                                painter: _DashedLinePainter(
                                    color: color.withValues(alpha: 0.35)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: v.code));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Đã sao chép mã ${v.code}')),
                                  );
                                }
                              },
                              child: Row(children: [
                                Expanded(
                                  child: Text(v.code,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: AppFontSize.caption,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                          letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded,
                                    size: 13, color: color),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      if (isExpiringSoon)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.rectangle,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                            ),
                            child: const Text('Sắp hết',
                                style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                      if (v.appOnly)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.rectangle,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                            ),
                            child: const Text('Chỉ có trên app',
                                style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  static const _dashWidth = 4.0;
  static const _dashSpace = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + _dashWidth, 0), paint);
      startX += _dashWidth + _dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
