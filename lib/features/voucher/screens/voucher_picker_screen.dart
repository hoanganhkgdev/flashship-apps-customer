import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';
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
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Column(children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: HomeStyle.card,
            border: Border(bottom: BorderSide(color: HomeStyle.divider)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: HomeStyle.card,
                    side: const BorderSide(color: HomeStyle.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chọn ưu đãi', style: HomeStyle.title),
                      SizedBox(height: 2),
                      Text('Tiết kiệm hơn cho đơn này',
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _FlatCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bạn có mã ưu đãi?',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.ink)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          enabled: !_applying,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600,
                              color: HomeStyle.ink),
                          decoration: InputDecoration(
                            hintText: 'Nhập mã ưu đãi',
                            filled: true,
                            fillColor: HomeStyle.cardMuted,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 15),
                            border: _inputBorder(HomeStyle.divider),
                            enabledBorder: _inputBorder(HomeStyle.divider),
                            disabledBorder: _inputBorder(HomeStyle.divider),
                            focusedBorder: _inputBorder(HomeStyle.orange, 1.5),
                          ),
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: _applyCode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _applying || _ctrl.text.trim().isEmpty
                            ? null
                            : () => _applyCode(_ctrl.text),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: HomeStyle.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: HomeStyle.divider,
                          disabledForegroundColor: HomeStyle.muted,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          textStyle: const TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w700),
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
                              fontSize: AppFontSize.caption,
                              color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Ưu đãi cho đơn này', style: HomeStyle.title),
              const SizedBox(height: 4),
              const Text('Chạm vào ưu đãi để áp dụng',
                  style: TextStyle(
                      fontSize: AppFontSize.caption, color: HomeStyle.muted)),
              const SizedBox(height: 12),
              voucherAsync.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: HomeStyle.orange))),
                error: (_, __) => _FlatCard(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(children: [
                      const Text('Chưa tải được ưu đãi',
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              color: HomeStyle.ink)),
                      TextButton(
                          onPressed: () => ref.invalidate(voucherProvider),
                          style: TextButton.styleFrom(
                              foregroundColor: HomeStyle.orange),
                          child: const Text('Thử lại')),
                    ]),
                  ),
                ),
                data: (vouchers) {
                  final fee = widget.orderFee ?? 0;
                  final applicable = vouchers
                      .where((v) =>
                          v.isAvailable &&
                          (v.serviceTypes == null ||
                              v.serviceTypes!.contains(widget.serviceType)))
                      .toList()
                    // Ưu đãi dùng được ngay lên trước, ưu đãi chưa đủ giá trị xuống sau.
                    ..sort((a, b) {
                      final aOk = fee >= (a.minOrderValue ?? 0);
                      final bOk = fee >= (b.minOrderValue ?? 0);
                      if (aOk == bOk) return 0;
                      return aOk ? -1 : 1;
                    });
                  if (applicable.isEmpty) return const _EmptyState();
                  return Column(
                    children: applicable
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _VoucherCard(
                                voucher: v,
                                isSelected: _selectedCode == v.code,
                                orderFee: fee,
                                onTap:
                                    _applying ? null : () => _applyCode(v.code),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              if (_selectedCode != null)
                TextButton.icon(
                  onPressed: _applying
                      ? null
                      : () => Navigator.pop(context,
                          const VoucherPickResult(code: '', discount: 0)),
                  icon:
                      const Icon(Icons.remove_circle_outline_rounded, size: 18),
                  label: const Text('Bỏ ưu đãi đang áp dụng'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 44)),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _FlatCard extends StatelessWidget {
  const _FlatCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor = HomeStyle.divider,
    this.borderWidth = 1,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Padding(padding: padding, child: child),
      );
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
      'percent' => HomeStyle.orange,
      _ => AppColors.success,
    };
    final icon = switch (voucher.type) {
      'freeship' => Icons.local_shipping_outlined,
      'percent' => Icons.percent_rounded,
      _ => Icons.card_giftcard_outlined,
    };
    final accent = canApply ? color : HomeStyle.muted;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: canApply && onTap != null,
      child: _FlatCard(
        borderColor: isSelected ? color : HomeStyle.divider,
        borderWidth: isSelected ? 1.5 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: canApply ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(icon, size: 24, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(voucher.discountLabel,
                              style: TextStyle(
                                  fontSize: AppFontSize.title,
                                  fontWeight: FontWeight.w800,
                                  color: accent)),
                          const SizedBox(height: 3),
                          Text(voucher.code,
                              style: const TextStyle(
                                  fontSize: AppFontSize.caption,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .4,
                                  color: HomeStyle.ink)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 24,
                        color: isSelected ? color : HomeStyle.muted),
                  ]),
                  if (voucher.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(voucher.description!,
                        style: const TextStyle(
                            fontSize: AppFontSize.body,
                            height: 1.4,
                            color: HomeStyle.ink)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HomeStyle.cardMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: HomeStyle.divider),
                    ),
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
                                fontSize: AppFontSize.caption,
                                color: HomeStyle.muted)),
                        if (voucher.expiresAt != null) ...[
                          const SizedBox(height: 5),
                          Text('HSD: ${Fmt.date(voucher.expiresAt!)}',
                              style: const TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: HomeStyle.muted)),
                        ],
                        if (!canApply || isSelected) ...[
                          const SizedBox(height: 7),
                          Text(
                              !canApply
                                  ? 'Cần thêm ${Fmt.currency(voucher.minOrderValue! - orderFee)} để áp dụng'
                                  : 'Đang áp dụng',
                              style: TextStyle(
                                  fontSize: AppFontSize.caption,
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
  Widget build(BuildContext context) => _FlatCard(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.confirmation_number_outlined,
                  size: 26, color: HomeStyle.orange),
            ),
            const SizedBox(height: 14),
            const Text('Chưa có ưu đãi phù hợp',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.ink)),
            const SizedBox(height: 6),
            const Text('Bạn vẫn có thể nhập mã ở trên.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFontSize.body, color: HomeStyle.muted)),
          ]),
        ),
      );
}
