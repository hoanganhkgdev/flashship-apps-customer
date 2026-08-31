import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum PaymentMethod {
  cash,
  zalopay,
  atm,
  vietqr,
  card;

  String get label => switch (this) {
        cash => 'Tiền mặt',
        zalopay => 'Ví Zalopay',
        atm => 'Thẻ ATM/ Internet Banking',
        vietqr => 'QR đa năng',
        card => 'Visa, Master, JCB',
      };

  IconData get icon => switch (this) {
        cash => Icons.payments_rounded,
        zalopay => Icons.account_balance_wallet_rounded,
        atm => Icons.account_balance_rounded,
        vietqr => Icons.qr_code_2_rounded,
        card => Icons.credit_card_rounded,
      };

  Color get iconBg => switch (this) {
        cash => AppColors.successSoft,
        zalopay => const Color(0xFFE3F0FF),
        atm => AppColors.successSoft,
        vietqr => const Color(0xFFFFECEC),
        card => const Color(0xFFEEF2FF),
      };

  Color get iconColor => switch (this) {
        cash => AppColors.success,
        zalopay => const Color(0xFF0068FF),
        atm => AppColors.success,
        vietqr => const Color(0xFFE53935),
        card => const Color(0xFF3D5AFE),
      };

  // Maps to backend values: cod | prepaid | wallet
  String get apiValue => switch (this) {
        cash => 'cod',
        zalopay => 'prepaid',
        atm => 'prepaid',
        vietqr => 'prepaid',
        card => 'prepaid',
      };
}

class PaymentMethodScreen extends StatefulWidget {
  final PaymentMethod selected;
  const PaymentMethodScreen({super.key, required this.selected});

  @override
  State<PaymentMethodScreen> createState() => _State();
}

class _State extends State<PaymentMethodScreen> {
  late PaymentMethod _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 60,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        title: const Text('Phương thức thanh toán',
            style: TextStyle(fontSize: AppFontSize.display, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Lưu',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 12),
        color: Colors.white,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: PaymentMethod.values.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, endIndent: 0),
          itemBuilder: (_, i) {
            final m = PaymentMethod.values[i];
            return _PaymentTile(
              method: m,
              isSelected: m == _selected,
              onTap: () => setState(() => _selected = m),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            _buildIcon(),
            const SizedBox(width: 14),

            // Label
            Expanded(
              child: Text(
                method.label,
                style:
                    const TextStyle(fontSize: AppFontSize.bodyLarge, fontWeight: FontWeight.w500),
              ),
            ),

            // Zalopay "Liên kết" badge
            if (method == PaymentMethod.zalopay) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.textTertiary, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('+ Liên kết',
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 10),
            ],

            // Radio button
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.textTertiary,
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (method == PaymentMethod.zalopay) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: method.iconBg,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/zalo.png',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              method.icon,
              color: method.iconColor,
              size: 22,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: method.iconBg,
        shape: BoxShape.circle,
      ),
      child: Icon(method.icon, color: method.iconColor, size: 22),
    );
  }
}
