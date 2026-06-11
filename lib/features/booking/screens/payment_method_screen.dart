import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum PaymentMethod {
  cash,
  zalopay,
  atm,
  vietqr,
  card;

  String get label => switch (this) {
    cash    => 'Tiền mặt',
    zalopay => 'Ví Zalopay',
    atm     => 'Thẻ ATM/ Internet Banking',
    vietqr  => 'QR đa năng',
    card    => 'Visa, Master, JCB',
  };

  IconData get icon => switch (this) {
    cash    => Icons.payments_rounded,
    zalopay => Icons.account_balance_wallet_rounded,
    atm     => Icons.account_balance_rounded,
    vietqr  => Icons.qr_code_2_rounded,
    card    => Icons.credit_card_rounded,
  };

  Color get iconBg => switch (this) {
    cash    => const Color(0xFFE8F8EE),
    zalopay => const Color(0xFFE3F0FF),
    atm     => const Color(0xFFE8F8EE),
    vietqr  => const Color(0xFFFFECEC),
    card    => const Color(0xFFEEF2FF),
  };

  Color get iconColor => switch (this) {
    cash    => const Color(0xFF30D158),
    zalopay => const Color(0xFF0068FF),
    atm     => const Color(0xFF30D158),
    vietqr  => const Color(0xFFE53935),
    card    => const Color(0xFF3D5AFE),
  };

  // Maps to backend values: cod | prepaid | wallet
  String get apiValue => switch (this) {
    cash    => 'cod',
    zalopay => 'prepaid',
    atm     => 'prepaid',
    vietqr  => 'prepaid',
    card    => 'prepaid',
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
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phương thức thanh toán',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Lưu',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),

            // Zalopay "Liên kết" badge
            if (method == PaymentMethod.zalopay) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFCCCCCC),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('+ Liên kết',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 10),
            ],

            // Radio button
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFCCCCCC),
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
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: method.iconBg,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/zalo.png',
            width: 42, height: 42,
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
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: method.iconBg,
        shape: BoxShape.circle,
      ),
      child: Icon(method.icon, color: method.iconColor, size: 22),
    );
  }
}
