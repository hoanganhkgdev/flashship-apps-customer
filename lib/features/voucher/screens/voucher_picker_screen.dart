import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';

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
    if (code.trim().isEmpty) return;
    setState(() { _applying = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).post(
        '/customer/vouchers/validate',
        data: {
          'code':         code.trim().toUpperCase(),
          'service_type': widget.serviceType,
          'order_total':  widget.orderFee ?? 0,
          'shipping_fee': widget.orderFee ?? 0,
        },
      );
      final data     = res.data as Map<String, dynamic>;
      final discount = (data['discount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      Navigator.pop(context, VoucherPickResult(
        code:     code.trim().toUpperCase(),
        discount: discount,
      ));
    } catch (e) {
      String msg = 'Mã không hợp lệ';
      try { msg = (e as dynamic).response?.data['message'] ?? msg; } catch (_) {}
      setState(() { _error = msg; _applying = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final voucherAsync = ref.watch(voucherProvider);

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
        title: const Text('Chọn ưu đãi',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Code input ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập mã ưu đãi...',
                      hintStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w400,
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
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
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
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5))),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                      setState(() {});
                    },
                    onSubmitted: _applyCode,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applying ? null : () => _applyCode(_ctrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    elevation: 0,
                    minimumSize: const Size(0, 46),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _applying
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Áp dụng',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.white)),
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
                          fontSize: 12, color: AppColors.danger)),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ── Voucher list ──────────────────────────────────────────────
          voucherAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
            ),
            error: (_, __) => const _EmptyState(),
            data: (vouchers) {
              final applicable = vouchers.where((v) =>
                  v.serviceTypes == null ||
                  v.serviceTypes!.contains(widget.serviceType)).toList();
              if (applicable.isEmpty) return const _EmptyState();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_offer_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      const Text('Ưu đãi của bạn',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
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
                onPressed: () => Navigator.pop(context,
                    const VoucherPickResult(code: '', discount: 0)),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 16, color: AppColors.danger),
                label: const Text('Bỏ ưu đãi đang áp dụng',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
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
    'freeship' => AppColors.info,
    'percent'  => AppColors.success,
    _          => AppColors.primary,
  };

  IconData get _icon => switch (voucher.type) {
    'freeship' => Icons.local_shipping_rounded,
    'percent'  => Icons.percent_rounded,
    _          => Icons.card_giftcard_rounded,
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: _color, width: 1.5)
                : null,
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left colored panel ──────────────────────────────
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_icon, size: 20, color: _color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        voucher.discountLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
                    children: List.generate(6, (_) => Container(
                      width: 1, height: 4,
                      color: const Color(0xFFE0E0E0),
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
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.5)),
                          ),
                          if (isSelected)
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: _color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14),
                            )
                          else if (isExpiringSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Sắp hết',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger)),
                            ),
                        ]),
                        if (voucher.description != null) ...[
                          const SizedBox(height: 4),
                          Text(voucher.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          if (!_canApply && voucher.minOrderValue != null)
                            Text(
                              'Đơn tối thiểu ${Fmt.currency(voucher.minOrderValue!)}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.danger),
                            )
                          else if (voucher.minOrderValue != null)
                            Text(
                              'Đơn từ ${Fmt.currency(voucher.minOrderValue!)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          const Spacer(),
                          if (voucher.expiresAt != null)
                            Text('HSD: ${Fmt.date(voucher.expiresAt!)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
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
        width: 80, height: 80,
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
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Nhập mã thủ công ở trên để áp dụng',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );
}
