import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/widgets/home_style.dart';
import 'booking_field_decoration.dart';

/// Phần tùy chọn (ghi chú, tiền ứng trước, thông tin cửa hàng) gập lại cho gọn.
class DeliveryDetailsCard extends StatefulWidget {
  const DeliveryDetailsCard({
    super.key,
    required this.noteController,
    required this.advanceController,
    required this.storeNameController,
    required this.storePhoneController,
    required this.onAdvanceChanged,
  });

  final TextEditingController noteController;
  final TextEditingController advanceController;
  final TextEditingController storeNameController;
  final TextEditingController storePhoneController;
  final ValueChanged<String> onAdvanceChanged;

  @override
  State<DeliveryDetailsCard> createState() => _DeliveryDetailsCardState();
}

class _DeliveryDetailsCardState extends State<DeliveryDetailsCard> {
  late bool _expanded = _hasExtras;

  bool get _hasExtras =>
      widget.noteController.text.trim().isNotEmpty ||
      widget.advanceController.text.trim().isNotEmpty ||
      widget.storeNameController.text.trim().isNotEmpty ||
      widget.storePhoneController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: HomeStyle.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: HomeStyle.peach,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 17, color: HomeStyle.orange),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Thông tin bổ sung',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink)),
                        SizedBox(height: 2),
                        Text('Tùy chọn · Cửa hàng, tiền ứng, ghi chú',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                color: HomeStyle.muted)),
                      ],
                    ),
                  ),
                  Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: HomeStyle.muted),
                ]),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 4),
              TextField(
                controller: widget.noteController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: AppFontSize.bodyLarge, color: HomeStyle.ink),
                decoration: bookingFieldDecoration(
                  label: 'Ghi chú',
                  hint: 'Mô tả hàng, lưu ý khi giao…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.advanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: widget.onAdvanceChanged,
                style: const TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success),
                decoration: bookingFieldDecoration(
                  label: 'Tiền tài xế ứng trước cho shop',
                  hint: '0',
                  suffixText: 'đ',
                  prefixIcon: Icons.payments_outlined,
                  helper:
                      'Tài xế sẽ chuẩn bị số tiền này để trả shop khi lấy hàng',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.storeNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: bookingFieldDecoration(
                  label: 'Tên cửa hàng',
                  hint: 'Nếu có',
                  prefixIcon: Icons.storefront_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.storePhoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: bookingFieldDecoration(
                  label: 'SĐT cửa hàng',
                  hint: 'Nếu có',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
