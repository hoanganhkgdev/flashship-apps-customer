part of '../screens/home_screen.dart';

// ── Saved address quick row (Đặt nhanh) ─────────────────────────────────────────

class _SavedAddressQuickRow extends ConsumerWidget {
  final void Function(AddressModel address) onPickAddress;
  const _SavedAddressQuickRow({required this.onPickAddress});

  static IconData _icon(String label) => switch (label) {
        'Nhà' => Icons.home_rounded,
        'Cơ quan' => Icons.business_rounded,
        _ => Icons.location_on_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    if (addresses.isEmpty) return const SizedBox.shrink();
    final shown = addresses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.info),
            ),
            const SizedBox(width: 8),
            Text('Địa chỉ thường dùng',
                style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final addr = shown[index];
              return _AddressQuickTile(
                address: addr,
                icon: _icon(addr.label),
                onTap: () => onPickAddress(addr),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AddressQuickTile extends StatelessWidget {
  final AddressModel address;
  final IconData icon;
  final VoidCallback onTap;
  const _AddressQuickTile({
    required this.address,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            Text(address.label.isNotEmpty ? address.label : 'Địa chỉ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
