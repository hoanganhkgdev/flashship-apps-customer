part of '../screens/home_screen.dart';

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compactHeader = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) > 16;
    final state = ref.watch(voucherProvider);
    final available = (state.valueOrNull ?? [])
        .where((voucher) => voucher.isAvailable)
        .toList()
      ..sort((a, b) {
        if (a.appOnly != b.appOnly) return a.appOnly ? -1 : 1;
        final aExpiry = a.expiresAt ?? DateTime(9999);
        final bExpiry = b.expiresAt ?? DateTime(9999);
        return aExpiry.compareTo(bExpiry);
      });
    final loading = state.isLoading && available.isEmpty;
    if (!loading && available.isEmpty) return const SizedBox.shrink();
    final shown = available.take(2).toList();
    void viewAll() => context.push('/vouchers');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeStyle.orangeLight, HomeStyle.orange],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Ưu đãi '),
                      TextSpan(
                        text: 'của bạn',
                        style: TextStyle(color: HomeStyle.orange),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                      color: HomeStyle.ink,
                    ),
                  ),
                  SizedBox(height: 5),
                  Row(children: [
                    Icon(
                      Icons.confirmation_number_rounded,
                      size: 15,
                      color: HomeStyle.orange,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Mã giảm giá đang có',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          height: 1.25,
                          color: HomeStyle.muted,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: viewAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: compactHeader
                  ? const Icon(Icons.arrow_forward_rounded, size: 18)
                  : const Text('Xem tất cả'),
            ),
          ]),
          const SizedBox(height: 12),
          if (loading)
            const _VoucherListSkeleton()
          else
            Column(children: [
              for (var index = 0; index < shown.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _HomeVoucherCard(
                  voucher: shown[index],
                  onTap: viewAll,
                ),
              ],
            ]),
        ],
      ),
    );
  }
}

class _VoucherListSkeleton extends StatelessWidget {
  const _VoucherListSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: HomeStyle.cardRadius,
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Column(children: [
          for (var index = 0; index < 2; index++) ...[
            if (index > 0) const Divider(indent: 64, color: HomeStyle.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 112,
                        height: 12,
                        color: const Color(0xFFEDEFF3),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        color: const Color(0xFFF1F2F5),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ]),
      );
}

class _HomeVoucherCard extends StatelessWidget {
  const _HomeVoucherCard({
    required this.voucher,
    required this.onTap,
  });

  final VoucherModel voucher;
  final VoidCallback onTap;

  (String, bool) get _detail {
    final expiry = voucher.expiresAt;
    if (expiry != null) {
      final remaining = expiry.difference(DateTime.now());
      if (!remaining.isNegative && remaining.inDays <= 3) {
        if (remaining.inDays == 0) return ('Hết hạn hôm nay', true);
        return ('Hết hạn sau ${remaining.inDays} ngày', true);
      }
    }
    if (voucher.minOrderValue != null && voucher.minOrderValue! > 0) {
      return ('Đơn tối thiểu ${Fmt.currency(voucher.minOrderValue!)}', false);
    }
    if (expiry != null) return ('HSD ${Fmt.date(expiry)}', false);
    if (voucher.description?.trim().isNotEmpty == true) {
      return (voucher.description!.trim(), false);
    }
    return ('Áp dụng theo điều kiện chương trình', false);
  }

  @override
  Widget build(BuildContext context) {
    const accent = HomeStyle.orange;
    final (detail, urgent) = _detail;
    return Material(
      color: Colors.transparent,
      borderRadius: HomeStyle.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: HomeStyle.cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeStyle.card,
            borderRadius: HomeStyle.cardRadius,
            border: Border.all(color: HomeStyle.divider),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HomeStyle.peach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.discountLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    if (voucher.appOnly) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'Ưu đãi trên app',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
                        color: urgent ? AppColors.warning : HomeStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: HomeStyle.divider),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  voucher.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Xem ưu đãi  ›',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
