import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../features/order/providers/order_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'shopping_stop_detail_screen.dart';

class _ShopStop {
  String? address;
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

  int?    _fee;
  int     _nightSurcharge = 0;
  double? _distanceKm;
  bool    _loadingFee = false;
  bool    _submitting  = false;
  String? _error;
  int     _voucherDiscount = 0;
  String? _voucherCode;

  @override
  void initState() {
    super.initState();
    final reorder = widget.reorderFrom;
    if (reorder != null) {
      _deliveryAddr            = reorder.deliveryAddress;
      _deliveryLat             = reorder.deliveryLat;
      _deliveryLng             = reorder.deliveryLng;
      _deliveryPhoneCtrl.text  = reorder.deliveryPhone ?? '';
      _stops.first.address     = reorder.pickupAddress;
      _stops.first.lat         = reorder.pickupLat;
      _stops.first.lng         = reorder.pickupLng;
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    } else {
      final user = ref.read(authProvider).user;
      if (user != null) _deliveryPhoneCtrl.text = user.phone;
      _loadGps();
    }
  }

  Future<void> _loadGps() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null || !mounted) return;
    _deliveryLat = pos.latitude;
    _deliveryLng = pos.longitude;
    final addr = await LocationService.addressFromCoords(pos.latitude, pos.longitude);
    if (!mounted) return;
    if (addr != null) setState(() => _deliveryAddr = addr);
  }

  @override
  void dispose() {
    for (final s in _stops) { s.dispose(); }
    _deliveryPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final first = _stops.first;
    if (first.address == null || _deliveryAddr == null) return;
    setState(() { _loadingFee = true; _fee = null; });
    try {
      final params = <String, dynamic>{
        'service_type': 'shopping',
        'stop_count':   _stops.length,
      };
      if (first.lat != null && first.lng != null &&
          _deliveryLat != null && _deliveryLng != null) {
        params['pickup_lat']   = first.lat;
        params['pickup_lng']   = first.lng;
        params['delivery_lat'] = _deliveryLat;
        params['delivery_lng'] = _deliveryLng;
      } else {
        params['pickup_address']   = first.address;
        params['delivery_address'] = _deliveryAddr;
      }
      final res = await ref.read(apiClientProvider).get(
        '/customer/pricing/estimate', params: params,
      );
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      setState(() {
        _fee            = (data['fee'] as num).toInt();
        _nightSurcharge = (data['night_surcharge'] as num?)?.toInt() ?? 0;
        _distanceKm     = (data['distance_km'] as num?)?.toDouble();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingFee = false);
    }
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
      _stops[index].lat     = result.lat;
      _stops[index].lng     = result.lng;
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
      _deliveryLat  = result.lat;
      _deliveryLng  = result.lng;
    });
    _estimate();
  }

  Future<void> _openStopDetail(int i) async {
    final stop = _stops[i];
    final result = await Navigator.of(context).push<ShoppingStopDetailResult>(
      MaterialPageRoute(
        builder: (_) => ShoppingStopDetailScreen(
          stopIndex:   i,
          description: stop.descCtrl.text,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      stop.descCtrl.text = result.description;
    });
  }

  Future<void> _showVoucherSheet() async {
    final result = await Navigator.of(context).push<VoucherPickResult>(
      MaterialPageRoute(
        builder: (_) => VoucherPickerScreen(
          serviceType: 'shopping',
          orderFee:    _fee,
          appliedCode: _voucherCode,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _voucherCode     = result.code;
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
      final s    = _stops[i];
      final addr = s.address ?? '';
      final desc = s.descCtrl.text.trim();
      buf.writeln('=== Điểm ${i + 1}: $addr ===');
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
        setState(() => _error = 'Vui lòng nhập thông tin hàng tại điểm ${i + 1}');
        return;
      }
    }
    if (_deliveryAddr == null) {
      setState(() => _error = 'Vui lòng chọn địa chỉ giao hàng');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final first     = _stops.first;
      final codAmount = _calcCodAmount();
      final netFee    = (_fee ?? 0) - _voucherDiscount;
      final res = await ref.read(apiClientProvider).post('/customer/orders', data: {
        'service_type':     'shopping',
        'pickup_address':   first.address!,
        'delivery_address': _deliveryAddr!,
        'pickup_phone':     '',
        'delivery_phone':   _deliveryPhoneCtrl.text.trim(),
        'order_note':       _buildNote(),
        'stop_count':       _stops.length,
        'payment_method':   'cod',
        'cod_amount':       codAmount,
        'total_amount':     netFee,
        if (first.lat != null)    'pickup_lat':   first.lat,
        if (first.lng != null)    'pickup_lng':   first.lng,
        if (_deliveryLat != null) 'delivery_lat': _deliveryLat,
        if (_deliveryLng != null) 'delivery_lng': _deliveryLng,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
      });
      final code = (res.data['data'] ?? res.data)['code'] as String;
      ref.read(orderListProvider.notifier).fetch();
      if (mounted) context.pushReplacement('/order/$code', extra: 'fromBooking');
    } catch (e) {
      String msg = 'Không thể đặt đơn.';
      try { msg = (e as dynamic).response?.data['message'] ?? msg; } catch (_) {}
      setState(() { _error = msg; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final netFee    = (_fee ?? 0) - _voucherDiscount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(Fmt.serviceLabel('shopping'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: Column(
        children: [

          // ── Scrollable form ────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),

                  ...List.generate(_stops.length, (i) => _buildStopCard(i)),

                  if (_stops.length < 5) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _addStop,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Thêm điểm mua',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildDeliveryCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom bar ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad + 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Service + distance
                Row(children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(Fmt.serviceLabel('shopping'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  if (_distanceKm != null)
                    Text('${_distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ]),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                const SizedBox(height: 10),

                // Price + voucher
                Row(children: [
                  GestureDetector(
                    onTap: (_stops.first.address != null && _deliveryAddr != null) ? _showVoucherSheet : null,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_offer_outlined,
                          size: 16,
                          color: _voucherCode != null
                              ? AppColors.primary
                              : (_stops.first.address != null && _deliveryAddr != null)
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(width: 5),
                      Text(_voucherCode ?? 'Ưu đãi',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _voucherCode != null
                                  ? AppColors.primary
                                  : (_stops.first.address != null && _deliveryAddr != null)
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondary.withValues(alpha: 0.4))),
                    ]),
                  ),
                  const Spacer(),
                  if (_loadingFee)
                    const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                  else
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (_fee != null && _voucherDiscount > 0)
                        Text(Fmt.currency(_fee!),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textSecondary)),
                      Text(_fee == null ? '—' : Fmt.currency(netFee),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: _fee != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary)),
                      if (!_loadingFee && _nightSurcharge > 0)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.nightlight_round,
                              size: 10, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text('+${Fmt.currency(_nightSurcharge)} đêm',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.warning)),
                        ]),
                    ]),
                ]),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12))),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Đặt ${Fmt.serviceLabel('shopping').toLowerCase()} ngay',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
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
    final stop    = _stops[i];
    final hasInfo = stop.descCtrl.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Điểm mua ${i + 1}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (_stops.length > 1)
                GestureDetector(
                  onTap: () => _removeStop(i),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.danger),
                  ),
                ),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Address tap row
          GestureDetector(
            onTap: () => _pickStopAddress(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 5, 13),
              child: Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stop.address ?? 'Nhập địa điểm lấy hàng',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: stop.address != null
                          ? FontWeight.w500 : FontWeight.w400,
                      color: stop.address != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Detail info tap row
          GestureDetector(
            onTap: () => _openStopDetail(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 5, 13),
              child: Row(children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: hasInfo ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasInfo
                      ? Text(
                          stop.descCtrl.text.isNotEmpty
                              ? stop.descCtrl.text
                              : 'Đã nhập thông tin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        )
                      : Text.rich(TextSpan(children: [
                          TextSpan(
                            text: 'Mô tả hàng cần mua',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.danger),
                          ),
                        ])),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              const Icon(Icons.flag_outlined,
                  size: 18, color: AppColors.danger),
              const SizedBox(width: 10),
              const Text('Địa chỉ giao hàng',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          GestureDetector(
            onTap: _pickDeliveryAddress,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 5, 13),
              child: Row(children: [
                const Icon(Icons.location_on_rounded,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _deliveryAddr ?? 'Chọn địa chỉ giao hàng',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _deliveryAddr != null
                          ? FontWeight.w500 : FontWeight.w400,
                      color: _deliveryAddr != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _CompactField(
              controller: _deliveryPhoneCtrl,
              hint: 'SĐT người nhận *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nhập SĐT người nhận' : null,
            ),
          ),
        ],
      ),
    );
  }
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
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 10, height: 1),
      ),
      validator: validator,
    );
  }
}
