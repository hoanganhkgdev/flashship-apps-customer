import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/order/providers/order_provider.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';

class DeliveryBookingScreen extends ConsumerStatefulWidget {
  final OrderModel? reorderFrom;
  const DeliveryBookingScreen({super.key, this.reorderFrom});

  @override
  ConsumerState<DeliveryBookingScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryBookingScreen> {
  gm.GoogleMapController? _mapCtrl;

  String? _pickupAddr, _destAddr;
  String? _pickupPlaceName, _destPlaceName;
  double? _pickupLat, _pickupLng, _destLat, _destLng;

  double _myLat = 10.0452;
  double _myLng = 105.7469;

  final _storeNameCtrl     = TextEditingController();
  final _storePhoneCtrl    = TextEditingController();
  final _deliveryPhoneCtrl = TextEditingController();
  final _noteCtrl          = TextEditingController();
  final _codCtrl           = TextEditingController();
  final _sheetCtrl         = DraggableScrollableController();

  int?   _fee;
  int    _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting  = false;
  String? _error;

  String? _voucherCode;
  int _voucherDiscount = 0;

  bool   _showDetails = false;
  int?   _codAmount;
  String _cargoType = 'standard';

  static const _cargoTypes = [
    ('standard', 'Hàng thường',  Icons.inventory_2_outlined),
    ('food',     'Đồ ăn/uống',   Icons.restaurant_outlined),
    ('fragile',  'Dễ vỡ',        Icons.warning_amber_rounded),
    ('bulky',    'Cồng kềnh',    Icons.inventory_outlined),
  ];

  Set<gm.Polyline> _polylines = {};
  List<Map<String, dynamic>> _nearbyDrivers = [];
  gm.BitmapDescriptor? _pickupMarkerIcon;
  gm.BitmapDescriptor? _deliveryMarkerIcon;
  gm.BitmapDescriptor? _driverMarkerIcon;

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _storeNameCtrl.dispose();
    _storePhoneCtrl.dispose();
    _deliveryPhoneCtrl.dispose();
    _noteCtrl.dispose();
    _codCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMarkers() async {
    _pickupMarkerIcon   = await _loadIcon('assets/images/icon_pick.png',     56);
    _deliveryMarkerIcon = await _loadIcon('assets/images/icon_delivery.png', 56);
    _driverMarkerIcon   = await _loadIcon('assets/images/icon_shiper.png',   42);
    if (mounted) setState(() {});
  }

  Future<gm.BitmapDescriptor?> _loadIcon(String path, int size) async {
    try {
      final data  = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(), targetWidth: size, targetHeight: size);
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return gm.BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('[Marker] load $path failed: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    final r = widget.reorderFrom;
    if (r != null) {
      _pickupAddr = r.pickupAddress;
      _destAddr   = r.deliveryAddress;
      _pickupLat  = r.pickupLat;
      _pickupLng  = r.pickupLng;
      _destLat    = r.deliveryLat;
      _destLng    = r.deliveryLng;
      _storeNameCtrl.text     = r.storeName ?? '';
      _storePhoneCtrl.text    = r.pickupPhone ?? '';
      _deliveryPhoneCtrl.text = r.deliveryPhone ?? '';
      _noteCtrl.text = r.orderNote ?? '';
      _destPlaceName = ref.read(authProvider).user?.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _estimate();
        // Phòng trường hợp đơn reorder thiếu pickup/destination (dữ liệu cũ
        // không đầy đủ) — _startAddressFlow() no-op ngay nếu cả 2 đã có sẵn.
        _startAddressFlow();
      });
    } else {
      final user = ref.read(authProvider).user;
      _deliveryPhoneCtrl.text = user?.phone ?? '';
      _destPlaceName = user?.name;
      _loadGps();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAddressFlow());
    }
  }

  // "Gõ trước, map xác nhận sau" — buộc chọn điểm lấy rồi điểm giao qua
  // AddressPickerScreen trước khi hiện bản đồ. Nếu _loadGps() kịp trả về
  // vị trí hiện tại trước khi tới bước 2 thì _destAddr coi như đã có sẵn
  // (mặc định "giao đến vị trí hiện tại") và bước chọn điểm giao sẽ được bỏ qua.
  Future<void> _startAddressFlow() async {
    if (_pickupAddr == null) {
      await _pickAddress(isPickup: true);
      if (!mounted) return;
      if (_pickupAddr == null) {
        if (context.mounted) context.pop();
        return;
      }
    }
    if (_destAddr == null) {
      await _pickAddress(isPickup: false);
      if (!mounted) return;
      if (_destAddr == null) {
        if (context.mounted) context.pop();
        return;
      }
    }
  }

  Future<void> _loadGps() async {
    final Position pos;
    try {
      pos = await LocationService.getCurrentPosition();
    } on LocationException catch (e) {
      if (mounted) LocationService.showFailureDialog(context, e);
      return;
    }
    if (!mounted) return;
    _myLat = pos.latitude;
    _myLng = pos.longitude;
    _destLat = pos.latitude;
    _destLng = pos.longitude;
    final addr = await LocationService.addressFromCoords(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() { if (addr != null) _destAddr = addr; });
    _mapCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(gm.LatLng(_myLat, _myLng), 15));
    _fetchNearbyDrivers(lat: pos.latitude, lng: pos.longitude);
  }

  Future<void> _pickAddress({required bool isPickup}) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickupAddr      = result.address;
        _pickupPlaceName = result.placeName;
        _pickupLat       = result.lat;
        _pickupLng       = result.lng;
        _nearbyDrivers   = [];
      } else {
        _destAddr      = result.address;
        _destPlaceName = result.placeName ?? ref.read(authProvider).user?.name;
        _destLat       = result.lat;
        _destLng       = result.lng;
      }
    });
    if (isPickup && _pickupLat != null) _fetchNearbyDrivers();
    await _estimate();
    if (_pickupLat != null && _destLat != null) {
      _fitCamera();
      _fetchRoute();
    } else {
      final lat = isPickup ? (_pickupLat ?? _myLat) : _destLat!;
      final lng = isPickup ? (_pickupLng ?? _myLng) : _destLng!;
      _mapCtrl?.animateCamera(
          gm.CameraUpdate.newLatLngZoom(gm.LatLng(lat, lng), 15));
    }
  }

  void _swapAddresses() {
    setState(() {
      final tmpAddr = _pickupAddr; _pickupAddr = _destAddr; _destAddr = tmpAddr;
      final tmpName = _pickupPlaceName; _pickupPlaceName = _destPlaceName; _destPlaceName = tmpName;
      final tmpLat  = _pickupLat; _pickupLat  = _destLat;  _destLat  = tmpLat;
      final tmpLng  = _pickupLng; _pickupLng  = _destLng;  _destLng  = tmpLng;
    });
    _estimate();
    _fitCamera();
    _fetchRoute();
  }

  void _fitCamera() {
    if (_pickupLat == null || _destLat == null) return;
    final sw = gm.LatLng(
      _pickupLat! < _destLat! ? _pickupLat! : _destLat!,
      _pickupLng! < _destLng! ? _pickupLng! : _destLng!,
    );
    final ne = gm.LatLng(
      _pickupLat! > _destLat! ? _pickupLat! : _destLat!,
      _pickupLng! > _destLng! ? _pickupLng! : _destLng!,
    );
    _mapCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(southwest: sw, northeast: ne), 80));
  }

  Future<void> _fetchNearbyDrivers({double? lat, double? lng}) async {
    final useLat = lat ?? _pickupLat;
    final useLng = lng ?? _pickupLng;
    if (useLat == null || useLng == null) return;
    try {
      final res = await ref.read(apiClientProvider).get(
        '/customer/drivers/nearby',
        params: {'lat': useLat, 'lng': useLng, 'radius': 5},
      );
      final list = (res.data['data'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _nearbyDrivers = list);
    } catch (e) {
      debugPrint('[NearbyDrivers] Error: $e');
    }
  }

  Future<void> _fetchRoute() async {
    if (_pickupLat == null || _destLat == null) {
      if (_polylines.isNotEmpty) setState(() => _polylines = {});
      return;
    }
    try {
      final res = await Dio().get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin':      '$_pickupLat,$_pickupLng',
          'destination': '$_destLat,$_destLng',
          'key':         AppConstants.googleMapsApiKey,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final routes = data['routes'] as List;
        if (routes.isEmpty) return;
        final encoded = routes[0]['overview_polyline']['points'] as String;
        if (!mounted) return;
        setState(() {
          _polylines = {
            gm.Polyline(
              polylineId: const gm.PolylineId('route'),
              points: _decodePolyline(encoded),
              color: AppColors.primary,
              width: 4,
              startCap: gm.Cap.roundCap,
              endCap: gm.Cap.roundCap,
              jointType: gm.JointType.round,
            ),
          };
        });
      }
    } catch (_) {}
  }

  static List<gm.LatLng> _decodePolyline(String encoded) {
    final pts = <gm.LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      pts.add(gm.LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  Future<void> _estimate() async {
    if (_pickupAddr == null || _destAddr == null) return;
    setState(() { _loadingFee = true; _fee = null; });
    try {
      final p = <String, dynamic>{'service_type': 'delivery'};
      if (_pickupLat != null && _destLat != null) {
        p['pickup_lat']   = _pickupLat;
        p['pickup_lng']   = _pickupLng;
        p['delivery_lat'] = _destLat;
        p['delivery_lng'] = _destLng;
      } else {
        p['pickup_address']   = _pickupAddr;
        p['delivery_address'] = _destAddr;
      }
      final res = await ref.read(apiClientProvider)
          .get('/customer/pricing/estimate', params: p);
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _fee            = (data['fee'] as num).toInt();
          _nightSurcharge = (data['night_surcharge'] as num?)?.toInt() ?? 0;
          _distanceKm     = (data['distance_km'] as num?)?.toDouble();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  Future<void> _submit() async {
    if (_pickupAddr == null || _destAddr == null) {
      setState(() => _error = 'Vui lòng chọn điểm lấy và điểm giao');
      return;
    }
    if (_pickupLat == null || _pickupLng == null || _destLat == null || _destLng == null) {
      setState(() => _error = 'Thiếu toạ độ chính xác. Vui lòng chọn lại điểm lấy/giao từ gợi ý hoặc bản đồ.');
      return;
    }
    if (_deliveryPhoneCtrl.text.trim().isEmpty) {
      _sheetCtrl.animateTo(1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _error = 'Vui lòng nhập SĐT người nhận');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final netFee = (_fee ?? 0) - _voucherDiscount;
      final res = await ref.read(apiClientProvider).post(
        '/customer/orders',
        data: {
          'service_type':     'delivery',
          'pickup_address':   _pickupAddr,
          'delivery_address': _destAddr,
          'delivery_phone':   _deliveryPhoneCtrl.text.trim(),
          'receiver_name':    ref.read(authProvider).user?.name ?? '',
          if (_storeNameCtrl.text.trim().isNotEmpty)
            'store_name':   _storeNameCtrl.text.trim(),
          // pickup_place_name: ưu tiên từ địa chỉ đã lưu, fallback về tên cửa hàng nhập tay
          'pickup_place_name': (_pickupPlaceName?.isNotEmpty == true
              ? _pickupPlaceName
              : _storeNameCtrl.text.trim().isNotEmpty
                  ? _storeNameCtrl.text.trim()
                  : null),
          if (_storePhoneCtrl.text.trim().isNotEmpty)
            'pickup_phone': _storePhoneCtrl.text.trim(),
          if (_noteCtrl.text.trim().isNotEmpty)
            'order_note': _noteCtrl.text.trim(),
          if (_pickupLat != null)  'pickup_lat':   _pickupLat,
          if (_pickupLng != null)  'pickup_lng':   _pickupLng,
          if (_destLat != null)    'delivery_lat': _destLat,
          if (_destLng != null)    'delivery_lng': _destLng,
          if (_voucherCode != null) 'voucher_code':  _voucherCode,
          'payment_method':                          'cod',
          'total_amount':                            netFee,
          'cod_amount':                               _codAmount ?? 0,
          'cargo_type':                               _cargoType,
        },
      );
      final code = (res.data['data'] ?? res.data)['code'] as String;
      ref.read(orderListProvider.notifier).fetch();
      if (mounted) context.pushReplacement('/order/$code', extra: 'fromBooking');
    } catch (e) {
      String msg = 'Không thể đặt đơn.';
      try { msg = (e as dynamic).response?.data['message'] ?? msg; } catch (_) {}
      setState(() { _error = msg; _submitting = false; });
    }
  }

  Future<void> _showVoucherSheet() async {
    final result = await Navigator.of(context).push<VoucherPickResult>(
      MaterialPageRoute(
        builder: (_) => VoucherPickerScreen(
          serviceType: 'delivery',
          orderFee: _fee,
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


  Set<gm.Marker> get _markers {
    final s = <gm.Marker>{};
    if (_pickupLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('pickup'),
        position: gm.LatLng(_pickupLat!, _pickupLng!),
        icon: _pickupMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueOrange),
      ));
    }
    if (_destLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('dest'),
        position: gm.LatLng(_destLat!, _destLng!),
        icon: _deliveryMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
      ));
    }
    for (final d in _nearbyDrivers) {
      s.add(gm.Marker(
        markerId: gm.MarkerId('driver_${d['id']}'),
        position: gm.LatLng(
            (d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
        icon: _driverMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
        rotation: (d['bearing'] as num?)?.toDouble() ?? 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    // Gõ trước, map xác nhận sau — chưa đủ pickup + destination thì chưa
    // hiện bản đồ/bottom sheet, tránh flash nội dung rỗng trong lúc
    // _startAddressFlow() đang điều hướng qua AddressPickerScreen.
    if (_pickupAddr == null || _destAddr == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final user      = ref.watch(authProvider).user;
    final cityName  = user?.cityName ?? '';
    final focusPt   = kCityCenters[cityName];
    final netFee    = (_fee ?? 0) - _voucherDiscount;
    final screenH   = MediaQuery.of(context).size.height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final minFrac   = ((225.0 + bottomPad) / screenH).clamp(0.25, 0.38);
    final maxFrac   = ((530.0 + bottomPad) / screenH).clamp(0.55, 0.85);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [

          // ── Full-screen map ───────────────────────────────────────────
          gm.GoogleMap(
            onMapCreated: (c) {
              _mapCtrl = c;
              if (_destLat != null) {
                c.animateCamera(gm.CameraUpdate.newLatLngZoom(
                    gm.LatLng(_destLat!, _destLng!), 15));
              } else if (focusPt != null) {
                c.animateCamera(gm.CameraUpdate.newLatLngZoom(
                    gm.LatLng(focusPt.latitude, focusPt.longitude), 14));
              }
            },
            initialCameraPosition: gm.CameraPosition(
              target: focusPt != null
                  ? gm.LatLng(focusPt.latitude, focusPt.longitude)
                  : gm.LatLng(_myLat, _myLng),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(
              top: 92 + MediaQuery.of(context).padding.top,
              bottom: 300 + bottomPad,
            ),
          ),

          // ── Floating address summary bar ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickAddress(isPickup: true),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          _pickupPlaceName?.isNotEmpty == true
                              ? _pickupPlaceName!
                              : _pickupAddr!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickAddress(isPickup: false),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          _destPlaceName?.isNotEmpty == true
                              ? _destPlaceName!
                              : _destAddr!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _swapAddresses,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            color: AppColors.textSecondary, size: 15),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _pickAddress(isPickup: true),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.primary, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── My location button ────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 290 + bottomPad,
            child: GestureDetector(
              onTap: () {
                final lat = _destLat ?? _myLat;
                final lng = _destLng ?? _myLng;
                _mapCtrl?.animateCamera(
                    gm.CameraUpdate.newLatLngZoom(gm.LatLng(lat, lng), 15));
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
          ),

          // ── Bottom panel (draggable) ──────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: minFrac,
            minChildSize: minFrac,
            maxChildSize: maxFrac,
            snap: true,
            snapSizes: [minFrac, maxFrac],
            builder: (_, scrollCtrl) => Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, bottomPad + 16 + keyboardH),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Hàng 1: dịch vụ + khoảng cách/tài xế (trái), giá (phải) ──
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Fmt.serviceLabel('delivery'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (_distanceKm != null) ...[
                              Text('${_distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _nearbyDrivers.isNotEmpty
                                    ? const Color(0xFFE7F7EF)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _nearbyDrivers.isNotEmpty
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _nearbyDrivers.isNotEmpty
                                      ? '${_nearbyDrivers.length} tài xế gần bạn'
                                      : 'Đang tìm tài xế gần bạn...',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _nearbyDrivers.isNotEmpty
                                          ? AppColors.success
                                          : AppColors.textSecondary),
                                ),
                              ]),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_loadingFee)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor:
                                        AppColors.textSecondary)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _fee == null ? '—' : Fmt.currency(netFee),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: _fee != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary),
                          ),
                        ]),
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

                  const SizedBox(height: 4),

                  // ── Hàng 2: Ưu đãi (tách riêng, border-top) ─────────────
                  GestureDetector(
                    onTap: _showVoucherSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(children: [
                        Icon(Icons.local_offer_outlined,
                            size: 16,
                            color: _voucherCode != null
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _voucherCode ?? 'Ưu đãi',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _voucherCode != null
                                    ? AppColors.primary
                                    : AppColors.textPrimary),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ]),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 12))),
                    ]),
                  ],

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  const SizedBox(height: 12),

                  // ── SĐT người nhận — bắt buộc, luôn hiện ───────────────
                  _buildField(
                      _deliveryPhoneCtrl,
                      'SĐT người nhận *',
                      'Bắt buộc',
                      Icons.phone_rounded,
                      keyboardType: TextInputType.phone),

                  const SizedBox(height: 4),

                  // ── Toggle "Thêm chi tiết đơn hàng" ─────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _showDetails = !_showDetails),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.tune_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Thêm chi tiết đơn hàng',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                        Icon(
                            _showDetails
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.textSecondary),
                      ]),
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: !_showDetails
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              _buildField(
                                  _storeNameCtrl,
                                  'Tên điểm lấy',
                                  'VD: Bún bò Huế (tuỳ chọn)',
                                  Icons.store_rounded),
                              const SizedBox(height: 12),
                              _buildField(
                                  _storePhoneCtrl,
                                  'SĐT điểm lấy',
                                  'Tuỳ chọn',
                                  Icons.phone_outlined,
                                  keyboardType: TextInputType.phone),
                              const SizedBox(height: 12),
                              _buildField(
                                  _noteCtrl,
                                  'Ghi chú / Mô tả hàng',
                                  'Loại hàng, yêu cầu đặc biệt...',
                                  Icons.note_alt_outlined,
                                  maxLines: 3),
                              const SizedBox(height: 12),
                              _buildCodField(),
                              const SizedBox(height: 12),
                              const Text('Loại hàng',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              _buildCargoTypeChips(),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  // ── Book button (always visible) ───────────────
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
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Đặt ${Fmt.serviceLabel('delivery').toLowerCase()} ngay',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodField() {
    return TextField(
      controller: _codCtrl,
      keyboardType: TextInputType.number,
      onChanged: (v) => setState(() =>
          _codAmount = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''))),
      style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Thu hộ (COD) — Tuỳ chọn',
        hintStyle:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.payments_outlined,
            size: 16, color: AppColors.success),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: AppColors.success.withValues(alpha: 0.10),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.success, width: 1.5)),
      ),
    );
  }

  Widget _buildCargoTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _cargoTypes.map((c) {
        final (key, label, icon) = c;
        final selected = _cargoType == key;
        return GestureDetector(
          onTap: () => setState(() => _cargoType = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: '$label — $hint',
        hintStyle:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }
}

