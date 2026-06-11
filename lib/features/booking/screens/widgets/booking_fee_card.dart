import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class BookingFeeCard extends StatelessWidget {
  final String serviceType;
  final int? fee;
  final double? distanceKm;
  final bool loading;
  final int discount;

  const BookingFeeCard({
    super.key,
    required this.serviceType,
    this.fee,
    this.distanceKm,
    this.loading = false,
    this.discount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color      = AppColors.serviceColor(serviceType);
    final finalFee   = fee != null ? (fee! - discount).clamp(0, fee!) : null;
    final hasDiscount = discount > 0 && fee != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phí vận chuyển',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                if (loading)
                  Text('Đang tính...',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 18))
                else if (fee != null) ...[
                  if (hasDiscount)
                    Text(Fmt.currency(fee!),
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.textSecondary)),
                  Text(Fmt.currency(finalFee!),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 20)),
                  if (hasDiscount)
                    Text('Tiết kiệm ${Fmt.currency(discount)}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (distanceKm != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${distanceKm!.toStringAsFixed(1)} km',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
