import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'home_style.dart';

class NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const NavItem(this.on, this.off, this.label);
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;
  const BottomNav(
      {super.key,
      required this.currentIndex,
      required this.unreadCount,
      required this.onTap});

  // Scaffold dùng extendBody nên không tự chừa chỗ cho thanh nav — các tab
  // phải tự chừa khoảng này.
  static bool _wrapLabels(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
      (MediaQuery.sizeOf(context).width < 360 &&
          MediaQuery.textScalerOf(context).scale(1) > 1.2);

  static double _barHeight(BuildContext context) {
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) *
            1.15 *
            (_wrapLabels(context) ? 2 : 1);
    final height = 32 + 4 + labelHeight + 16;
    return height < 72 ? 72 : height;
  }

  static double reservedHeight(BuildContext context) =>
      _barHeight(context) + 16 + MediaQuery.paddingOf(context).bottom;

  static const _tabs = [
    NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    NavItem(
        Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Đơn hàng'),
    NavItem(
        Icons.notifications_rounded, Icons.notifications_outlined, 'Thông báo'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  List<Widget> _buildTabs(BuildContext context) =>
      List.generate(_tabs.length, (i) {
        final tab = _tabs[i];
        final selected = currentIndex == i;
        final color = selected ? HomeStyle.orange : HomeStyle.muted;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              selected: selected,
              button: true,
              label:
                  '${tab.label}${i == 2 && unreadCount > 0 ? ', $unreadCount chưa đọc' : ''}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: double.infinity,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 48,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? HomeStyle.peach
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Badge(
                              isLabelVisible: i == 2 && unreadCount > 0,
                              backgroundColor: AppColors.danger,
                              label: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Icon(
                                selected ? tab.on : tab.off,
                                color: color,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            textAlign: TextAlign.center,
                            maxLines: _wrapLabels(context) ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFontSize.caption,
                              height: 1.15,
                              color: color,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            height: _barHeight(context),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: HomeStyle.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: HomeStyle.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D101828),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: _buildTabs(context)),
          ),
        ),
      );
}
