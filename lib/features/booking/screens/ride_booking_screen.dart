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
import '../../../features/profile/providers/active_city_provider.dart';
import '../../../features/profile/providers/cities_provider.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';

class RideBookingScreen extends ConsumerStatefulWidget {
  final String serviceType; // bike | motor | car
  final OrderModel? reorderFrom;
  const RideBookingScreen(
      {super.key, required this.serviceType, this.reorderFrom});

  @override
  ConsumerState<RideBookingScreen> createState() => _State();
}

class _State extends ConsumerState<RideBookingScreen> {
  gm.GoogleMapController? _mapCtrl;

  String? _pickupAddr, _destAddr;
  String? _pickupPlaceName, _destPlaceName;
  double? _pickupLat, _pickupLng, _destLat, _destLng;

  double _myLat = 10.0452;
  double _myLng = 105.7469;
  bool _mapCenterReady = false;

  final _noteCtrl = TextEditingController();
  int? _fee;
  int _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting = false;
  String? _error;

  String? _voucherCode;
  int _voucherDiscount = 0;

  Set<gm.Polyline> _polylines = {};
  List<Map<String, dynamic>> _nearbyDrivers = [];
  gm.BitmapDescriptor? _pickupMarkerIcon;
  gm.BitmapDescriptor? _deliveryMarkerIcon;
  gm.BitmapDescriptor? _driverMarkerIcon;

  String get _type => widget.serviceType;

  String get _serviceLabel => Fmt.serviceLabel(_type);

  Color get _accentColor => switch (_type) {
        'motor' => AppColors.info,
        'car' => const Color(0xFF7957FF),
        _ => const Color(0xFFB86F00),
      };

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    final r = widget.reorderFrom;
    if (r != null) {
      _pickupAddr = r.pickupAddress;
      _destAddr = r.deliveryAddress;
      _pickupLat = r.pickupLat;
      _pickupLng = r.pickupLng;
      _destLat = r.deliveryLat;
      _destLng = r.deliveryLng;
      _noteCtrl.text = r.orderNote ?? '';
      _destPlaceName = ref.read(authProvider).user?.name;
      final initialLat = r.pickupLat ?? r.deliveryLat;
      final initialLng = r.pickupLng ?? r.deliveryLng;
      if (initialLat != null && initialLng != null) {
        _myLat = initialLat;
        _myLng = initialLng;
        _mapCenterReady = true;
      } else {
        _loadRegionCenter();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    } else {
      _destPlaceName = ref.read(authProvider).user?.name;
      _loadGps(fallbackToRegion: true);
    }
  }

  Future<void> _loadRegionCenter() async {
    final region = ref.read(activeCityProvider);
    final user = ref.read(authProvider).user;
    final cityId = region.cityId ?? user?.cityId;
    final cityName =
        region.cityName.isNotEmpty ? region.cityName : (user?.cityName ?? '');

    // Tọa độ tĩnh giúp các khu vực cũ hiển thị ngay, không cần chờ API.
    final staticCenter = kCityCenters[cityName];
    if (staticCenter != null && mounted) {
      setState(() {
        _myLat = staticCenter.latitude;
        _myLng = staticCenter.longitude;
        _mapCenterReady = true;
      });
    }

    try {
      final cities = await ref.read(citiesProvider.future);
      CityItem? city;
      for (final item in cities) {
        if (cityId != null && item.id == cityId) {
          city = item;
          break;
        }
      }
      if (city == null && cityName.isNotEmpty) {
        for (final item in cities) {
          if (item.name == cityName) {
            city = item;
            break;
          }
        }
      }
      if (city?.lat != null && city?.lng != null && mounted) {
        setState(() {
          _myLat = city!.lat!;
          _myLng = city.lng!;
          _mapCenterReady = true;
        });
      }
    } catch (_) {
      // Giữ tọa độ tĩnh nếu API thành phố tạm thời không khả dụng.
    }
  }

  Future<void> _loadMarkers() async {
    _pickupMarkerIcon = await _loadIcon('assets/images/icon_pick.png', 56);
    _deliveryMarkerIcon =
        await _loadIcon('assets/images/icon_delivery.png', 56);
    _driverMarkerIcon = await _loadIcon('assets/images/icon_shiper.png', 42);
    if (mounted) setState(() {});
  }

