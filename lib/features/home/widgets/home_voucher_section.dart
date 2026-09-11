part of '../screens/home_screen.dart';

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchers = ref.watch(voucherProvider).valueOrNull ?? [];
    if (vouchers.isEmpty) return const SizedBox.shrink();
    final sorted = [
      ...vouchers.where((v) => v.appOnly),
      ...vouchers.where((v) => !v.appOnly),
    ];
    final shown = sorted.take(2).toList();
    void viewAll() => context.push('/vouchers');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlass(
        borderRadius: HomeStyle.radius,
        padding: const EdgeInsets.all(4),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(children: [
              const GlassIcon(
                  icon: Icons.local_offer_rounded,
                  color: HomeStyle.orange,
                  size: 34,
                  iconSize: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Row(children: [
                const Flexible(
                    child: Text('Ưu đãi dành cho bạn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.ink))),
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: HomeStyle.orange.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(AppRadius.glass)),
                  child: Text('${vouchers.length}',
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.orange)),
                ),
              ])),
              const SizedBox(width: 8),
              TextButton(
                onPressed: viewAll,
                style: TextButton.styleFrom(
                    foregroundColor: HomeStyle.orange,
                    backgroundColor: HomeStyle.orange.withValues(alpha: .08),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.glass))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Xem tất cả',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 17)
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: IntrinsicHeight(
                child: Row(children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                    child: _HomeVoucherCard(
                        voucher: shown[i], index: i, onTap: viewAll)),
              ],
            ])),
          ),
        ]),
      ),
    );
  }
}

class _HomeVoucherCard extends StatelessWidget {
  const _HomeVoucherCard(
      {required this.voucher, required this.index, required this.onTap});
  final VoucherModel voucher;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = [HomeStyle.orange, Color(0xFF318B83)];
    final accent = colors[index % colors.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: HomeStyle.radius,
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: HomeStyle.radius,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .76),
                  accent.withValues(alpha: .11)
                ]),
            border: Border.all(color: Colors.white.withValues(alpha: .88)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GlassIcon(
                  icon: Icons.confirmation_number_rounded,
                  color: accent,
                  size: 32,
                  iconSize: 17),
              const Spacer(),
              if (voucher.appOnly)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(AppRadius.glass)),
                  child: Text('APP',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
            ]),
            const SizedBox(height: 10),
            Text(voucher.discountLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: accent)),
            const SizedBox(height: 5),
            Text(voucher.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    letterSpacing: .4,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.ink)),
            if (voucher.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(voucher.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, height: 1.25, color: HomeStyle.muted)),
            ],
            const Spacer(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: accent.withValues(alpha: .13),
                    foregroundColor: accent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.glass),
                        side:
                            BorderSide(color: accent.withValues(alpha: .16)))),
                child: const Text('Dùng ngay',
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
