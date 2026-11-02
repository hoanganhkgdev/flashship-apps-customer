import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../home/widgets/home_style.dart';

class DeliveryVoucherCard extends StatelessWidget {
  const DeliveryVoucherCard({
    super.key,
    required this.code,
    required this.discount,
    required this.onTap,
    required this.onRemove,
  });

  final String? code;
  final int discount;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final applied = code?.isNotEmpty == true;
    final enabled = onTap != null;
    final accent = !enabled
        ? AppColors.textTertiary
        : applied
            ? AppColors.success
            : HomeStyle.orange;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: applied
            ? AppColors.success.withValues(alpha: .035)
            : HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: applied
              ? AppColors.success.withValues(alpha: .28)
              : HomeStyle.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.local_offer_outlined,
                        size: 20, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applied ? code! : 'Ưu đãi giao hàng',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: !enabled
                                    ? AppColors.textTertiary
                                    : applied
                                        ? accent
                                        : AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          !enabled
                              ? 'Có giá cước mới chọn được ưu đãi'
                              : applied
                                  ? discount > 0
                                      ? 'Giảm ${Fmt.currency(discount)} · Đổi mã'
                                      : 'Đã chọn · Đổi mã'
                                  : 'Chọn hoặc nhập mã giảm giá',
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              color:
                                  applied ? accent : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!applied && enabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ],
                ]),
              ),
            ),
          ),
          if (applied)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: 'Bỏ mã giảm giá',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
        ]),
      ),
    );
  }
}
