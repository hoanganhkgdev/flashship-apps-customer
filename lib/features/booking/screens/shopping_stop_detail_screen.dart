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
        title: Text(
          'Điểm mua ${widget.stopIndex + 1}',
          style: const TextStyle(
              fontSize: AppFontSize.display,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
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

          // Section header
          Padding(
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
              const Text('Mô tả hàng cần mua',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
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
                      fontSize: AppFontSize.bodyLarge,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Mô tả hàng cần mua *',
                    labelStyle: const TextStyle(
                        fontSize: AppFontSize.bodyLarge, color: AppColors.textSecondary),
                    floatingLabelStyle: const TextStyle(
                        fontSize: AppFontSize.body,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                    hintText: 'Tên món, số lượng, yêu cầu...',
                    hintStyle: const TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400),
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    errorText: _error,
                    errorStyle:
                        const TextStyle(fontSize: AppFontSize.caption, color: AppColors.danger),
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
