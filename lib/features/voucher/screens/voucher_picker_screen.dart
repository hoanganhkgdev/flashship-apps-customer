import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        title: Text('Chọn ưu đãi',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Code input ────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập mã ưu đãi...',
                      hintStyle: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.confirmation_number_outlined,
                          size: 18,
                          color: _error != null
                              ? AppColors.danger
                              : AppColors.textSecondary),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textSecondary),
                              onPressed: () {
                                _ctrl.clear();
                                setState(() => _error = null);
                              })
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5))),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                      setState(() {});
                    },
                    onSubmitted: _applying ? null : _applyCode,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _applying || _ctrl.text.trim().isEmpty
                        ? null
                        : () => _applyCode(_ctrl.text),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(96, 52),
                      maximumSize: const Size(96, 52),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Áp dụng',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 13, color: AppColors.danger),
                  const SizedBox(width: 4),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: AppColors.danger)),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ── Voucher list ──────────────────────────────────────────────
          voucherAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
            ),
            error: (_, __) => const _EmptyState(),
            data: (vouchers) {
              final now = DateTime.now();
              final applicable = vouchers
                  .where((v) =>
                      v.isAvailable &&
                      (v.expiresAt == null || v.expiresAt!.isAfter(now)) &&
                      (v.serviceTypes == null ||
                          v.serviceTypes!.contains(widget.serviceType)))
                  .toList();
              if (applicable.isEmpty) return const _EmptyState();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.local_offer_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Ưu đãi của bạn',
                          style: TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ]),
                  ),
                  ...applicable.map((v) => _VoucherCard(
                        voucher: v,
                        isSelected: _selectedCode == v.code,
                        orderFee: widget.orderFee ?? 0,
                        onTap: () => _applyCode(v.code),
                      )),
                ],
              );
            },
          ),

          // ── Remove applied voucher ────────────────────────────────────
          if (_selectedCode != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                    context, const VoucherPickResult(code: '', discount: 0)),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 16, color: AppColors.danger),
                label: const Text('Bỏ ưu đãi đang áp dụng',
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger)),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Voucher card (ticket style) ───────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final bool isSelected;
  final int orderFee;
  final VoidCallback onTap;

  const _VoucherCard({
    required this.voucher,
    required this.isSelected,
    required this.orderFee,
    required this.onTap,
  });

  bool get _canApply =>
      voucher.minOrderValue == null || orderFee >= voucher.minOrderValue!;

  Color get _color => switch (voucher.type) {
        'freeship' => AppColors.accent2,
        'percent' => AppColors.primary,
        _ => AppColors.success,
      };

  IconData get _icon => switch (voucher.type) {
        'freeship' => Icons.local_shipping_outlined,
        'percent' => Icons.percent_rounded,
        _ => Icons.card_giftcard_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final isExpiringSoon = voucher.expiresAt != null &&
        voucher.expiresAt!.difference(DateTime.now()).inDays <= 3;

    return Opacity(
      opacity: _canApply ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: _canApply ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: isSelected
                ? Border.all(color: _color, width: 1.5)
                : Border.all(color: AppColors.divider),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left colored panel ──────────────────────────────
                Container(
                  width: 78,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      bottomLeft: Radius.circular(17),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(_icon, size: 20, color: _color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        voucher.discountLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: _color),
                      ),
                    ],
                  ),
                ),

                // ── Dashed separator ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                        6,
                        (_) => Container(
                              width: 1,
                              height: 4,
                              color: AppColors.divider,
                            )),
                  ),
                ),

                // ── Right content ───────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(voucher.code,
                                style: TextStyle(
                                    fontSize: AppFontSize.bodyLarge,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.5)),
                          ),
                          if (isSelected)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
                            )
                          else if (isExpiringSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Sắp hết',
                                  style: TextStyle(
                                      fontSize: AppFontSize.caption,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger)),
                            ),
                        ]),
                        if (voucher.description != null) ...[
                          const SizedBox(height: 4),
                          Text(voucher.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          if (!_canApply && voucher.minOrderValue != null)
                            Text(
                              'Đơn tối thiểu ${Fmt.currency(voucher.minOrderValue!)}',
                              style: TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: AppColors.danger),
                            )
                          else if (voucher.minOrderValue != null)
                            Text(
                              'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}',
                              style: TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: AppColors.textTertiary),
                            ),
                          const Spacer(),
                          if (voucher.expiresAt != null)
                            Text('HSD: ${Fmt.date(voucher.expiresAt!)}',
                                style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    color: AppColors.textTertiary)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('Không có ưu đãi nào',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Nhập mã thủ công ở trên để áp dụng',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
}
