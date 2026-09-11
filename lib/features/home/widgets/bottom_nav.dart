import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
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

  // Scaffold dùng extendBody nên không tự chừa chỗ cho thanh nav nổi (để
  // nền kính lỏng xuyên suốt phía sau) — các tab phải tự chừa khoảng này.
  static double reservedHeight(BuildContext context) =>
      84 + MediaQuery.paddingOf(context).bottom;

  static const _tabs = [
    NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    NavItem(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Lịch sử'),
    NavItem(
        Icons.notifications_rounded, Icons.notifications_outlined, 'Thông báo'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  List<Widget> _buildTabs() => List.generate(_tabs.length, (i) {
        final tab = _tabs[i];
        final selected = currentIndex == i;
        final color = selected ? HomeStyle.orange : HomeStyle.muted;
        return Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            label:
                '${tab.label}${i == 2 && unreadCount > 0 ? ', $unreadCount chưa đọc' : ''}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(AppRadius.glass),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 58),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: i == 2 && unreadCount > 0,
                          backgroundColor: AppColors.danger,
                          label: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.glass),
                              gradient: selected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: .68),
                                        HomeStyle.orange.withValues(alpha: .18),
                                      ],
                                    )
                                  : null,
                              border: selected
                                  ? Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .82))
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: HomeStyle.orange
                                            .withValues(alpha: .12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(selected ? tab.on : tab.off,
                                color: color, size: 22),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            height: 1.1,
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
        );
      });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: LiquidGlass(
            borderRadius: BorderRadius.circular(AppRadius.glass),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(children: _buildTabs()),
          ),
        ),
      );
}
