import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/widgets/home_style.dart';

/// Một thẻ hành trình: điểm lấy hàng nối với điểm giao hàng.
class DeliveryRouteCard extends StatelessWidget {
  const DeliveryRouteCard({
    super.key,
    required this.pickupPlaceName,
    required this.pickupAddress,
    required this.destAddress,
    required this.onPickupTap,
    required this.onDestTap,
  });

  final String? pickupPlaceName;
  final String? pickupAddress;
  final String? destAddress;
  final VoidCallback onPickupTap;
  final VoidCallback onDestTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: HomeStyle.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Icon(Icons.alt_route_rounded, size: 19, color: HomeStyle.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Điểm lấy và điểm giao',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w800,
                        color: HomeStyle.ink)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _StopRow(
            icon: Icons.inventory_2_outlined,
            color: HomeStyle.orange,
            label: 'Lấy hàng tại',
            title: _pickupTitle,
            subtitle: _pickupSubtitle,
            placeholder: 'Chọn nơi lấy hàng',
            onTap: onPickupTap,
          ),
          const Divider(
              height: 1, indent: 54, endIndent: 10, color: HomeStyle.divider),
          _StopRow(
            icon: Icons.location_on_outlined,
            color: AppColors.info,
            label: 'Giao hàng đến',
            title: destAddress,
            placeholder: 'Chọn nơi giao hàng',
            onTap: onDestTap,
          ),
        ]),
      ),
    );
  }

  bool get _hasPlace => pickupPlaceName?.trim().isNotEmpty == true;

  String? get _pickupTitle =>
      _hasPlace ? pickupPlaceName!.trim() : pickupAddress;

  String? get _pickupSubtitle => _hasPlace ? pickupAddress : null;
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.label,
    required this.title,
    required this.placeholder,
    required this.onTap,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String? title;
  final String? subtitle;
  final String placeholder;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = title?.trim().isNotEmpty == true;
    return Semantics(
      button: true,
      label: '$label: ${filled ? title : placeholder}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: HomeStyle.muted)),
                      const SizedBox(height: 3),
                      Text(
                        filled ? title! : placeholder,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: filled ? HomeStyle.ink : color,
                        ),
                      ),
                      if (filled && subtitle?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                height: 1.35,
                                color: HomeStyle.muted)),
                      ],
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: HomeStyle.muted),
            ]),
          ),
        ),
      ),
    );
  }
}
