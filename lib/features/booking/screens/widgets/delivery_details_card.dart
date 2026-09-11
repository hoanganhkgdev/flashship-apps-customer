import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/liquid_glass.dart';

class DeliveryDetailsCard extends StatelessWidget {
  const DeliveryDetailsCard({
    super.key,
    required this.noteController,
    required this.advanceController,
    required this.selectedCargo,
    required this.cargoTypes,
    required this.onAdvanceChanged,
    required this.onCargoSelected,
  });

  final TextEditingController noteController;
  final TextEditingController advanceController;
  final String selectedCargo;
  final List<(String, String, IconData)> cargoTypes;
  final ValueChanged<String> onAdvanceChanged;
  final ValueChanged<String> onCargoSelected;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(AppRadius.glass),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const GlassIcon(
              icon: Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 32,
              iconSize: 18,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Chi tiết đơn hàng',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('Loại hàng',
              style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 0; index < cargoTypes.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    selected: cargoTypes[index].$1 == selectedCargo,
                    child: IconButton(
                      tooltip: cargoTypes[index].$2,
                      onPressed: () => onCargoSelected(cargoTypes[index].$1),
                      icon: Icon(cargoTypes[index].$3, size: 24),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 52),
                        foregroundColor: cargoTypes[index].$1 == selectedCargo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        backgroundColor: cargoTypes[index].$1 == selectedCargo
                            ? AppColors.primary.withValues(alpha: .12)
                            : Colors.white.withValues(alpha: .28),
                        side: BorderSide(
                          color: cargoTypes[index].$1 == selectedCargo
                              ? AppColors.primary.withValues(alpha: .5)
                              : Colors.white.withValues(alpha: .7),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                fontSize: AppFontSize.bodyLarge, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tùy chọn)',
              hintText: 'Mô tả hàng, lưu ý khi giao…',
              alignLabelWithHint: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: advanceController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onAdvanceChanged,
            style: const TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.success),
            decoration: const InputDecoration(
              labelText: 'Tiền trả shop (tùy chọn)',
              hintText: '0',
              suffixText: 'đ',
              prefixIcon: Icon(Icons.payments_outlined,
                  size: 20, color: AppColors.success),
              helperText: 'Để tài xế chuẩn bị tiền trả shop khi lấy hàng',
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
