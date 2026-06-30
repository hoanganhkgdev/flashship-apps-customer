import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _sheetCtrl         = DraggableScrollableController();

  int?   _fee;
  int    _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting  = false;
  String? _error;

  String? _voucherCode;
  int _voucherDiscount = 0;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    } else {
      final user = ref.read(authProvider).user;
      _deliveryPhoneCtrl.text = user?.phone ?? '';
      _destPlaceName = user?.name;
      _loadGps();
    }
  }

  Future<void> _loadGps() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null || !mounted) return;
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
              top: 130 + MediaQuery.of(context).padding.top,
              bottom: 300 + bottomPad,
            ),
          ),

          // ── Floating address bar ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Back
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                        onPressed: () => context.pop(),
                      ),

                      // Timeline dots
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: const Color(0xFFDDDDDD),
                              ),
                            ),
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Address rows
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pickup row
                            GestureDetector(
                              onTap: () => _pickAddress(isPickup: true),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 14, 5, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _pickupAddr != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _pickupPlaceName ?? _pickupAddr!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (_pickupPlaceName != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _pickupAddr!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      : const Text(
                                          'Chọn điểm lấy hàng',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const Divider(height: 1, color: Color(0xFFF0F0F0)),

                            // Delivery row
                            GestureDetector(
                              onTap: () => _pickAddress(isPickup: false),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 5, 14),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _destAddr != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _destPlaceName ??
                                                  user?.name ??
                                                  'Người nhận',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _destAddr!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Chọn điểm giao hàng',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Swap button (when both set)
                      if (_pickupAddr != null && _destAddr != null) ...[
                        Container(
                            width: 1, height: 36,
                            color: const Color(0xFFF0F0F0)),
                        GestureDetector(
                          onTap: _swapAddresses,
                          child: Container(
                            width: 44, height: 44,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.swap_vert_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(width: 4),
                    ],
                  ),
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
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
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
            builder: (_, scrollCtrl) => ListenableBuilder(
              listenable: _sheetCtrl,
              builder: (context, _) {
                final expanded = _sheetCtrl.isAttached &&
                    _sheetCtrl.size > minFrac + 0.02;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
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
                          margin:
                              const EdgeInsets.only(top: 10, bottom: 14),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Service row ────────────────────────────────
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(Fmt.serviceLabel('delivery'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              if (_distanceKm != null)
                                Text(
                                    '${_distanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_nearbyDrivers.isNotEmpty
                                    ? AppColors.success
                                    : AppColors.textSecondary)
                                .withValues(alpha: 0.10),
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
                              '${_nearbyDrivers.length} tài xế gần bạn',
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

                      const SizedBox(height: 14),
                      const Divider(
                          height: 1, color: Color(0xFFF5F5F5)),
                      const SizedBox(height: 12),

                      // ── Price + voucher row ────────────────────────
                      Row(children: [
                        GestureDetector(
                          onTap:
                              (_pickupAddr != null && _destAddr != null)
                                  ? _showVoucherSheet
                                  : null,
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Icon(Icons.local_offer_outlined,
                                size: 16,
                                color: _voucherCode != null
                                    ? AppColors.primary
                                    : (_pickupAddr != null &&
                                            _destAddr != null)
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.4)),
                            const SizedBox(width: 5),
                            Text(
                              _voucherCode ?? 'Ưu đãi',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _voucherCode != null
                                      ? AppColors.primary
                                      : (_pickupAddr != null &&
                                              _destAddr != null)
                                          ? AppColors.textSecondary
                                          : AppColors.textSecondary
                                              .withValues(alpha: 0.4)),
                            ),
                          ]),
                        ),
                        const Spacer(),
                        if (_loadingFee)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                        else
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                            if (_fee != null && _voucherDiscount > 0)
                              Text(Fmt.currency(_fee!),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                      decoration:
                                          TextDecoration.lineThrough,
                                      decorationColor:
                                          AppColors.textSecondary)),
                            Text(
                              _fee == null
                                  ? '—'
                                  : Fmt.currency(netFee),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _fee != null
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                            ),
                            if (!_loadingFee && _nightSurcharge > 0)
                              Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                const Icon(Icons.nightlight_round,
                                    size: 10,
                                    color: AppColors.warning),
                                const SizedBox(width: 3),
                                Text(
                                    '+${Fmt.currency(_nightSurcharge)} đêm',
                                    style: const TextStyle(
                                        fontSize: 10,
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
                                      fontSize: 12))),
                        ]),
                      ],

                      // ── Detail fields (only when expanded) ────────
                      if (expanded) ...[
                        const SizedBox(height: 16),
                        const Divider(
                            height: 1, color: Color(0xFFF5F5F5)),
                        const SizedBox(height: 16),
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
                            _deliveryPhoneCtrl,
                            'SĐT người nhận *',
                            'Bắt buộc',
                            Icons.phone_rounded,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        _buildField(
                            _noteCtrl,
                            'Ghi chú / Mô tả hàng',
                            'Loại hàng, yêu cầu đặc biệt...',
                            Icons.note_alt_outlined,
                            maxLines: 3),
                      ],

                      const SizedBox(height: 16),

                      // ── Book button (always visible) ───────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
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
                );
              },
            ),
          ),
        ],
      ),
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

