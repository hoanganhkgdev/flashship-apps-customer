part of '../screens/home_screen.dart';

// ── Header (BShip style) ─────────────────────────────────────────────────────

class _QuickServiceRow extends StatelessWidget {
  const _QuickServiceRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Header extends ConsumerWidget {
  final String name;
  final String initials;
  final String currentAddress;
  final String? currentPlaceName;
  final bool isDetecting;
  const _Header({
    required this.name,
    required this.initials,
    required this.currentAddress,
    this.currentPlaceName,
    required this.isDetecting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final result =
                            await Navigator.of(context).push<MapPickResult>(
                          MaterialPageRoute(
                            builder: (_) => const AddressPickerScreen(),
                          ),
                        );
                        if (result != null && context.mounted) {
                          ref.read(activeCityProvider.notifier).overrideAddress(
                                result.address,
                                placeName: result.placeName,
                              );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GIAO ĐẾN',
                            style: TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isDetecting)
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            Text(
                              currentPlaceName?.isNotEmpty == true
                                  ? currentPlaceName!
                                  : currentAddress.isNotEmpty
                                      ? currentAddress
                                      : 'Chọn địa chỉ giao đến',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => ref.read(_homeTabProvider.notifier).state = 2,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF4E4642),
                            size: 23,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent address row ────────────────────────────────────────────────────────

class _RecentAddressRow extends ConsumerStatefulWidget {
  const _RecentAddressRow();

  @override
  ConsumerState<_RecentAddressRow> createState() => _RecentAddressRowState();
}

class _RecentAddressRowState extends ConsumerState<_RecentAddressRow> {
  List<AddressHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AddressHistoryService.load();
    if (!mounted) return;
    setState(() => _items = items.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = _items[i];
          return GestureDetector(
            onTap: () {
              ref
                  .read(activeCityProvider.notifier)
                  .overrideAddress(item.address);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    item.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Service icon grid ─────────────────────────────────────────────────────────

class _ServiceIconGrid extends ConsumerWidget {
  final void Function(String type) onTap;
  const _ServiceIconGrid({required this.onTap});

  static Color _serviceColor(String key) => switch (key) {
        'delivery' => AppColors.primary,
        'shopping' => AppColors.accent2,
        'topup' => AppColors.success,
        'bike' => const Color(0xFFB66D00),
        'motor' => AppColors.info,
        'car' => const Color(0xFF7B61FF),
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceTypeProvider).valueOrNull ?? [];
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.apps_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text('Dịch vụ',
                style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            childAspectRatio: 1.38,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: services
                .map((svc) => _ServiceIconItem(
                      svc: svc,
                      color: _serviceColor(svc.key),
                      onTap: () => onTap(svc.key),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ServiceIconItem extends StatelessWidget {
  final ServiceTypeModel svc;
  final Color color;
  final VoidCallback onTap;
  const _ServiceIconItem(
      {required this.svc, required this.color, required this.onTap});

  static IconData _icon(String key) => switch (key) {
        'delivery' => Icons.inventory_2_outlined,
        'shopping' => Icons.shopping_bag_outlined,
        'topup' => Icons.credit_card_rounded,
        'bike' => Icons.pedal_bike_rounded,
        'motor' => Icons.electric_scooter_rounded,
        'car' => Icons.directions_car_filled_outlined,
        _ => Icons.miscellaneous_services_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(_icon(svc.key), color: color, size: 25),
            const SizedBox(height: 7),
            Text(
              svc.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
