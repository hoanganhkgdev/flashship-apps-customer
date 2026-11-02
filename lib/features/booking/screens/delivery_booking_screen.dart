import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/providers/service_type_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../home/widgets/home_style.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/delivery_receiver_card.dart';
import 'widgets/delivery_route_card.dart';
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
  bool _phoneError = false;
  String? _voucherCode;
  int _voucherDiscount = 0;
  int? _advanceAmount;
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
      setState(() {
        _phoneError = true;
        _error = 'Vui lòng nhập SĐT người nhận';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _phoneError = false;
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
        'cargo_type': 'standard',
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

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFFFE9DE),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        leadingWidth: 72,
        centerTitle: false,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: HomeStyle.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: HomeStyle.ink),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink)),
              const SizedBox(height: 3),
              const Text('Lấy hàng giúp bạn, giao tận nơi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.caption, color: HomeStyle.muted)),
            ],
          ),
        ),
      ),
      body: Builder(
        builder: (bodyContext) => ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16,
              MediaQuery.paddingOf(bodyContext).bottom + bottomInset + 28),
          children: [
            _DeliveryGuideCard(
              pickupSelected: _pickupAddr?.trim().isNotEmpty == true,
              destSelected: _destAddr?.trim().isNotEmpty == true,
            ),
            const SizedBox(height: 16),
            DeliveryRouteCard(
              pickupPlaceName: _pickupPlaceName,
              pickupAddress: _pickupAddr,
              destAddress: _destAddr,
              onPickupTap: () => _pickAddress(pickup: true),
              onDestTap: () => _pickAddress(pickup: false),
            ),
            const SizedBox(height: 16),
            DeliveryReceiverCard(
              nameController: _receiverNameCtrl,
              phoneController: _deliveryPhoneCtrl,
              showPhoneError: _phoneError,
            ),
            const SizedBox(height: 16),
            DeliveryDetailsCard(
              noteController: _noteCtrl,
              advanceController: _advanceCtrl,
              storeNameController: _storeNameCtrl,
              storePhoneController: _storePhoneCtrl,
              onAdvanceChanged: (value) => setState(() {
                _advanceAmount = int.tryParse(
                  value.replaceAll(RegExp(r'[^0-9]'), ''),
                );
              }),
            ),
            const SizedBox(height: 16),
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
        buttonLabel: 'Đặt lấy đồ hộ',
        feeLabel: 'Cước dịch vụ',
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
    );
  }
}

class _DeliveryGuideCard extends StatelessWidget {
  const _DeliveryGuideCard({
    required this.pickupSelected,
    required this.destSelected,
  });

  final bool pickupSelected;
  final bool destSelected;

  static const _steps = [
    (Icons.inventory_2_outlined, 'Chọn điểm lấy'),
    (Icons.location_on_outlined, 'Chọn điểm giao'),
    (Icons.receipt_long_outlined, 'Xác nhận đơn'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
        decoration: BoxDecoration(
          color: HomeStyle.peach,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.route_outlined, size: 18, color: HomeStyle.orange),
            SizedBox(width: 7),
            Expanded(
              child: Text('Lấy hộ, giao tận nơi',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                return const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 17),
                    child: Divider(height: 1, color: Color(0xFFFFCBB5)),
                  ),
                );
              }
              final step = index ~/ 2;
              final (icon, label) = _steps[step];
              final done =
                  step == 0 ? pickupSelected : step == 1 && destSelected;
              return Expanded(
                flex: 4,
                child: Column(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done ? HomeStyle.orange : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(done ? Icons.check_rounded : icon,
                        size: 18,
                        color: done ? Colors.white : HomeStyle.orange),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: HomeStyle.muted)),
                ]),
              );
            }),
          ),
        ]),
      );
}
