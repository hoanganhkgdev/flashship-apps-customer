import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RideNoteScreen extends StatefulWidget {
  final String serviceType;
  final String initialNote;
  const RideNoteScreen(
      {super.key, required this.serviceType, required this.initialNote});

  @override
  State<RideNoteScreen> createState() => _State();
}

class _State extends State<RideNoteScreen> {
  late final TextEditingController _ctrl;

  bool get _isBike => widget.serviceType == 'bike';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(context, _ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final title = _isBike ? 'Ghi chú cho tài xế' : 'Thông tin xe';
    final hint  = _isBike
        ? 'Hướng dẫn đón, yêu cầu đặc biệt... (tuỳ chọn)'
        : 'Loại xe, màu sắc, biển số... (tuỳ chọn)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isBike ? 'Ghi chú' : 'Thông tin xe',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Xong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: TextField(
              controller: _ctrl,
              maxLines: 6,
              autofocus: true,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: title,
                labelStyle: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                floatingLabelStyle: const TextStyle(
                    fontSize: 13, color: AppColors.primary,
                    fontWeight: FontWeight.w500),
                hintText: hint,
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400),
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
