import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// AppColors (customer) chưa có textTertiary như app tài xế — dùng lại màu xám
// trung tính từng dùng cho tab chưa chọn ở _BottomNav cũ.
const _unselectedColor = Color(0xFF9E9E9E);

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
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  // Scaffold dùng extendBody: true (để BackdropFilter có nội dung thật phía
  // sau mà làm mờ) — mỗi tab tự chừa khoảng trống nhỏ này ở cuối nội dung
  // cuộn, CHỈ đủ để không bị cắt cụt hẳn, KHÔNG chừa hết cả chiều cao thanh
  // nav — cố tình để phần cuối content vẫn cuộn ra sau toàn bộ thanh nav
  // (kể cả vùng safe-area dưới), thấy rõ hiệu ứng kính mờ toàn dải thay vì
  // chỉ toàn nền trơn phía sau.
  static double reservedHeight(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 8;

  static const _tabs = [
    NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    NavItem(Icons.history_rounded, Icons.history_outlined, 'Hoạt động'),
    NavItem(
        Icons.notifications_rounded, Icons.notifications_outlined, 'Thông báo'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottom + 9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final selected = i == currentIndex;
          final showBadge = i == 2 && unreadCount > 0;
          final color = selected ? AppColors.primary : _unselectedColor;

          return Expanded(
            child: InkResponse(
              onTap: () => onTap(i),
              radius: 30,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 42,
                    height: 28,
                    child: Center(
                      child: showBadge
                          ? Badge(
                              label: Text('$unreadCount',
                                  style: const TextStyle(fontSize: AppFontSize.caption)),
                              child: Icon(selected ? tab.on : tab.off,
                                  size: 23, color: color),
                            )
                          : Icon(selected ? tab.on : tab.off,
                              size: 23, color: color),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
