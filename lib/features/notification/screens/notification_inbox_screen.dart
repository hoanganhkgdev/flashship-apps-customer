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
    final state       = ref.watch(notificationProvider);
    final items       = state.items;
    final unreadCount = items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(children: [
          const Text('Thông báo',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$unreadCount',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ]),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Đọc tất cả',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).fetchFromServer(),
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                children: [
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: items.asMap().entries.map((e) {
                        final i    = e.key;
                        final item = e.value;
                        return Column(children: [
                          _NotifRow(
                            item: item,
                            onTap: () {
                              ref.read(notificationProvider.notifier)
                                  .markRead(item.id);
                              if (item.orderCode != null) {
                                context.push('/order/${item.orderCode}');
                              }
                            },
                            onDismiss: () => ref
                                .read(notificationProvider.notifier)
                                .delete(item.id),
                          ),
                          if (i < items.length - 1)
                            const Divider(height: 1, indent: 70,
                                color: Color(0xFFF5F5F5)),
                        ]);
                      }).toList(),
                    ),
                  ),

                  // ── Xem thêm ────────────────────────────────────────────
                  if (state.hasMore || state.isLoadingMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: state.isLoadingMore
                          ? const Center(
                              child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(notificationProvider.notifier)
                                  .loadMore(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(
                                    color: AppColors.divider),
                              ),
                              child: const Text('Xem thêm',
                                  style: TextStyle(
                                      fontSize: 14,
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

  IconData get _icon => item.orderCode != null
      ? Icons.local_shipping_outlined
      : Icons.campaign_outlined;

  Color get _iconColor => item.orderCode != null
      ? AppColors.primary
      : const Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
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
        child: Container(
          color: item.isRead
              ? Colors.white
              : AppColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20, color: _iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(item.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w500 : FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3)),
                    ),
                    const SizedBox(width: 8),
                    Text(Fmt.timeAgo(item.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Text(item.body,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (item.orderCode != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 10, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Xem đơn #${item.orderCode}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ]),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
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
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_none_rounded,
            size: 40, color: AppColors.primary),
      ),
      const SizedBox(height: 16),
      const Text('Chưa có thông báo nào',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Thông báo mới sẽ xuất hiện tại đây',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );
}
