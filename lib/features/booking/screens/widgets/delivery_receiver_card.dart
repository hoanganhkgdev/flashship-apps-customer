import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/widgets/home_style.dart';
import 'booking_field_decoration.dart';

/// Người nhận luôn hiện sẵn; SĐT là bắt buộc nên báo thiếu ngay khi rời ô.
class DeliveryReceiverCard extends StatefulWidget {
  const DeliveryReceiverCard({
    super.key,
    required this.nameController,
    required this.phoneController,
    this.showPhoneError = false,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;

  /// Cha bật khi người dùng bấm Đặt mà chưa có SĐT.
  final bool showPhoneError;

  @override
  State<DeliveryReceiverCard> createState() => _DeliveryReceiverCardState();
}

class _DeliveryReceiverCardState extends State<DeliveryReceiverCard> {
  final _phoneFocus = FocusNode();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus && !_touched) {
        setState(() => _touched = true);
      }
    });
    widget.phoneController.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_onChanged);
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.phoneController.text.trim().isEmpty;
    final showError = empty && (_touched || widget.showPhoneError);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: HomeStyle.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 18, color: HomeStyle.orange),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Người nhận hàng',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.ink)),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: widget.nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: bookingFieldDecoration(
                label: 'Tên người nhận', hint: 'Nguyễn Văn A'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: bookingFieldDecoration(
              label: 'Số điện thoại người nhận *',
              hint: '0912 345 678',
              errorText: showError ? 'Nhập SĐT để tài xế liên hệ' : null,
            ),
          ),
        ]),
      ),
    );
  }
}
