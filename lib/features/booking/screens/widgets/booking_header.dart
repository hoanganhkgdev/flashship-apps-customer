import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/liquid_glass.dart';

class BookingHeader extends StatelessWidget {
  final String serviceType;
  final String title;
  final String subtitle;
  final VoidCallback? onPricingTap;

  const BookingHeader({
    super.key,
    required this.serviceType,
    required this.title,
    required this.subtitle,
    this.onPricingTap,
  });

  @override
  Widget build(BuildContext context) {
    final svc = serviceDefOf(serviceType);
    return LiquidGlass(
      borderRadius: BorderRadius.circular(AppRadius.card),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: svc.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: svc.color.withValues(alpha: 0.22)),
            ),
            child: Icon(svc.icon, color: svc.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSize.bodyLarge,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: AppFontSize.body, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (onPricingTap != null)
            InkWell(
              onTap: onPricingTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: svc.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 14, color: svc.color),
                    const SizedBox(width: 4),
                    Text('Bảng giá',
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w600,
                          color: svc.color,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
