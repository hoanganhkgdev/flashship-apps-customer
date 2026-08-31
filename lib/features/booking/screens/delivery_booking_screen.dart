import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';

class DeliveryBookingScreen extends ConsumerStatefulWidget {
  const DeliveryBookingScreen({super.key, this.reorderFrom});

  final OrderModel? reorderFrom;

  @override
  ConsumerState<DeliveryBookingScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryBookingScreen> {
  final _storeNameCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _deliveryPhoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _codCtrl = TextEditingController();

  String? _pickupAddr;
  String? _pickupPlaceName;
  double? _pickupLat;
  double? _pickupLng;
  String? _destAddr;
  String? _destPlaceName;
  double? _destLat;
  double? _destLng;

  int? _fee;
  int _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting = false;
  String? _error;
  String? _voucherCode;
  int _voucherDiscount = 0;
  int? _codAmount;
  String _cargoType = 'standard';

  static const _cargoTypes = [
    ('standard', 'Hàng thường', Icons.inventory_2_outlined),
    ('food', 'Đồ ăn/uống', Icons.restaurant_outlined),
    ('fragile', 'Dễ vỡ', Icons.warning_amber_rounded),
    ('bulky', 'Cồng kềnh', Icons.inventory_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final order = widget.reorderFrom;
    final user = ref.read(authProvider).user;
    _deliveryPhoneCtrl.text = order?.deliveryPhone ?? user?.phone ?? '';
    _destPlaceName = user?.name;
    if (order != null) {
      _pickupAddr = order.pickupAddress;
      _pickupPlaceName = order.pickupPlaceName;
      _pickupLat = order.pickupLat;
      _pickupLng = order.pickupLng;
      _destAddr = order.deliveryAddress;
      _destLat = order.deliveryLat;
      _destLng = order.deliveryLng;
      _storeNameCtrl.text = order.storeName ?? '';
      _storePhoneCtrl.text = order.pickupPhone ?? '';
      _noteCtrl.text = order.orderNote ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    } else {
      _loadCurrentDestination();
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storePhoneCtrl.dispose();
    _deliveryPhoneCtrl.dispose();
    _noteCtrl.dispose();
    _codCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentDestination() async {
    final result = await LocationService.resolveCurrentLocation(context);
    if (result == null || !mounted) return;
    final (position, address) = result;
    setState(() {
      _destLat = position.latitude;
      _destLng = position.longitude;
      _destAddr = address;
    });
  }

  Future<void> _pickAddress({required bool pickup}) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (pickup) {
        _pickupAddr = result.address;
        _pickupPlaceName = result.placeName;
        _pickupLat = result.lat;
        _pickupLng = result.lng;
      } else {
        _destAddr = result.address;
        _destPlaceName = result.placeName ?? ref.read(authProvider).user?.name;
        _destLat = result.lat;
        _destLng = result.lng;
      }
    });
    await _estimate();
  }

  Future<void> _estimate() async {
    if (_pickupAddr == null || _destAddr == null) return;
    setState(() {
      _loadingFee = true;
      _fee = null;
    });
    final params = <String, dynamic>{'service_type': 'delivery'};
    if (_pickupLat != null && _destLat != null) {
      params.addAll({
        'pickup_lat': _pickupLat,
        'pickup_lng': _pickupLng,
        'delivery_lat': _destLat,
        'delivery_lng': _destLng,
      });
    } else {
      params.addAll({
        'pickup_address': _pickupAddr,
        'delivery_address': _destAddr,
      });
    }
    final estimate = await fetchPricingEstimate(ref, params);
    if (!mounted) return;
    if (estimate != null) {
      setState(() {
        _fee = estimate.fee;
        _nightSurcharge = estimate.nightSurcharge;
        _distanceKm = estimate.distanceKm;
      });
    }
    setState(() => _loadingFee = false);
  }

  Future<void> _pickVoucher() async {
    final result = await Navigator.of(context).push<VoucherPickResult>(
      MaterialPageRoute(
        builder: (_) => VoucherPickerScreen(
          serviceType: 'delivery',
          orderFee: _fee,
          appliedCode: _voucherCode,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _voucherCode = result.code.isEmpty ? null : result.code;
        _voucherDiscount = result.discount;
      });
    }
  }

  Future<void> _submit() async {
    if (_pickupAddr == null || _destAddr == null) {
      setState(() => _error = 'Vui lòng chọn điểm lấy và điểm giao');
      return;
    }
    if (_pickupLat == null ||
        _pickupLng == null ||
        _destLat == null ||
        _destLng == null) {
      setState(() => _error = 'Vui lòng chọn lại địa chỉ từ gợi ý hoặc bản đồ');
      return;
    }
    if (_deliveryPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập SĐT người nhận');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await submitBookingOrder(
      ref: ref,
      context: context,
      data: {
        'service_type': 'delivery',
        'pickup_address': _pickupAddr,
        'delivery_address': _destAddr,
        'pickup_lat': _pickupLat,
        'pickup_lng': _pickupLng,
        'delivery_lat': _destLat,
        'delivery_lng': _destLng,
        'delivery_phone': _deliveryPhoneCtrl.text.trim(),
        'receiver_name': ref.read(authProvider).user?.name ?? '',
        if (_storeNameCtrl.text.trim().isNotEmpty)
          'store_name': _storeNameCtrl.text.trim(),
        if (_storePhoneCtrl.text.trim().isNotEmpty)
          'pickup_phone': _storePhoneCtrl.text.trim(),
        if (_noteCtrl.text.trim().isNotEmpty)
          'order_note': _noteCtrl.text.trim(),
        if (_pickupPlaceName?.isNotEmpty == true)
          'pickup_place_name': _pickupPlaceName,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
        'payment_method': 'cod',
        'total_amount': ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0),
        'cod_amount': _codAmount ?? 0,
        'cargo_type': _cargoType,
      },
      onError: (message) {
        if (mounted) {
          setState(() {
            _error = message;
            _submitting = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        toolbarHeight: 70,
        leadingWidth: 60,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => context.pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: _ink),
              ),
            ),
          ),
        ),
        title: Text('Giao hàng',
            style: _style(AppFontSize.display, FontWeight.w600, _ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 28),
              children: [
                _AddressCard(
                  title: 'Điểm lấy hàng',
                  titleIcon: Icons.work_outline_rounded,
                  titleColor: _orange,
                  placeName: _pickupPlaceName,
                  address: _pickupAddr,
                  emptyText: 'Chọn điểm lấy hàng',
                  onAddressTap: () => _pickAddress(pickup: true),
                  fields: [
                    _FormField(
                      controller: _storeNameCtrl,
                      hint: 'Tên điểm lấy (tùy chọn)',
                      icon: Icons.storefront_outlined,
                    ),
                    _FormField(
                      controller: _storePhoneCtrl,
                      hint: 'SĐT điểm lấy (tùy chọn)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AddressCard(
                  title: 'Giao hàng đến',
                  titleIcon: Icons.flag_rounded,
                  titleColor: const Color(0xFFD8323C),
                  placeName: _destPlaceName ?? user?.name,
                  address: _destAddr,
                  emptyText: 'Chọn địa chỉ giao hàng',
                  onAddressTap: () => _pickAddress(pickup: false),
                  fields: [
                    _FormField(
                      controller: _deliveryPhoneCtrl,
                      hint: 'SĐT người nhận',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailsCard(
                  noteController: _noteCtrl,
                  codController: _codCtrl,
                  selectedCargo: _cargoType,
                  cargoTypes: _cargoTypes,
                  onCodChanged: (value) => setState(() {
                    _codAmount = int.tryParse(
                      value.replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                  }),
                  onCargoSelected: (value) =>
                      setState(() => _cargoType = value),
                ),
              ],
            ),
          ),
          _SummaryBar(
            distanceKm: _distanceKm,
            fee: _fee,
            netFee: netFee,
            nightSurcharge: _nightSurcharge,
            loadingFee: _loadingFee,
            voucherCode: _voucherCode,
            error: _error,
            submitting: _submitting,
            onVoucherTap: _pickVoucher,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.titleIcon,
    required this.titleColor,
    required this.placeName,
    required this.address,
    required this.emptyText,
    required this.onAddressTap,
    required this.fields,
  });

  final String title;
  final IconData titleIcon;
  final Color titleColor;
  final String? placeName;
  final String? address;
  final String emptyText;
  final VoidCallback onAddressTap;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _CardHeader(icon: titleIcon, color: titleColor, title: title),
          const Divider(height: 1, color: AppColors.divider),
          InkWell(
            onTap: onAddressTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _IconBox(icon: Icons.location_on_outlined, color: _orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: address == null
                        ? Text(emptyText,
                            style: _style(
                                AppFontSize.bodyLarge, FontWeight.w600, _muted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                placeName?.isNotEmpty == true
                                    ? placeName!
                                    : address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _style(AppFontSize.bodyLarge,
                                    FontWeight.w600, _ink),
                              ),
                              if (placeName?.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _style(AppFontSize.body,
                                      FontWeight.w500, _muted),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _softMuted),
                ],
              ),
            ),
          ),
          for (final field in fields) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: field,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.noteController,
    required this.codController,
    required this.selectedCargo,
    required this.cargoTypes,
    required this.onCodChanged,
    required this.onCargoSelected,
  });

  final TextEditingController noteController;
  final TextEditingController codController;
  final String selectedCargo;
  final List<(String, String, IconData)> cargoTypes;
  final ValueChanged<String> onCodChanged;
  final ValueChanged<String> onCargoSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.subject_rounded,
            color: AppColors.textSecondary,
            title: 'Chi tiết đơn hàng',
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FormField(
                  controller: noteController,
                  hint: 'Ghi chú / mô tả hàng — Loại hàng, yêu cầu đặc biệt...',
                  icon: Icons.description_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onCodChanged,
                  style: _style(AppFontSize.bodyLarge, FontWeight.w600,
                      AppColors.success),
                  decoration: _decoration(
                    'Thu hộ (COD) — Tùy chọn',
                    Icons.payments_outlined,
                    fillColor: const Color(0xFFE6F3E9),
                    iconColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loại hàng',
                    style: _style(AppFontSize.body, FontWeight.w600, _ink)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cargoTypes.map((item) {
                    final (key, label, icon) = item;
                    final selected = key == selectedCargo;
                    return GestureDetector(
                      onTap: () => onCargoSelected(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primarySoft
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                              color: selected ? _orange : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 15, color: selected ? _orange : _muted),
                            const SizedBox(width: 6),
                            Text(label,
                                style: _style(
                                    AppFontSize.caption,
                                    selected
                                        ? FontWeight.w600
                                        : FontWeight.w600,
                                    selected ? _orange : _muted)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.distanceKm,
    required this.fee,
    required this.netFee,
    required this.nightSurcharge,
    required this.loadingFee,
    required this.voucherCode,
    required this.error,
    required this.submitting,
    required this.onVoucherTap,
    required this.onSubmit,
  });

  final double? distanceKm;
  final int? fee;
  final int netFee;
  final int nightSurcharge;
  final bool loadingFee;
  final String? voucherCode;
  final String? error;
  final bool submitting;
  final VoidCallback onVoucherTap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.inventory_2_outlined, color: _orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giao hàng',
                        style: _style(
                            AppFontSize.bodyLarge, FontWeight.w600, _ink)),
                    if (distanceKm != null)
                      Text('${distanceKm!.toStringAsFixed(1)} km',
                          style: _style(
                              AppFontSize.caption, FontWeight.w500, _muted)),
                  ],
                ),
              ),
              if (loadingFee)
                const CircularProgressIndicator(strokeWidth: 2, color: _orange)
              else
                Row(
                  children: [
                    if (fee != null && fee! > netFee) ...[
                      Text(Fmt.currency(fee!),
                          style: _style(
                                  AppFontSize.body, FontWeight.w500, _softMuted)
                              .copyWith(
                                  decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 7),
                    ],
                    Text(fee == null ? '—' : Fmt.currency(netFee),
                        style: _style(AppFontSize.display, FontWeight.w600,
                            fee == null ? _softMuted : _orange)),
                  ],
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.divider),
          ),
          InkWell(
            onTap: onVoucherTap,
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 18, color: _orange),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(voucherCode ?? 'Chọn ưu đãi',
                        style: _style(AppFontSize.body, FontWeight.w600,
                            voucherCode == null ? _muted : _orange))),
                const Icon(Icons.chevron_right_rounded, color: _softMuted),
              ],
            ),
          ),
          if (nightSurcharge > 0) ...[
            const SizedBox(height: 6),
            Align(
                alignment: Alignment.centerRight,
                child: Text('+${Fmt.currency(nightSurcharge)} phụ phí đêm',
                    style: _style(AppFontSize.caption, FontWeight.w600,
                        AppColors.warning))),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(error!,
                      style: _style(AppFontSize.caption, FontWeight.w500,
                          AppColors.danger))),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                  backgroundColor: _orange, shape: const StadiumBorder()),
              child: submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Đặt giao hàng ngay',
                      style: _style(AppFontSize.bodyLarge, FontWeight.w600,
                          Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(
      {required this.icon, required this.color, required this.title});
  final IconData icon;
  final Color color;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: Colors.white)),
          const SizedBox(width: 12),
          Text(title,
              style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink)),
        ]),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Icon(icon, size: 20, color: color),
      );
}

class _FormField extends StatelessWidget {
  const _FormField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.keyboardType,
      this.maxLines = 1});
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
        decoration: _decoration(hint, icon),
      );
}

InputDecoration _decoration(String hint, IconData icon,
        {Color fillColor = AppColors.surfaceAlt, Color iconColor = _muted}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: _style(AppFontSize.bodyLarge, FontWeight.w500, _softMuted),
      prefixIcon: Icon(icon, size: 19, color: iconColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: _orange, width: 1.5)),
    );

const _ink = AppColors.textPrimary;
const _muted = AppColors.textSecondary;
const _softMuted = AppColors.textTertiary;
const _orange = AppColors.primary;

TextStyle _style(double size, [FontWeight? weight, Color? color]) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color);
