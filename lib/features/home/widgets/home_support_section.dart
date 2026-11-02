part of '../screens/home_screen.dart';

class _HomeSupportSection extends ConsumerWidget {
  const _HomeSupportSection();

  Future<void> _open(BuildContext context, SupportItem item) async {
    final raw = item.value.trim();
    if (raw.isEmpty) return;
    final type = item.type.toLowerCase();
    final Uri? uri;
    if (type == 'phone' || type == 'hotline') {
      uri = Uri(scheme: 'tel', path: raw);
    } else if (type == 'email') {
      uri = Uri(scheme: 'mailto', path: raw);
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      uri = Uri.tryParse(raw);
    } else if (type == 'zalo' || type == 'chat') {
      uri = Uri.tryParse('https://zalo.me/$raw');
    } else {
      uri = Uri.tryParse('https://$raw');
    }
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa mở được kênh hỗ trợ này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supportProvider);
    final items = state.valueOrNull ?? [];
    final loading = state.isLoading && items.isEmpty;
    if (!loading && items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(2).toList();

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
                      TextSpan(text: 'Bạn cần '),
                      TextSpan(
                        text: 'hỗ trợ?',
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
                      Icons.headset_mic_rounded,
                      size: 15,
                      color: HomeStyle.orange,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Liên hệ với Flash Ship',
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
          ]),
          const SizedBox(height: 12),
          if (loading)
            const _SupportListSkeleton()
          else
            Container(
              decoration: BoxDecoration(
                color: HomeStyle.card,
                borderRadius: HomeStyle.cardRadius,
                border: Border.all(color: HomeStyle.divider),
              ),
              child: Column(children: [
                for (var index = 0; index < shown.length; index++) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 14,
                      color: HomeStyle.divider,
                    ),
                  _SupportQuickTile(
                    item: shown[index],
                    onTap: () => _open(context, shown[index]),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _SupportQuickTile extends StatelessWidget {
  const _SupportQuickTile({required this.item, required this.onTap});

  final SupportItem item;
  final VoidCallback onTap;

  IconData get _icon => switch (item.type.toLowerCase()) {
        'phone' || 'hotline' => Icons.call_rounded,
        'zalo' || 'chat' => Icons.chat_bubble_rounded,
        'email' => Icons.mail_rounded,
        _ => Icons.language_rounded,
      };

  Color get _color => switch (item.type.toLowerCase()) {
        'phone' || 'hotline' => HomeStyle.orange,
        'zalo' || 'chat' => const Color(0xFF0068FF),
        'email' => const Color(0xFF7C5CFC),
        _ => AppColors.accent2,
      };

  String get _action => switch (item.type.toLowerCase()) {
        'phone' || 'hotline' => 'Gọi ngay',
        'zalo' || 'chat' => 'Mở chat',
        'email' => 'Gửi email',
        _ => 'Mở trang',
      };

  String get _subtitle {
    if (item.subtitle?.trim().isNotEmpty == true) return item.subtitle!.trim();
    return switch (item.type.toLowerCase()) {
      'phone' || 'hotline' || 'email' => item.value,
      'zalo' || 'chat' => 'Nhắn tin với FlashShip',
      _ => 'Xem thông tin hỗ trợ',
    };
  }

  @override
  Widget build(BuildContext context) {
    final compactAction = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) > 16;
    return Semantics(
      button: true,
      label: '$_action: ${item.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: HomeStyle.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
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
                      _subtitle,
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
                width: compactAction ? 36 : null,
                height: 36,
                alignment: Alignment.center,
                padding: compactAction
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: compactAction
                    ? Icon(Icons.chevron_right_rounded, size: 19, color: _color)
                    : Text(
                        '$_action  ›',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: _color,
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SupportListSkeleton extends StatelessWidget {
  const _SupportListSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: HomeStyle.cardRadius,
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Column(children: [
          for (var index = 0; index < 2; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 12,
                  color: const Color(0xFFEDEFF3),
                ),
              ),
            ]),
          ],
        ]),
      );
}
