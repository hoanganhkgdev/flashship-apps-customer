import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/liquid_glass.dart';

/// Shared glass layout for pickup and destination contact details.
class DeliveryAddressCard extends StatefulWidget {
  const DeliveryAddressCard({
    super.key,
    required this.address,
    required this.placeName,
    required this.nameController,
    required this.phoneController,
    required this.onAddressTap,
    this.isPickup = true,
  });

  final bool isPickup;
  final String? address;
  final String? placeName;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onAddressTap;

  @override
  State<DeliveryAddressCard> createState() => _DeliveryAddressCardState();
}

class _DeliveryAddressCardState extends State<DeliveryAddressCard> {
  bool _editingContact = false;

  void _toggleContact() {
    if (_editingContact) FocusScope.of(context).unfocus();
    setState(() => _editingContact = !_editingContact);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isPickup ? AppColors.primary : AppColors.accent2;
    final hasAddress = widget.address?.trim().isNotEmpty == true;
    // Destination shows the street address; the recipient belongs in contact details.
    final hasPlace =
        widget.isPickup && widget.placeName?.trim().isNotEmpty == true;
    return LiquidGlass(
      borderRadius: BorderRadius.circular(AppRadius.glass),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GlassIcon(
              icon: widget.isPickup
                  ? Icons.storefront_outlined
                  : Icons.flag_outlined,
              color: accent,
              size: 32,
              iconSize: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.isPickup ? 'Điểm lấy hàng' : 'Điểm giao hàng',
                  style: const TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onAddressTap,
              borderRadius: BorderRadius.circular(AppRadius.glass),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAddress
                              ? (hasPlace ? widget.placeName! : widget.address!)
                              : widget.isPickup
                                  ? 'Chọn địa chỉ lấy hàng'
                                  : 'Chọn địa chỉ giao hàng',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w600,
                            color: hasAddress ? AppColors.textPrimary : accent,
                          ),
                        ),
                        if (hasAddress && hasPlace) ...[
                          const SizedBox(height: 4),
                          Text(widget.address!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: AppFontSize.body,
                                  height: 1.4,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(AppRadius.glass),
              border: Border.all(color: Colors.white.withValues(alpha: .65)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleContact,
                borderRadius: BorderRadius.circular(AppRadius.glass),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.nameController,
                          widget.phoneController,
                        ]),
                        builder: (context, _) {
                          final name = widget.nameController.text.trim();
                          final phone = widget.phoneController.text.trim();
                          if (name.isEmpty && phone.isEmpty) {
                            return Text(
                                widget.isPickup
                                    ? 'Thêm tên & SĐT liên hệ'
                                    : 'Thêm tên & SĐT người nhận',
                                style: const TextStyle(
                                    fontSize: AppFontSize.body,
                                    color: AppColors.textSecondary));
                          }
                          return Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (name.isNotEmpty)
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: AppFontSize.body,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                              if (phone.isNotEmpty)
                                Text(name.isNotEmpty ? '· $phone' : phone,
                                    style: const TextStyle(
                                        fontSize: AppFontSize.body,
                                        color: AppColors.textSecondary)),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                        _editingContact
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.edit_outlined,
                        size: 16,
                        color: AppColors.textSecondary),
                  ]),
                ),
              ),
            ),
          ),
          if (_editingContact) ...[
            const SizedBox(height: 16),
            TextField(
              controller: widget.nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: widget.isPickup
                    ? 'Tên điểm lấy (tùy chọn)'
                    : 'Tên người nhận',
                prefixIcon: Icon(
                    widget.isPickup
                        ? Icons.storefront_outlined
                        : Icons.person_outline_rounded,
                    size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _toggleContact(),
              decoration: InputDecoration(
                labelText: widget.isPickup
                    ? 'SĐT liên hệ (tùy chọn)'
                    : 'SĐT người nhận *',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _toggleContact,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Xong'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
