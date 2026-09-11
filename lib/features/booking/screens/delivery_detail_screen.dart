import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryDetailResult {
  final String storeName;
  final String storePhone;
  final String deliveryPhone;
  final String note;

  const DeliveryDetailResult({
    required this.storeName,
    required this.storePhone,
    required this.deliveryPhone,
    required this.note,
  });
}

class DeliveryDetailScreen extends StatefulWidget {
  final String storeName;
  final String storePhone;
  final String deliveryPhone;
  final String note;

  const DeliveryDetailScreen({
    super.key,
    this.storeName = '',
    this.storePhone = '',
    this.deliveryPhone = '',
    this.note = '',
  });

  @override
  State<DeliveryDetailScreen> createState() => _State();
}

class _State extends State<DeliveryDetailScreen> {
  late final _nameCtrl = TextEditingController(text: widget.storeName);
  late final _storeCtrl = TextEditingController(text: widget.storePhone);
  late final _deliveryCtrl = TextEditingController(text: widget.deliveryPhone);
  late final _noteCtrl = TextEditingController(text: widget.note);

  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storeCtrl.dispose();
    _deliveryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_deliveryCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại người nhận');
      return;
    }
    Navigator.of(context).pop(DeliveryDetailResult(
      storeName: _nameCtrl.text.trim(),
      storePhone: _storeCtrl.text.trim(),
      deliveryPhone: _deliveryCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 60,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        title: const Text('Thông tin đơn hàng',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Xong',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),

          // ── Cửa hàng ─────────────────────────────────────────────────
          _SectionHeader(title: 'Điểm lấy'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: [
              _Field(
                controller: _nameCtrl,
                label: 'Tên điểm lấy',
                hint: 'VD: Bún bò Huế (tuỳ chọn)',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _storeCtrl,
                label: 'SĐT điểm lấy',
                hint: 'Tuỳ chọn',
                keyboardType: TextInputType.phone,
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Người nhận ────────────────────────────────────────────────
          _SectionHeader(title: 'Người nhận'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _Field(
              controller: _deliveryCtrl,
              label: 'SĐT người nhận *',
              hint: 'Bắt buộc',
              keyboardType: TextInputType.phone,
              error: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Ghi chú ───────────────────────────────────────────────────
          _SectionHeader(title: 'Ghi chú / Mô tả hàng'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _Field(
              controller: _noteCtrl,
              label: 'Ghi chú',
              hint: 'Loại hàng, số lượng, yêu cầu đặc biệt...',
              maxLines: 4,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ]),
      );
}

// ── Field ─────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? error;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
          fontSize: AppFontSize.bodyLarge,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: AppFontSize.bodyLarge, color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
            fontSize: AppFontSize.body,
            color: AppColors.primary,
            fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: AppFontSize.bodyLarge,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400),
        alignLabelWithHint: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        errorText: error,
        errorStyle: const TextStyle(fontSize: AppFontSize.caption, color: AppColors.danger),
      ),
    );
  }
}
