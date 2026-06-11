import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ShoppingStopDetailResult {
  final String description;
  const ShoppingStopDetailResult({required this.description});
}

class ShoppingStopDetailScreen extends StatefulWidget {
  final int stopIndex;
  final String description;

  const ShoppingStopDetailScreen({
    super.key,
    required this.stopIndex,
    this.description = '',
  });

  @override
  State<ShoppingStopDetailScreen> createState() => _State();
}

class _State extends State<ShoppingStopDetailScreen> {
  late final _descCtrl = TextEditingController(text: widget.description);
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập mô tả hàng cần mua');
      return;
    }
    Navigator.of(context).pop(ShoppingStopDetailResult(
      description: _descCtrl.text.trim(),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Điểm mua ${widget.stopIndex + 1}',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
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
              const Text('Mô tả hàng cần mua',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _descCtrl,
                  maxLines: 6,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Mô tả hàng cần mua *',
                    labelStyle: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                    floatingLabelStyle: const TextStyle(
                        fontSize: 13, color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                    hintText: 'Tên món, số lượng, yêu cầu...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: _error != null
                        ? AppColors.danger.withValues(alpha: 0.04)
                        : const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: _error != null
                            ? BorderSide(
                                color: AppColors.danger.withValues(alpha: 0.5))
                            : BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    errorText: _error,
                    errorStyle: const TextStyle(
                        fontSize: 12, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
