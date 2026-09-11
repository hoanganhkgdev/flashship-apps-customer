import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../../core/utils/formatters.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';
import '../providers/voucher_validation_provider.dart';

class VoucherPickResult {
  final String code;
  final int discount;
  const VoucherPickResult({required this.code, required this.discount});
}

class VoucherPickerScreen extends ConsumerStatefulWidget {
  final String serviceType;
  final int? orderFee;
  final String? appliedCode;

  const VoucherPickerScreen({
    super.key,
    required this.serviceType,
    this.orderFee,
    this.appliedCode,
  });

  @override
  ConsumerState<VoucherPickerScreen> createState() => _State();
}

class _State extends ConsumerState<VoucherPickerScreen> {
  final _ctrl = TextEditingController();
  bool _applying = false;
  String? _error;
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.appliedCode;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _applyCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty || _applying) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final result = await ref.read(voucherValidationServiceProvider).validate(
            code: normalizedCode,
            serviceType: widget.serviceType,
            orderFee: widget.orderFee ?? 0,
          );
      if (!mounted) return;
      Navigator.pop(
          context,
          VoucherPickResult(
            code: result.code,
            discount: result.discount,
          ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, 'Mã không hợp lệ');
        _applying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final voucherAsync = ref.watch(voucherProvider);
    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(children: [
                LiquidGlass(
                  child: IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chọn ưu đãi',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      SizedBox(height: 3),
                      Text('Tiết kiệm hơn cho đơn này',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  LiquidGlass(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bạn có mã ưu đãi?',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                            controller: _ctrl,
                            enabled: !_applying,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Nhập mã ưu đãi',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.25),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 15),
                              border: const GlassInputBorder(),
                              enabledBorder: const GlassInputBorder(),
                              focusedBorder: const GlassInputBorder(
                                  borderSide: BorderSide(
                                      color: AppColors.primary, width: 1.5)),
                            ),
                            onChanged: (_) => setState(() => _error = null),
                            onSubmitted: _applyCode,
                          )),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _applying || _ctrl.text.trim().isEmpty
                                ? null
                                : () => _applyCode(_ctrl.text),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(84, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _applying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Áp dụng'),
                          ),
                        ]),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.danger)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Ưu đãi cho đơn này',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Chạm vào ưu đãi để áp dụng',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  voucherAsync.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => LiquidGlass(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        const Text('Chưa tải được ưu đãi'),
                        TextButton(
                            onPressed: () => ref.invalidate(voucherProvider),
                            child: const Text('Thử lại')),
                      ]),
                    ),
                    data: (vouchers) {
                      final applicable = vouchers
                          .where((v) =>
                              v.isAvailable &&
                              (v.serviceTypes == null ||
                                  v.serviceTypes!.contains(widget.serviceType)))
                          .toList();
                      if (applicable.isEmpty) return const _EmptyState();
                      return Column(
                          children: applicable
                              .map((v) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _VoucherCard(
                                      voucher: v,
                                      isSelected: _selectedCode == v.code,
                                      orderFee: widget.orderFee ?? 0,
                                      onTap: _applying
                                          ? null
                                          : () => _applyCode(v.code),
                                    ),
                                  ))
                              .toList());
                    },
                  ),
                  if (_selectedCode != null)
                    TextButton.icon(
                      onPressed: _applying
                          ? null
                          : () => Navigator.pop(context,
                              const VoucherPickResult(code: '', discount: 0)),
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 18),
                      label: const Text('Bỏ ưu đãi đang áp dụng'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final bool isSelected;
  final int orderFee;
  final VoidCallback? onTap;

  const _VoucherCard({
    required this.voucher,
    required this.isSelected,
    required this.orderFee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canApply = orderFee >= (voucher.minOrderValue ?? 0);
    final color = switch (voucher.type) {
      'freeship' => AppColors.accent2,
      'percent' => AppColors.primary,
      _ => AppColors.success,
    };
    final icon = switch (voucher.type) {
      'freeship' => Icons.local_shipping_outlined,
      'percent' => Icons.percent_rounded,
      _ => Icons.card_giftcard_outlined,
    };
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: canApply && onTap != null,
      child: LiquidGlass(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canApply ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border:
                    isSelected ? Border.all(color: color, width: 1.5) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GlassIcon(
                        icon: icon,
                        color: canApply ? color : AppColors.textSecondary,
                        size: 48,
                        iconSize: 24),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(voucher.discountLabel,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: canApply
                                    ? color
                                    : AppColors.textSecondary)),
                        const SizedBox(height: 3),
                        Text(voucher.code,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: isSelected ? color : AppColors.textTertiary),
                  ]),
                  if (voucher.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(voucher.description!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            [
                              if (voucher.minOrderValue != null)
                                'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}',
                              if (voucher.maxDiscount != null)
                                'Giảm tối đa ${Fmt.currency(voucher.maxDiscount!)}',
                              if (voucher.minOrderValue == null &&
                                  voucher.maxDiscount == null)
                                'Không yêu cầu giá trị tối thiểu',
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        if (voucher.expiresAt != null) ...[
                          const SizedBox(height: 5),
                          Text('HSD: ${Fmt.date(voucher.expiresAt!)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                        if (!canApply || isSelected) ...[
                          const SizedBox(height: 7),
                          Text(
                              !canApply
                                  ? 'Cần thêm ${Fmt.currency(voucher.minOrderValue! - orderFee)} để áp dụng'
                                  : 'Đang áp dụng',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !canApply ? AppColors.danger : color)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const LiquidGlass(
        padding: EdgeInsets.all(24),
        child: Column(children: [
          GlassIcon(
              icon: Icons.confirmation_number_outlined,
              color: AppColors.primary,
              size: 56,
              iconSize: 26),
          SizedBox(height: 14),
          Text('Chưa có ưu đãi phù hợp',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Bạn vẫn có thể nhập mã ở trên.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
}
