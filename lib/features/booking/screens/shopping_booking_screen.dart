import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';

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
        'receiver_name': ref.read(authProvider).user?.name ?? '',
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        title: Text(
          'Mua hộ',
          style: TextStyle(
            fontSize: AppFontSize.display,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // ── Scrollable form ────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  ...List.generate(_stops.length, (i) => _buildStopCard(i)),
                  if (_stops.length < 5) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _addStop,
                      child: CustomPaint(
                        painter: const _DashedOutlinePainter(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded,
                                    size: 14, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Text('Thêm điểm mua',
                                  style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildDeliveryCard(user),
                ],
              ),
            ),
          ),

          // ── Bottom bar ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Service + distance
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: AppColors.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mua hộ',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (_distanceKm != null)
                          Text('${_distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${_stops.length} điểm mua',
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.surfaceAlt),
                const SizedBox(height: 12),

                // Price + voucher
                Row(children: [
                  GestureDetector(
                    onTap:
                        (_stops.first.address != null && _deliveryAddr != null)
                            ? _showVoucherSheet
                            : null,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_offer_outlined,
                          size: 16,
                          color: _voucherCode != null
                              ? AppColors.primary
                              : (_stops.first.address != null &&
                                      _deliveryAddr != null)
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.4)),
                      const SizedBox(width: 5),
                      Text(_voucherCode ?? 'Ưu đãi',
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w600,
                              color: _voucherCode != null
                                  ? AppColors.primary
                                  : (_stops.first.address != null &&
                                          _deliveryAddr != null)
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.4))),
                    ]),
                  ),
                  const Spacer(),
                  if (_loadingFee)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                  else
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                if (_fee != null && _voucherDiscount > 0) ...[
                                  Text(Fmt.currency(_fee!),
                                      style: const TextStyle(
                                          fontSize: AppFontSize.body,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor:
                                              AppColors.textSecondary)),
                                  const SizedBox(width: 6),
                                ],
                                Text(_fee == null ? '—' : Fmt.currency(netFee),
                                    style: TextStyle(
                                        fontSize: AppFontSize.display,
                                        fontWeight: FontWeight.w600,
                                        color: _fee != null
                                            ? AppColors.primary
                                            : AppColors.textSecondary)),
                              ]),
                          if (!_loadingFee && _nightSurcharge > 0)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.nightlight_round,
                                  size: 10, color: AppColors.warning),
                              const SizedBox(width: 3),
                              Text('+${Fmt.currency(_nightSurcharge)} đêm',
                                  style: const TextStyle(
                                      fontSize: AppFontSize.caption,
                                      color: AppColors.warning)),
                            ]),
                        ]),
                ]),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: AppFontSize.caption))),
                  ]),
                ],

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: const StadiumBorder(),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Đặt mua hộ ngay',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(int i) {
    final stop = _stops[i];
    final hasInfo = stop.descCtrl.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Điểm mua ${i + 1}',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (_stops.length > 1)
                GestureDetector(
                  onTap: () => _removeStop(i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: AppColors.danger),
                  ),
                ),
            ]),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Address tap row
          GestureDetector(
            onTap: () => _pickStopAddress(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: stop.address != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.placeName ?? stop.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            if (stop.placeName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                stop.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: AppFontSize.body,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        )
                      : const Text(
                          'Chọn địa điểm mua hàng',
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              color: AppColors.textSecondary),
                        ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Inline description field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: TextField(
              controller: stop.descCtrl,
              maxLines: null,
              minLines: 2,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Mô tả hàng cần mua *',
                hintStyle: const TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    color: AppColors.textSecondary),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Icon(Icons.shopping_cart_outlined,
                      size: 16,
                      color: hasInfo
                          ? AppColors.primary
                          : AppColors.textSecondary),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(UserModel? user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_rounded,
                    size: 13, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('Giao hàng đến',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.divider),
          GestureDetector(
            onTap: _pickDeliveryAddress,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      size: 15, color: AppColors.danger),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _deliveryAddr != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Người nhận',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deliveryAddr!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      : const Text(
                          'Chọn địa chỉ giao hàng',
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              color: AppColors.textSecondary),
                        ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _CompactField(
              controller: _deliveryPhoneCtrl,
              hint: 'SĐT người nhận *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nhập SĐT người nhận'
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(18),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Compact Field ────────────────────────────────────────────────────────────

class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const _CompactField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: AppFontSize.bodyLarge),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: AppFontSize.bodyLarge, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
        errorStyle: const TextStyle(fontSize: AppFontSize.caption, height: 1),
      ),
      validator: validator,
    );
  }
}
