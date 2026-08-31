import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../voucher/providers/voucher_validation_provider.dart';

class VoucherInputRow extends ConsumerStatefulWidget {
  final String serviceType;
  final int? orderFee;
  final void Function(String? code, int? discount) onChanged;

  const VoucherInputRow({
    super.key,
    required this.serviceType,
    required this.onChanged,
    this.orderFee,
  });

  @override
  ConsumerState<VoucherInputRow> createState() => _VoucherInputRowState();
}

class _VoucherInputRowState extends ConsumerState<VoucherInputRow> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _applied = false;
  int? _discount;
  String? _label;
  String? _desc;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(voucherValidationServiceProvider).validate(
            code: code,
            serviceType: widget.serviceType,
            orderFee: widget.orderFee ?? 0,
          );
      if (!mounted) return;
      setState(() {
        _applied = true;
        _discount = result.discount;
        _label = result.discountLabel;
        _desc = result.description;
        _loading = false;
      });
      widget.onChanged(result.code, result.discount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, 'Mã không hợp lệ');
        _loading = false;
      });
    }
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _applied = false;
      _discount = null;
      _label = null;
      _desc = null;
      _error = null;
    });
    widget.onChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    if (_applied) {
      return _AppliedBanner(
        code: _ctrl.text.trim().toUpperCase(),
        label: _label ?? '',
        desc: _desc,
        discount: _discount ?? 0,
        onRemove: _clear,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nhập mã giảm giá',
                prefixIcon: const Icon(Icons.local_offer_outlined),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {
                _error = null;
              }),
              onSubmitted: (_) => _apply(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              onPressed: _loading || _ctrl.text.trim().isEmpty ? null : _apply,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Áp dụng',
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.error_outline_rounded,
                size: 14, color: AppColors.danger),
            const SizedBox(width: 4),
            Text(_error!,
                style: const TextStyle(
                    fontSize: AppFontSize.caption, color: AppColors.danger)),
          ]),
        ],
      ],
    );
  }
}

class _AppliedBanner extends StatelessWidget {
  final String code;
  final String label;
  final String? desc;
  final int discount;
  final VoidCallback onRemove;

  const _AppliedBanner({
    required this.code,
    required this.label,
    required this.discount,
    required this.onRemove,
    this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_offer_rounded,
              size: 16, color: AppColors.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppFontSize.body,
                      color: AppColors.success,
                      letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            if (discount > 0)
              Text('Tiết kiệm ${Fmt.currency(discount)}',
                  style: const TextStyle(
                      fontSize: AppFontSize.caption, color: AppColors.success)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 18, color: AppColors.textSecondary),
          onPressed: onRemove,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}
