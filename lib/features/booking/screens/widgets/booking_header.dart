import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: svc.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: svc.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(svc.icon, color: svc.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppFontSize.bodyLarge,
                      color: svc.color,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: AppFontSize.body, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (onPricingTap != null)
            GestureDetector(
              onTap: onPricingTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: svc.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
