import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../order/providers/order_provider.dart';
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

class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final unreadCount = state.items.where((n) => !n.isRead).length;
    final items = _unreadOnly
        ? state.items.where((item) => !item.isRead).toList()
        : state.items;
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

    return ColoredBox(
      color: HomeStyle.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9DE),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: 'Thông '),
                                      TextSpan(
                                        text: 'báo',
                                        style:
                                            TextStyle(color: HomeStyle.orange),
                                      ),
                                    ]),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.4,
                                      color: HomeStyle.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    unreadCount > 0
                                        ? 'Bạn có $unreadCount thông báo chưa đọc'
                                        : 'Thông tin đơn hàng và ưu đãi',
                                    style: const TextStyle(
                                      fontSize: AppFontSize.caption,
                                      color: HomeStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Đánh dấu tất cả đã đọc',
                              onPressed: unreadCount > 0
                                  ? () => ref
                                      .read(notificationProvider.notifier)
                                      .markAllRead()
                                  : null,
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(44),
                                backgroundColor: HomeStyle.orange,
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: .5),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              icon: Icon(
                                Icons.done_all_rounded,
                                size: 20,
                                color: unreadCount > 0
                                    ? Colors.white
                                    : HomeStyle.muted,
                              ),
                            ),
                          ]),
                      const SizedBox(height: 14),
                      Container(
                        height: 44 +
                            (MediaQuery.textScalerOf(context).scale(12) - 12)
                                .clamp(0.0, double.infinity),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(children: [
                          _NotificationFilter(
                            label: 'Tất cả',
                            selected: !_unreadOnly,
                            onTap: () => setState(() => _unreadOnly = false),
                          ),
                          _NotificationFilter(
                            label: unreadCount > 0
                                ? 'Chưa đọc ($unreadCount)'
                                : 'Chưa đọc',
                            selected: _unreadOnly,
                            onTap: () => setState(() => _unreadOnly = true),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
                child: RefreshIndicator(
              color: HomeStyle.orange,
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).fetchFromServer(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 32 + BottomNav.reservedHeight(context)),
                children: [
                  if (items.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 56, horizontal: 16),
                        child: _EmptyState(unreadOnly: _unreadOnly)),
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotificationGroupTitle(
                        label: group.key,
                        count: group.value.length,
                      ),
                    ),
                    ...group.value.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotifRow(
                            item: item,
                            onTap: () {
                              ref
                                  .read(notificationProvider.notifier)
                                  .markRead(item.id);
                              if (item.orderCode?.trim().isNotEmpty == true) {
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
                                    strokeWidth: 2, color: HomeStyle.orange),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(notificationProvider.notifier)
                                  .loadMore(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                backgroundColor: HomeStyle.card,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md)),
                                side:
                                    const BorderSide(color: HomeStyle.divider),
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

class _NotificationFilter extends StatelessWidget {
  const _NotificationFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? HomeStyle.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : HomeStyle.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _NotificationGroupTitle extends StatelessWidget {
  const _NotificationGroupTitle({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: HomeStyle.peach,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.calendar_today_rounded,
              size: 14, color: HomeStyle.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppFontSize.body,
              fontWeight: FontWeight.w800,
              color: HomeStyle.ink,
            ),
          ),
        ),
        Text(
          '$count thông báo',
          style: const TextStyle(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w600,
            color: HomeStyle.muted,
          ),
        ),
      ]);
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
      return (Icons.confirmation_number_outlined, HomeStyle.orange);
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
            borderRadius: BorderRadius.circular(AppRadius.card)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              color: item.isRead ? HomeStyle.card : const Color(0xFFFFF8F4),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color:
                    item.isRead ? HomeStyle.divider : const Color(0xFFFFE0D2),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppFontSize.body,
                                    fontWeight: item.isRead
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                    color: item.isRead
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    height: 1.3)),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: const BoxDecoration(
                                  color: HomeStyle.orange,
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ]),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(item.body,
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              color: item.isRead
                                  ? HomeStyle.muted
                                  : AppColors.textSecondary,
                              height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (item.orderCode?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        serviceType != null
                            ? '#$code · ${Fmt.serviceLabel(serviceType)}'
                            : 'Đơn #$code',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted,
                        ),
                      )),
                      if (code?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        const Text('Xem đơn',
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w600,
                                color: HomeStyle.orange)),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: HomeStyle.orange),
                      ],
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: HomeStyle.peach,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 34, color: HomeStyle.orange),
          ),
          const SizedBox(height: 16),
          Text(
              unreadOnly
                  ? 'Không còn thông báo chưa đọc'
                  : 'Chưa có thông báo nào',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
              unreadOnly
                  ? 'Bạn đã cập nhật tất cả thông tin mới.'
                  : 'Thông tin đơn hàng và ưu đãi sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
}
