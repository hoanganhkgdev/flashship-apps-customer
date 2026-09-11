part of '../screens/home_screen.dart';

class _SavedAddressQuickRow extends ConsumerWidget {
  final void Function(AddressModel address) onPickAddress;
  const _SavedAddressQuickRow({required this.onPickAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressesProvider);
    final addresses = state.valueOrNull ?? [];
    final ranked = [...addresses];
    int priority(AddressModel address) => switch (address.label) {
          'Nhà' || 'Nhà riêng' => 0,
          'Cơ quan' || 'Công ty' => 1,
          _ => 2,
        };
    ranked.sort((a, b) => priority(a).compareTo(priority(b)));
    final shown = ranked.take(2).toList();
    void manage() => context.push('/profile/addresses');
    final loadingEmpty = state.isLoading && shown.isEmpty;
    final errorEmpty = state.hasError && shown.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LiquidGlass(
          borderRadius: HomeStyle.radius,
          padding: const EdgeInsets.all(4),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(children: [
                const GlassIcon(
                  icon: Icons.location_on_rounded,
                  color: HomeStyle.orange,
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    const Flexible(
                      child: Text('Địa chỉ thường dùng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w700,
                              color: HomeStyle.ink)),
                    ),
                    if (addresses.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: HomeStyle.orange.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(AppRadius.glass),
                        ),
                        child: Text('${addresses.length}',
                            style: const TextStyle(
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.orange)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: manage,
                  style: TextButton.styleFrom(
                    foregroundColor: HomeStyle.orange,
                    backgroundColor: HomeStyle.orange.withValues(alpha: .08),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.glass)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Quản lý',
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 17),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            if (loadingEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 20),
                child: LinearProgressIndicator(
                    color: HomeStyle.orange, backgroundColor: HomeStyle.peach),
              )
            else if (errorEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  const Expanded(
                    child: Text('Chưa tải được địa chỉ',
                        style: TextStyle(
                            color: HomeStyle.muted,
                            fontSize: AppFontSize.caption)),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(addressesProvider),
                    child: const Text('Thử lại'),
                  ),
                ]),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: IntrinsicHeight(
                  child: Row(children: [
                    for (var i = 0; i < 2; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: i < shown.length
                            ? _AddressQuickTile(
                                address: shown[i],
                                onTap: () => onPickAddress(shown[i]),
                              )
                            : _AddressQuickTile(onTap: manage),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _AddressQuickTile extends StatelessWidget {
  final AddressModel? address;
  final VoidCallback onTap;
  const _AddressQuickTile({this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = address?.label ?? '';
    final home = ['Nhà', 'Nhà riêng'].contains(label);
    final work = ['Cơ quan', 'Công ty'].contains(label);
    final title = address == null
        ? 'Thêm địa chỉ'
        : home
            ? 'Nhà riêng'
            : work
                ? 'Công ty'
                : label.isNotEmpty
                    ? label
                    : 'Địa chỉ';
    final icon = address == null
        ? Icons.add_rounded
        : home
            ? Icons.home_rounded
            : work
                ? Icons.work_rounded
                : Icons.location_on_rounded;
    final color = address == null
        ? HomeStyle.muted
        : home
            ? AppColors.primary
            : work
                ? AppColors.info
                : AppColors.accent2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: HomeStyle.radius,
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .25),
            borderRadius: HomeStyle.radius,
            border: Border.all(color: Colors.white.withValues(alpha: .65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GlassIcon(icon: icon, color: color, size: 36, iconSize: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.ink)),
                ),
              ]),
              const SizedBox(height: 9),
              Text(address?.address ?? 'Lưu địa chỉ để đặt nhanh',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSize.caption,
                      height: 1.35,
                      color: HomeStyle.muted)),
              const Spacer(),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadius.glass),
                ),
                child: Text(address == null ? 'Thêm' : 'Đặt ngay',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
