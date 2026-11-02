part of '../screens/home_screen.dart';

class _SavedAddressQuickRow extends ConsumerWidget {
  final void Function(AddressModel address) onPickAddress;
  const _SavedAddressQuickRow({required this.onPickAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compactHeader = MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) > 16;
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
                      TextSpan(text: 'Địa chỉ '),
                      TextSpan(
                        text: 'thường dùng',
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
                      Icons.location_on_rounded,
                      size: 15,
                      color: HomeStyle.orange,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Chọn điểm đến đã lưu',
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
              onPressed: manage,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: compactHeader
                  ? const Icon(Icons.settings_outlined, size: 18)
                  : const Text('Quản lý'),
            ),
          ]),
          const SizedBox(height: 12),
          if (loadingEmpty)
            const _AddressListSkeleton()
          else if (errorEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: HomeStyle.cardRadius,
                border: Border.all(color: HomeStyle.divider),
              ),
              child: Row(children: [
                const Expanded(
                  child: Text(
                    'Chưa tải được địa chỉ',
                    style: TextStyle(
                      color: HomeStyle.muted,
                      fontSize: AppFontSize.caption,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(addressesProvider),
                  child: const Text('Thử lại'),
                ),
              ]),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: HomeStyle.cardRadius,
                border: Border.all(color: HomeStyle.divider),
                boxShadow: HomeStyle.shadow,
              ),
              child: Column(children: [
                for (var index = 0;
                    index < (shown.isEmpty ? 1 : 2);
                    index++) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 14,
                      color: HomeStyle.divider,
                    ),
                  _AddressQuickTile(
                    address: index < shown.length ? shown[index] : null,
                    emptyTitle: shown.isEmpty
                        ? 'Thêm địa chỉ đầu tiên'
                        : 'Thêm địa chỉ',
                    onTap: index < shown.length
                        ? () => onPickAddress(shown[index])
                        : manage,
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _AddressListSkeleton extends StatelessWidget {
  const _AddressListSkeleton();

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
                        width: 82,
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

class _AddressQuickTile extends StatelessWidget {
  final AddressModel? address;
  final VoidCallback onTap;
  final String emptyTitle;
  const _AddressQuickTile({
    this.address,
    required this.onTap,
    this.emptyTitle = 'Thêm địa chỉ',
  });

  @override
  Widget build(BuildContext context) {
    final label = address?.label ?? '';
    final home = ['Nhà', 'Nhà riêng'].contains(label);
    final work = ['Cơ quan', 'Công ty'].contains(label);
    final title = address == null
        ? emptyTitle
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
    return Semantics(
      button: true,
      label: address == null ? emptyTitle : 'Đặt đến $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700,
                        color: HomeStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address?.address ??
                          'Lưu Nhà riêng hoặc Công ty để đặt nhanh',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        color: HomeStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  address == null
                      ? Icons.add_rounded
                      : Icons.chevron_right_rounded,
                  size: 19,
                  color: color,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
