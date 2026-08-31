import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart' show Fmt;
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

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
          ? 'HÔM NAY'
          : date == today.subtract(const Duration(days: 1))
              ? 'HÔM QUA'
              : Fmt.date(date).toUpperCase();
      groups.putIfAbsent(label, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text('Thông báo',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: Text('Đánh dấu đã đọc',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).fetchFromServer(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
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
                          padding: const EdgeInsets.only(bottom: 12),
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
            ),
    );
  }
}

// ── Notification row ──────────────────────────────────────────────────────────

class _NotifRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifRow({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  (IconData, Color) get _meta {
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
  Widget build(BuildContext context) {
    final (icon, iconColor) = _meta;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.createdAt.toLocal()),
      alwaysUse24HourFormat: true,
    );
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: AppColors.danger.withValues(alpha: 0.08),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(item.title,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600,
                              color: item.isRead
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              height: 1.3)),
                    ),
                    if (!item.isRead) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(item.body,
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          color: item.isRead
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(time,
                      style: TextStyle(
                          fontSize: AppFontSize.body, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ]),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có thông báo nào',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Thông báo mới sẽ xuất hiện tại đây',
              style: TextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
}