  Future<gm.BitmapDescriptor?> _loadIcon(String path, int size) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
          targetWidth: size, targetHeight: size);
      final frame = await codec.getNextFrame();
      final bytes =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return gm.BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchNearbyDrivers() async {
    if (_pickupLat == null || _pickupLng == null) return;
    try {
      final res = await ref.read(apiClientProvider).get(
        '/customer/drivers/nearby',
        params: {'lat': _pickupLat, 'lng': _pickupLng, 'radius': 5},
      );
      final list =
          (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _nearbyDrivers = list);
    } catch (_) {}
  }

  Future<void> _loadGps({bool fallbackToRegion = false}) async {
    final result = await LocationService.resolveCurrentLocation(context);
    if (result == null || !mounted) {
      if (fallbackToRegion && mounted) await _loadRegionCenter();
      return;
    }
    final (pos, addr) = result;
    _myLat = pos.latitude;
    _myLng = pos.longitude;
    _pickupLat = pos.latitude;
    _pickupLng = pos.longitude;
    setState(() {
      _mapCenterReady = true;
      if (addr != null) _pickupAddr = addr;
    });
    _mapCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(gm.LatLng(_myLat, _myLng), 15));
    _fetchNearbyDrivers();
  }

  Future<void> _pickAddress({required bool isPickup}) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
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
    if (isPickup && _pickupLat != null) _fetchNearbyDrivers();
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
    // padding 80 — GoogleMap.padding handles UI chrome offset
    _mapCtrl?.animateCamera(gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(southwest: sw, northeast: ne), 80));
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
          'origin': '$_pickupLat,$_pickupLng',
          'destination': '$_destLat,$_destLng',
          'key': AppConstants.googleMapsApiKey,
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
              color: _accentColor,
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
      shift = 0;
      result = 0;
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
    setState(() {
      _loadingFee = true;
      _fee = null;
    });
    final p = <String, dynamic>{'service_type': _type};
    if (_pickupLat != null && _destLat != null) {
      p['pickup_lat'] = _pickupLat;
      p['pickup_lng'] = _pickupLng;
      p['delivery_lat'] = _destLat;
      p['delivery_lng'] = _destLng;
    } else {
      p['pickup_address'] = _pickupAddr;
      p['delivery_address'] = _destAddr;
    }
    final estimate = await fetchPricingEstimate(ref, p);
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

  Future<void> _submit() async {
    if (_pickupAddr == null || _destAddr == null) {
      setState(() => _error = 'Vui lòng chọn điểm đón và điểm đến');
      return;
    }
    if (_pickupLat == null ||
        _pickupLng == null ||
        _destLat == null ||
        _destLng == null) {
      setState(() => _error =
          'Thiếu toạ độ chính xác. Vui lòng chọn lại điểm đón/đến từ gợi ý hoặc bản đồ.');
      return;
    }
    final phone = ref.read(authProvider).user?.phone ?? '';
    setState(() {
      _submitting = true;
      _error = null;
    });
    await submitBookingOrder(
      ref: ref,
      context: context,
      data: {
        'service_type': _type,
        'pickup_address': _pickupAddr,
        'delivery_address': _destAddr,
        'delivery_phone': phone,
        'receiver_name': ref.read(authProvider).user?.name ?? '',
        if (_pickupPlaceName?.isNotEmpty == true)
          'pickup_place_name': _pickupPlaceName,
        if (_noteCtrl.text.trim().isNotEmpty)
          'order_note': _noteCtrl.text.trim(),
        if (_pickupLat != null) 'pickup_lat': _pickupLat,
        if (_pickupLng != null) 'pickup_lng': _pickupLng,
        if (_destLat != null) 'delivery_lat': _destLat,
        if (_destLng != null) 'delivery_lng': _destLng,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
        'payment_method': 'cod',
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

  Future<void> _showVoucherSheet() async {
    final result = await Navigator.of(context).push<VoucherPickResult>(
      MaterialPageRoute(
        builder: (_) => VoucherPickerScreen(
          serviceType: _type,
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

  void _swapAddresses() {
    setState(() {
      final tmpAddr = _pickupAddr;
      _pickupAddr = _destAddr;
      _destAddr = tmpAddr;
      final tmpName = _pickupPlaceName;
      _pickupPlaceName = _destPlaceName;
      _destPlaceName = tmpName;
      final tmpLat = _pickupLat;
      _pickupLat = _destLat;
      _destLat = tmpLat;
      final tmpLng = _pickupLng;
      _pickupLng = _destLng;
      _destLng = tmpLng;
    });
    _estimate();
    _fitCamera();
    _fetchRoute();
  }

  Set<gm.Marker> get _markers {
    final s = <gm.Marker>{};
    if (_pickupLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('pickup'),
        position: gm.LatLng(_pickupLat!, _pickupLng!),
        icon: _pickupMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueOrange),
      ));
    }
    if (_destLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('dest'),
        position: gm.LatLng(_destLat!, _destLng!),
        icon: _deliveryMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueRed),
      ));
    }
    for (final d in _nearbyDrivers) {
      s.add(gm.Marker(
        markerId: gm.MarkerId('driver_${d['id']}'),
        position: gm.LatLng(
            (d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
        icon: _driverMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueAzure),
        rotation: (d['bearing'] as num?)?.toDouble() ?? 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final rideAccent = _accentColor;
    const surface = AppColors.surface;
    const field = AppColors.surfaceAlt;
    const outline = AppColors.divider;
    const muted = AppColors.textSecondary;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final user = ref.watch(authProvider).user;
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF1EAE1),
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────
          if (_mapCenterReady)
            gm.GoogleMap(
              onMapCreated: (c) {
                _mapCtrl = c;
                if (_pickupLat != null) {
                  c.animateCamera(gm.CameraUpdate.newLatLngZoom(
                      gm.LatLng(_pickupLat!, _pickupLng!), 15));
                }
              },
              initialCameraPosition: gm.CameraPosition(
                target: _pickupLat != null
                    ? gm.LatLng(_pickupLat!, _pickupLng!)
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
                top: 172 + MediaQuery.of(context).padding.top,
                bottom: 330 + bottomPad,
              ),
            )
          else
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFFF1EAE1),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

          // ── Floating address bar ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: outline),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: outline),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18, color: AppColors.textPrimary),
                          ),
                        ),
                      ),

                      // Timeline dots
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Column(children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: rideAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: AppColors.divider,
                            ),
                          ),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]),
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
                                padding:
                                    const EdgeInsets.fromLTRB(0, 17, 8, 11),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _pickupAddr != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _pickupPlaceName ??
                                                  'Vị trí hiện tại của bạn',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: AppFontSize.bodyLarge,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _pickupAddr!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: AppFontSize.body,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Chọn điểm đón',
                                          style: TextStyle(
                                            fontSize: AppFontSize.bodyLarge,
                                            color: muted,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const Divider(height: 1, color: AppColors.divider),

                            // Destination row
                            GestureDetector(
                              onTap: () => _pickAddress(isPickup: false),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 11, 8, 17),
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
                                                  'Điểm đến',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: AppFontSize.bodyLarge,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _destAddr!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: AppFontSize.body,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Chọn điểm đến',
                                          style: TextStyle(
                                            fontSize: AppFontSize.bodyLarge,
                                            color: muted,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Swap button
                      if (_pickupAddr != null && _destAddr != null) ...[
                        Container(width: 1, height: 80, color: outline),
                        GestureDetector(
                          onTap: _swapAddresses,
                          child: Container(
                            width: 58,
                            height: 70,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: rideAccent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: const Icon(
                                  Icons.swap_vert_rounded,
                                  color: Colors.white,
                                  size: 23,
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
            right: 16,
            bottom: 345 + bottomPad,
            child: GestureDetector(
              onTap: () {
                final lat = _pickupLat ?? _myLat;
                final lng = _pickupLng ?? _myLng;
                _mapCtrl?.animateCamera(
                    gm.CameraUpdate.newLatLngZoom(gm.LatLng(lat, lng), 15));
              },
              child: Container(
                width: 52,
                height: 52,
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
                child: Icon(Icons.my_location_rounded,
                    color: rideAccent, size: 23),
              ),
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: outline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Service row ───────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: rideAccent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Fmt.serviceIcon(_type),
                          color: rideAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_serviceLabel,
                              style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          if (_distanceKm != null)
                            Text('${_distanceKm!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                    fontSize: AppFontSize.body, color: muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _nearbyDrivers.isNotEmpty
                            ? const Color(0xFFE7F7EF)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                          _nearbyDrivers.isEmpty
                              ? 'Đang tìm tài xế...'
                              : '${_nearbyDrivers.length} tài xế',
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w600,
                              color: _nearbyDrivers.isNotEmpty
                                  ? AppColors.success
                                  : AppColors.textSecondary),
                        ),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Note inline ────────────────────────────────────────
                  TextField(
                    controller: _noteCtrl,
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ghi chú cho tài xế...',
                      hintStyle: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          color: const Color(0xFFA39A96)),
                      prefixIcon: const Icon(Icons.description_outlined,
                          size: 21, color: AppColors.textTertiary),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      filled: true,
                      fillColor: field,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              BorderSide(color: rideAccent, width: 1.5)),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: outline),
                  const SizedBox(height: 16),

                  // ── Price + voucher ───────────────────────────────────
                  Row(children: [
                    GestureDetector(
                      onTap: _destAddr != null ? _showVoucherSheet : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.local_offer_outlined,
                            size: 20,
                            color: _voucherCode != null
                                ? rideAccent
                                : _destAddr != null
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary
                                        .withValues(alpha: 0.4)),
                        const SizedBox(width: 5),
                        Text(_voucherCode ?? 'Ưu đãi',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: _voucherCode != null
                                    ? rideAccent
                                    : _destAddr != null
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
                          child: CircularProgressIndicator(strokeWidth: 2))
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
                                  Text(
                                      _fee == null ? '—' : Fmt.currency(netFee),
                                      style: TextStyle(
                                          fontSize: AppFontSize.display,
                                          fontWeight: FontWeight.w600,
                                          color: _fee != null
                                              ? rideAccent
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

                  // Error
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

                  const SizedBox(height: 18),

                  // ── Book button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rideAccent,
                        disabledBackgroundColor:
                            rideAccent.withValues(alpha: 0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Đặt ${_serviceLabel.toLowerCase()} ngay',
                              style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
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
}
