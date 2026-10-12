import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/booking_summary_bar.dart';
import 'widgets/delivery_voucher_card.dart';
import 'widgets/delivery_address_card.dart';
import '../../home/providers/service_type_provider.dart';
import '../../../core/constants/app_constants.dart';

class _ShopStop {
  String? address;
  String? placeName;
  double? lat, lng;
  final TextEditingController descCtrl = TextEditingController();

  void dispose() {
    descCtrl.dispose();
  }
}

class ShoppingBookingScreen extends ConsumerStatefulWidget {
  final OrderModel? reorderFrom;
  const ShoppingBookingScreen({super.key, this.reorderFrom});

  @override
  ConsumerState<ShoppingBookingScreen> createState() => _State();
}

class _State extends ConsumerState<ShoppingBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receiverNameCtrl = TextEditingController();
  final _deliveryPhoneCtrl = TextEditingController();
  final List<_ShopStop> _stops = [_ShopStop()];

  String? _deliveryAddr;
  double? _deliveryLat, _deliveryLng;

  int? _fee;
  int _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting = false;
  String? _error;
  int _voucherDiscount = 0;
  String? _voucherCode;

  @override
  void initState() {
    super.initState();
    final reorder = widget.reorderFrom;
    _receiverNameCtrl.text =
        reorder?.receiverName ?? ref.read(authProvider).user?.name ?? '';
    if (reorder != null) {
      _deliveryAddr = reorder.deliveryAddress;
      _deliveryLat = reorder.deliveryLat;
      _deliveryLng = reorder.deliveryLng;
      _deliveryPhoneCtrl.text = reorder.deliveryPhone ?? '';
      _stops.first.address = reorder.pickupAddress;
      _stops.first.lat = reorder.pickupLat;
      _stops.first.lng = reorder.pickupLng;
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    } else {
      final user = ref.read(authProvider).user;
      if (user != null) _deliveryPhoneCtrl.text = user.phone;
      _loadGps();
    }
  }

  Future<void> _loadGps() async {
    final result = await LocationService.resolveCurrentLocation(context);
    if (result == null || !mounted) return;
    final (pos, addr) = result;
    _deliveryLat = pos.latitude;
    _deliveryLng = pos.longitude;
    if (addr != null) setState(() => _deliveryAddr = addr);
  }

  @override
  void dispose() {
    for (final s in _stops) {
      s.dispose();
    }
    _receiverNameCtrl.dispose();
    _deliveryPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final first = _stops.first;
    if (first.address == null || _deliveryAddr == null) return;
    setState(() {
      _loadingFee = true;
      _fee = null;
    });
    final params = <String, dynamic>{
      'service_type': 'shopping',
      'stop_count': _stops.length,
    };
    if (first.lat != null &&
        first.lng != null &&
        _deliveryLat != null &&
        _deliveryLng != null) {
      params['pickup_lat'] = first.lat;
      params['pickup_lng'] = first.lng;
      params['delivery_lat'] = _deliveryLat;
      params['delivery_lng'] = _deliveryLng;
    } else {
      params['pickup_address'] = first.address;
      params['delivery_address'] = _deliveryAddr;
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

  void _addStop() {
    if (_stops.length >= 5) return;
    setState(() => _stops.add(_ShopStop()));
    _estimate();
  }

  void _removeStop(int index) {
    if (_stops.length <= 1) return;
    setState(() {
      _stops[index].dispose();
      _stops.removeAt(index);
    });
    _estimate();
  }

  Future<void> _pickStopAddress(int index) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _stops[index].address = result.address;
      _stops[index].placeName = result.placeName;
      _stops[index].lat = result.lat;
      _stops[index].lng = result.lng;
    });
    _estimate();
  }

  Future<void> _pickDeliveryAddress() async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _deliveryAddr = result.address;
      _deliveryLat = result.lat;
      _deliveryLng = result.lng;
    });
    _estimate();
  }

  Future<void> _showVoucherSheet() async {
    if (_fee == null || _loadingFee) return;
    final result = await Navigator.of(context).push<VoucherPickResult>(
      MaterialPageRoute(
        builder: (_) => VoucherPickerScreen(
          serviceType: 'shopping',
          orderFee: _fee,
          appliedCode: _voucherCode,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _voucherCode = result.code.isEmpty ? null : result.code;
        _voucherDiscount = result.discount;
      });
    }
  }

  String _buildNote() {
    if (_stops.length == 1) {
      return _stops.first.descCtrl.text.trim();
    }
    final buf = StringBuffer();
    for (var i = 0; i < _stops.length; i++) {
      final s = _stops[i];
      final name = s.placeName ?? s.address ?? '';
      final desc = s.descCtrl.text.trim();
      buf.writeln('=== Điểm ${i + 1}: $name ===');
      if (s.placeName != null && s.address != null) {
        buf.writeln(s.address!);
      }
      if (desc.isNotEmpty) buf.writeln(desc);
      if (i < _stops.length - 1) buf.writeln();
    }
    return buf.toString().trimRight();
  }

  int _calcCodAmount() => 0;

  Future<void> _submit() async {
    for (var i = 0; i < _stops.length; i++) {
      if (_stops[i].address == null) {
        setState(() => _error = 'Vui lòng chọn địa chỉ điểm mua ${i + 1}');
        return;
      }
      if (_stops[i].lat == null || _stops[i].lng == null) {
        setState(() => _error =
            'Điểm mua ${i + 1} chưa có vị trí chính xác. Vui lòng chọn lại từ gợi ý hoặc bản đồ.');
        return;
      }
      if (_stops[i].descCtrl.text.trim().isEmpty) {
        setState(
            () => _error = 'Vui lòng nhập thông tin hàng tại điểm ${i + 1}');
        return;
      }
    }
    if (_deliveryAddr == null) {
      setState(() => _error = 'Vui lòng chọn địa chỉ giao hàng');
      return;
    }
    if (_deliveryLat == null || _deliveryLng == null) {
      setState(() => _error =
          'Điểm giao chưa có vị trí chính xác. Vui lòng chọn lại từ gợi ý hoặc bản đồ.');
      return;
    }
    if (_deliveryPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập SĐT người nhận');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final first = _stops.first;
    final codAmount = _calcCodAmount();
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);
    await submitBookingOrder(
      ref: ref,
      context: context,
      data: {
        'service_type': 'shopping',
        'pickup_address': first.address!,
        if (first.placeName?.isNotEmpty == true)
          'pickup_place_name': first.placeName,
        'delivery_address': _deliveryAddr!,
        'pickup_phone': '',
        'delivery_phone': _deliveryPhoneCtrl.text.trim(),
        'receiver_name': _receiverNameCtrl.text.trim(),
        'order_note': _buildNote(),
        'stop_count': _stops.length,
        'payment_method': 'cod',
        'cod_amount': codAmount,
        'total_amount': netFee,
        if (first.lat != null) 'pickup_lat': first.lat,
        if (first.lng != null) 'pickup_lng': first.lng,
        if (_deliveryLat != null) 'delivery_lat': _deliveryLat,
        if (_deliveryLng != null) 'delivery_lng': _deliveryLng,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
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
    final serviceName = ref
            .watch(serviceTypeProvider)
            .valueOrNull
            ?.where((service) => service.key == 'shopping')
            .map((service) => service.label.trim())
            .where((label) => label.isNotEmpty)
            .firstOrNull ??
        serviceDefOf('shopping').label;
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
                size: 18, color: AppColors.textPrimary),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(serviceName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFontSize.titleLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ),
      body: Builder(
        builder: (bodyContext) => Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.paddingOf(bodyContext).bottom + 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ...List.generate(_stops.length, (i) => _buildStopCard(i)),
              if (_stops.length < 5) ...[
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Thêm điểm mua'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: Colors.white.withValues(alpha: .28),
                    side: BorderSide(color: Colors.white.withValues(alpha: .7)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.glass)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildDeliveryCard(),
              const SizedBox(height: 14),
              DeliveryVoucherCard(
                code: _voucherCode,
                discount: _voucherDiscount,
                onTap: _fee != null && !_loadingFee ? _showVoucherSheet : null,
                onRemove: () => setState(() {
                  _voucherCode = null;
                  _voucherDiscount = 0;
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BookingSummaryBar(
        serviceName: '$serviceName · ${_stops.length} điểm mua',
        buttonLabel: 'Đặt mua hộ',
        feeLabel: 'Cước mua hộ',
        canEstimate: _stops.first.address != null && _deliveryAddr != null,
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
    ));
  }

  Widget _buildStopCard(int i) {
    final stop = _stops[i];
    final hasAddress = stop.address?.trim().isNotEmpty == true;
    final hasPlace = stop.placeName?.trim().isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(AppRadius.glass),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickStopAddress(i),
                    borderRadius: BorderRadius.circular(AppRadius.glass),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.glass),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .7)),
                          ),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: AppFontSize.body,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Điểm mua ${i + 1}',
                                  style: const TextStyle(
                                      fontSize: AppFontSize.caption,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                hasAddress
                                    ? (hasPlace
                                        ? stop.placeName!
                                        : stop.address!)
                                    : 'Chọn cửa hàng / địa chỉ',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppFontSize.bodyLarge,
                                    fontWeight: FontWeight.w600,
                                    color: hasAddress
                                        ? AppColors.textPrimary
                                        : AppColors.primary),
                              ),
                              if (hasAddress && hasPlace) ...[
                                const SizedBox(height: 4),
                                Text(stop.address!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: AppFontSize.body,
                                        color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ]),
                    ),
                  ),
                ),
              ),
              if (_stops.length > 1)
                IconButton(
                  tooltip: 'Xóa điểm mua ${i + 1}',
                  onPressed: () => _removeStop(i),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: stop.descCtrl,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Cần mua gì? *',
                hintText: 'Ví dụ: 2 ly cà phê sữa, ít đá',
                alignLabelWithHint: true,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard() => DeliveryAddressCard(
        isPickup: false,
        address: _deliveryAddr,
        placeName: null,
        nameController: _receiverNameCtrl,
        phoneController: _deliveryPhoneCtrl,
        onAddressTap: _pickDeliveryAddress,
      );
}
