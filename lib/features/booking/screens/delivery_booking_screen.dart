import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/providers/service_type_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/delivery_details_card.dart';
import 'widgets/booking_summary_bar.dart';
import 'widgets/delivery_voucher_card.dart';

class DeliveryBookingScreen extends ConsumerStatefulWidget {
  const DeliveryBookingScreen({super.key, this.reorderFrom});

  final OrderModel? reorderFrom;

  @override
  ConsumerState<DeliveryBookingScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryBookingScreen> {
  final _storeNameCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _receiverNameCtrl = TextEditingController();
  final _deliveryPhoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();

  String? _pickupAddr;
  String? _pickupPlaceName;
  double? _pickupLat;
  double? _pickupLng;
  String? _destAddr;
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
  int? _advanceAmount;
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
    _receiverNameCtrl.text = order?.receiverName ?? user?.name ?? '';
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
    _receiverNameCtrl.dispose();
    _deliveryPhoneCtrl.dispose();
    _noteCtrl.dispose();
    _advanceCtrl.dispose();
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
    if (_fee == null || _loadingFee) return;
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
        'receiver_name': _receiverNameCtrl.text.trim(),
        if (_storeNameCtrl.text.trim().isNotEmpty)
          'store_name': _storeNameCtrl.text.trim(),
        if (_storePhoneCtrl.text.trim().isNotEmpty)
          'pickup_phone': _storePhoneCtrl.text.trim(),
        if (_noteCtrl.text.trim().isNotEmpty || (_advanceAmount ?? 0) > 0)
          'order_note': [
            if ((_advanceAmount ?? 0) > 0)
              'Tài xế chuẩn bị ${Fmt.currency(_advanceAmount!)} để trả shop khi lấy hàng.',
            if (_noteCtrl.text.trim().isNotEmpty) _noteCtrl.text.trim(),
          ].join('\n'),
        if (_pickupPlaceName?.isNotEmpty == true)
          'pickup_place_name': _pickupPlaceName,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
        'payment_method': 'cod',
        'total_amount': ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0),
        'cod_amount': 0,
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
    final services = ref.watch(serviceTypeProvider).valueOrNull;
    final serviceName = services
            ?.where((service) => service.key == 'delivery')
            .map((service) => service.label.trim())
            .where((label) => label.isNotEmpty)
            .firstOrNull ??
        serviceDefOf('delivery').label;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);

    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          leadingWidth: 72,
          centerTitle: false,
          titleSpacing: 0,
          flexibleSpace: const LiquidGlass(
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(AppRadius.glass)),
            child: SizedBox.expand(),
          ),
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .35),
                side: BorderSide(color: Colors.white.withValues(alpha: .7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.glass)),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _ink),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(serviceName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _style(AppFontSize.titleLarge, FontWeight.w600, _ink)),
          ),
        ),
        body: Builder(
          builder: (bodyContext) => ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                MediaQuery.paddingOf(bodyContext).bottom + bottomInset + 28),
            children: [
              DeliveryAddressCard(
                placeName: _pickupPlaceName,
                address: _pickupAddr,
                nameController: _storeNameCtrl,
                phoneController: _storePhoneCtrl,
                onAddressTap: () => _pickAddress(pickup: true),
              ),
              const SizedBox(height: 14),
              DeliveryAddressCard(
                isPickup: false,
                placeName: null,
                address: _destAddr,
                nameController: _receiverNameCtrl,
                phoneController: _deliveryPhoneCtrl,
                onAddressTap: () => _pickAddress(pickup: false),
              ),
              const SizedBox(height: 14),
              DeliveryDetailsCard(
                noteController: _noteCtrl,
                advanceController: _advanceCtrl,
                selectedCargo: _cargoType,
                cargoTypes: _cargoTypes,
                onAdvanceChanged: (value) => setState(() {
                  _advanceAmount = int.tryParse(
                    value.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                }),
                onCargoSelected: (value) => setState(() => _cargoType = value),
              ),
              const SizedBox(height: 14),
              DeliveryVoucherCard(
                code: _voucherCode,
                discount: _voucherDiscount,
                onTap: _fee != null && !_loadingFee ? _pickVoucher : null,
                onRemove: () => setState(() {
                  _voucherCode = null;
                  _voucherDiscount = 0;
                }),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BookingSummaryBar(
          serviceName: serviceName,
          canEstimate: _pickupAddr != null && _destAddr != null,
          onRetry: _estimate,
          distanceKm: _distanceKm,
          fee: _fee,
          netFee: netFee,
          nightSurcharge: _nightSurcharge,
          loadingFee: _loadingFee,
          error: _error,
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ),
    );
  }
}

const _ink = AppColors.textPrimary;

TextStyle _style(double size, [FontWeight? weight, Color? color]) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color);
