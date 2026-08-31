part of '../screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();
  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  String _version = '';
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportProvider.future).ignore();
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn tài khoản và toàn bộ dữ liệu của bạn. '
          'Không thể hoàn tác sau khi xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa tài khoản',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).delete('/customer/account');
    } catch (_) {}
    if (!mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider).orders;
    final vouchers = ref.watch(voucherProvider).valueOrNull ?? [];
    final topPadding = MediaQuery.of(context).padding.top;
    final completedOrders = orders.where((o) => o.isCompleted).length;

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 18),
            child: Column(children: [
              Row(children: [
                Text('Hồ sơ',
                    style: TextStyle(
                        fontSize: AppFontSize.display,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user?.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: user!.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              _ProfileInitials(user.initials),
                          errorWidget: (_, __, ___) =>
                              _ProfileInitials(user.initials),
                        )
                      : _ProfileInitials(user?.initials ?? 'U'),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Khách hàng',
                        style: TextStyle(
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                        '${user?.phone ?? ''}${user?.cityName?.isNotEmpty == true ? ' · ${user!.cityName}' : ''}',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            color: AppColors.textSecondary)),
                  ],
                )),
                _MemberBadge(completedOrders: completedOrders),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(children: [
              Expanded(
                  child: _ProfileStatCard(
                label: 'Đơn hoàn thành',
                value: '$completedOrders',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                onTap: () => context.push('/stats'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _ProfileStatCard(
                label: 'Ưu đãi',
                value: '${vouchers.length}',
                icon: Icons.confirmation_number_outlined,
                color: AppColors.primary,
                onTap: () => context.push('/vouchers'),
              )),
            ]),
          ),

          // ── Tài khoản ─────────────────────────────────────────────────
          _SettingsSection(
            header: 'Tài khoản của tôi',
            rows: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFFF6B35),
                label: 'Chỉnh sửa thông tin',
                onTap: () => context.push('/profile/edit'),
              ),
              _SettingsRow(
                icon: Icons.location_on_outlined,
                iconBg: AppColors.info,
                label: 'Địa chỉ đã lưu',
                onTap: () => context.push('/profile/addresses'),
              ),
              _SettingsRow(
                icon: Icons.star_border_rounded,
                iconBg: AppColors.warning,
                label: 'Điểm thưởng',
                trailing: Text('$completedOrders điểm',
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                onTap: () => context.push('/stats'),
              ),
              _SettingsRow(
                icon: Icons.local_offer_outlined,
                iconBg: AppColors.success,
                label: 'Ưu đãi của bạn',
                trailing: vouchers.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text('${vouchers.length}',
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      )
                    : null,
                onTap: () => context.push('/vouchers'),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                iconBg: const Color(0xFF8B5CF6),
                label: 'Đổi mật khẩu',
                onTap: () => context.push('/profile/change-password'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Hỗ trợ & Pháp lý ─────────────────────────────────────────
          _SettingsSection(
            header: 'Pháp lý',
            rows: [
              _SettingsRow(
                icon: Icons.shield_outlined,
                iconBg: const Color(0xFF6366F1),
                label: 'Chính sách quyền riêng tư',
                onTap: () => context.push(
                    '/legal/privacy-policy?title=Chính sách quyền riêng tư'),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFF64748B),
                label: 'Điều khoản sử dụng',
                onTap: () => context
                    .push('/legal/terms-of-service?title=Điều khoản sử dụng'),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFF94A3B8),
                label: 'Phiên bản',
                trailing: Text(
                  _version.isEmpty ? '...' : _version,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSize.body),
                ),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Đăng xuất + Xóa tài khoản ────────────────────────────────
          _SettingsSection(
            header: 'Tài khoản',
            rows: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconBg: AppColors.danger.withValues(alpha: 0.15),
                iconColor: AppColors.danger,
                label: 'Đăng xuất',
                labelColor: AppColors.danger,
                showChevron: false,
                onTap: _confirmLogout,
              ),
              _SettingsRow(
                icon: Icons.delete_forever_outlined,
                iconBg: AppColors.danger.withValues(alpha: 0.15),
                iconColor: AppColors.danger,
                label: _deleting ? 'Đang xóa...' : 'Xóa tài khoản',
                labelColor: AppColors.danger,
                showChevron: false,
                onTap: _deleting ? null : _confirmDelete,
              ),
            ],
          ),

          const SizedBox(height: 28),
          Center(
              child: Text('Flash Ship',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      color: AppColors.textTertiary))),
          SizedBox(height: 48 + BottomNav.reservedHeight(context)),
        ],
      ),
    );
  }
}

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      );
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.divider),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary))),
            ]),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: AppFontSize.display,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
        ),
      );
}

// ── Member badge ──────────────────────────────────────────────────────────────

class _MemberBadge extends StatelessWidget {
  final int completedOrders;
  const _MemberBadge({required this.completedOrders});

  (IconData, String) get _tier => switch (completedOrders) {
        >= 50 => (Icons.workspace_premium_rounded, 'Khách VIP'),
        >= 20 => (Icons.star_rounded, 'Thân thiết'),
        >= 5 => (Icons.star_rounded, 'Thường xuyên'),
        _ => (Icons.person_outline_rounded, 'Thành viên mới'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _tier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ]),
    );
  }
}

// ── Settings section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String? header;
  final List<_SettingsRow> rows;
  const _SettingsSection({this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 9),
          child: Text(
            header!,
            style: TextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.3),
          ),
        ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final isLast = i == rows.length - 1;
              return Column(children: [
                row,
                if (!isLast) const Divider(height: 1, color: AppColors.divider),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ── Single settings row ───────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconBg;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.iconBg,
    this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            SizedBox(
                width: 26,
                child: Icon(icon,
                    size: 20,
                    color: iconColor ?? iconBg ?? AppColors.textSecondary)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? AppColors.textPrimary)),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 22),
          ]),
        ),
      ),
    );
  }
}
