import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../home/widgets/home_style.dart';

class BookingSummaryBar extends StatelessWidget {
  const BookingSummaryBar({
    super.key,
    this.buttonLabel = 'Đặt giao hàng',
    this.feeLabel = 'Cước giao hàng',
    this.emptyPriceHint = 'Chọn điểm lấy và điểm giao để xem cước',
    required this.serviceName,
    required this.canEstimate,
    required this.onRetry,
    required this.distanceKm,
    required this.fee,
    required this.netFee,
    required this.nightSurcharge,
    required this.loadingFee,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final String buttonLabel;
  final String feeLabel;
  final String emptyPriceHint;
  final String serviceName;
  final bool canEstimate;
  final VoidCallback onRetry;
  final double? distanceKm;
  final int? fee;
  final int netFee;
  final int nightSurcharge;
  final bool loadingFee;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = fee != null && fee! > netFee;
    final ready = fee != null && !loadingFee && !submitting;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HomeStyle.card,
        border: Border(top: BorderSide(color: HomeStyle.divider)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feeLabel,
                          style: _style(
                              AppFontSize.body, FontWeight.w500, _muted)),
                      const SizedBox(height: 4),
                      if (loadingFee)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Text(fee == null ? 'Chưa có giá' : Fmt.currency(netFee),
                            style: _style(AppFontSize.heading, FontWeight.w700,
                                fee == null ? _muted : _orange)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(serviceName,
                          textAlign: TextAlign.right,
                          style:
                              _style(AppFontSize.body, FontWeight.w600, _ink)),
                      if (distanceKm != null && !loadingFee) ...[
                        const SizedBox(height: 4),
                        Text('${distanceKm!.toStringAsFixed(1)} km',
                            textAlign: TextAlign.right,
                            style: _style(
                                AppFontSize.caption, FontWeight.w500, _muted)),
                      ],
                      if (hasDiscount && !loadingFee) ...[
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: Fmt.currency(fee!),
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: 'Đã giảm ${Fmt.currency(fee! - netFee)}',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                          textAlign: TextAlign.right,
                          style: _style(
                              AppFontSize.caption, FontWeight.w400, _muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!loadingFee && nightSurcharge > 0) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 6, children: [
                if (nightSurcharge > 0)
                  Text('Phụ phí đêm: ${Fmt.currency(nightSurcharge)}',
                      style: _style(AppFontSize.caption, FontWeight.w500,
                          AppColors.warning)),
              ]),
            ],
            if (fee == null && !loadingFee) ...[
              const SizedBox(height: 8),
              if (canEstimate)
                TextButton.icon(
                  onPressed: submitting ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử tính cước lại'),
                )
              else
                Text(emptyPriceHint,
                    style:
                        _style(AppFontSize.caption, FontWeight.w400, _muted)),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(error!,
                        style: _style(AppFontSize.caption, FontWeight.w500,
                            AppColors.danger))),
              ]),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: ready ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      submitting ? HomeStyle.orange : HomeStyle.divider,
                  disabledForegroundColor:
                      submitting ? Colors.white : HomeStyle.muted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(loadingFee ? 'Đang tính cước…' : buttonLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _ink = AppColors.textPrimary;
const _muted = AppColors.textSecondary;
const _orange = HomeStyle.orange;

TextStyle _style(double size, [FontWeight? weight, Color? color]) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color);
