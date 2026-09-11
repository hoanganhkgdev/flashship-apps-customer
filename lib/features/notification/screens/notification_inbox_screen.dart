import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../order/providers/order_provider.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/utils/formatters.dart' show Fmt;
import '../../home/widgets/bottom_nav.dart';
import '../../home/widgets/home_style.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

final _notificationServiceProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, code) async {
  final orders = ref.watch(orderListProvider.select((state) => state.orders));
  for (final order in orders) {
    if (order.code == code) return order.serviceType;
  }
  final response = await ref
      .read(apiClientProvider)
      .get('/customer/orders/${Uri.encodeComponent(code)}');
  final data = response.data['data'] ?? response.data;
  return data['service_type'] as String?;
});

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final items = state.items;
    final unreadCount = items.where((n) => !n.isRead).length;
    final groups = <String, List<NotificationItem>>{};
    for (final item in items) {
      final now = DateTime.now();
      final date = DateUtils.dateOnly(item.createdAt.toLocal());
      final today = DateUtils.dateOnly(now);
      final label = date == today
          ? 'Hôm nay'
          : date == today.subtract(const Duration(days: 1))
              ? 'Hôm qua'
              : Fmt.date(date).toUpperCase();
      groups.putIfAbsent(label, () => []).add(item);
    }

    return LiquidBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Thông báo',
                          style: TextStyle(
                            fontSize: AppFontSize.display,
                            fontWeight: FontWeight.w800,
                            color: HomeStyle.ink,
                          )),
                    ),
                    IconButton(
                      tooltip: 'Đánh dấu tất cả đã đọc',
                      onPressed: unreadCount > 0
                          ? () => ref
                              .read(notificationProvider.notifier)
                              .markAllRead()
                          : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(42, 42),
                        backgroundColor: Colors.white.withValues(alpha: .45),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: .8)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass)),
                      ),
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      unreadCount > 0
                          ? '$unreadCount thông báo chưa đọc'
                          : 'Bạn đã đọc tất cả thông báo',
                      style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        color: HomeStyle.muted,
                      )),
                ],
              ),
            ),
            Expanded(
                child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).fetchFromServer(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 32 + BottomNav.reservedHeight(context)),
                children: [
                  if (items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: _EmptyState()),
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Text(group.key,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary)),
                    ),
                    ...group.value.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NotifRow(
                            item: item,
                            onTap: () {
                              ref
                                  .read(notificationProvider.notifier)
                                  .markRead(item.id);
                              if (item.orderCode != null) {
                                context.push('/order/${item.orderCode}');
                              }
                            },
                            onDismiss: () => ref
                                .read(notificationProvider.notifier)
                                .delete(item.id),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],

                  // ── Xem thêm ────────────────────────────────────────────
                  if (state.hasMore || state.isLoadingMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: state.isLoadingMore
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(notificationProvider.notifier)
                                  .loadMore(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                backgroundColor:
                                    Colors.white.withValues(alpha: .4),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.glass)),
                                side:
                                    const BorderSide(color: AppColors.divider),
                              ),
                              child: const Text('Xem thêm',
                                  style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                            ),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Notification row ──────────────────────────────────────────────────────────

class _NotifRow extends ConsumerWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifRow({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  String? get _orderStatus {
    if (item.orderCode?.trim().isNotEmpty != true) return null;
    final title = '${item.title} ${item.body}'.toLowerCase();
    final String status;
    if (title.contains('đã giao') ||
        title.contains('giao hàng thành công') ||
        title.contains('giao thành công') ||
        title.contains('hoàn thành')) {
      status = 'Đã giao';
    } else if (title.contains('đã lấy') || title.contains('đã nhận hàng')) {
      status = 'Đã lấy hàng';
    } else if (title.contains('đã nhận') || title.contains('nhận đơn')) {
      status = 'Đã nhận';
    } else {
      return null;
    }
    return status;
  }

  String get _compactTitle {
    final status = _orderStatus;
    if (status == null) return item.title;
    final code = item.orderCode!.trim().replaceFirst(RegExp(r'^#'), '');
    return '#$code · $status';
  }

  (IconData, Color) get _meta {
    switch (_orderStatus) {
      case 'Đã nhận':
        return (Icons.inventory_2_outlined, HomeStyle.orange);
      case 'Đã lấy hàng':
        return (Icons.inventory_2_outlined, const Color(0xFF4F8FE8));
      case 'Đã giao':
        return (Icons.check_rounded, AppColors.success);
    }
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (text.contains('hoàn thành') || text.contains('thành công')) {
      return (Icons.check_rounded, AppColors.success);
    }
    if (text.contains('voucher') ||
        text.contains('ưu đãi') ||
        text.contains('giảm')) {
      return (Icons.confirmation_number_outlined, AppColors.primary);
    }
    if (text.contains('chính sách') || text.contains('bảo mật')) {
      return (Icons.shield_outlined, AppColors.textTertiary);
    }
    return (Icons.inventory_2_outlined, const Color(0xFF4F8FE8));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, iconColor) = _meta;
    final code = item.orderCode?.trim();
    final serviceType = code != null && code.isNotEmpty
        ? ref.watch(_notificationServiceProvider(code)).valueOrNull
        : null;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.createdAt.toLocal()),
      alwaysUse24HourFormat: true,
    );
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.glass)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      child: LiquidGlass(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              decoration: BoxDecoration(
                color: item.isRead
                    ? Colors.transparent
                    : AppColors.primary.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: Colors.white.withValues(alpha: .6)),
              ),
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GlassIcon(icon: icon, color: iconColor, size: 34, iconSize: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(_compactTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      fontWeight: item.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color: item.isRead
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                      height: 1.3)),
                            ),
                            const SizedBox(width: 8),
                            Text(time,
                                style: const TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: HomeStyle.muted,
                                )),
                            if (!item.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle),
                              ),
                            ],
                          ]),
                      if (_compactTitle == item.title) ...[
                        const SizedBox(height: 3),
                        Text(item.body,
                            style: TextStyle(
                                fontSize: AppFontSize.body,
                                color: item.isRead
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      if (item.orderCode?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                serviceType != null
                                    ? Fmt.serviceLabel(serviceType)
                                    : 'Đơn hàng',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: HomeStyle.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Xem đơn',
                                style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.primary),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
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
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const GlassIcon(
              icon: Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 72,
              iconSize: 34),
          const SizedBox(height: 16),
          const Text('Chưa có thông báo nào',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Thông báo mới sẽ xuất hiện tại đây',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
}
