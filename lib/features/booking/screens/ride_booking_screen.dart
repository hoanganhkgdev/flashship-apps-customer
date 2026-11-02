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
import '../../home/widgets/home_style.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/order/models/order_model.dart';
import '../../../features/profile/providers/active_city_provider.dart';
import '../../../features/profile/providers/cities_provider.dart';
import '../../../features/voucher/screens/voucher_picker_screen.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/booking_field_decoration.dart';
import 'widgets/booking_summary_bar.dart';
import 'widgets/delivery_voucher_card.dart';
import '../../home/providers/service_type_provider.dart';

class _RideAddressCard extends StatelessWidget {
  const _RideAddressCard({
    required this.pickupAddress,
    required this.pickupPlaceName,
    required this.destAddress,
    required this.destPlaceName,
    required this.accent,
    required this.onPickup,
    required this.onDestination,
    required this.onSwap,
  });

  final String? pickupAddress, pickupPlaceName, destAddress, destPlaceName;
  final Color accent;
  final VoidCallback onPickup, onDestination;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) => Material(
        color: HomeStyle.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: HomeStyle.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
            child: Row(children: [
              Icon(Icons.alt_route_rounded, size: 19, color: accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Hành trình của bạn',
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w800,
                        color: HomeStyle.ink)),
              ),
              IconButton(
                tooltip: 'Đổi điểm đón và điểm đến',
                onPressed: onSwap,
                icon: const Icon(Icons.swap_vert_rounded, size: 22),
                color: accent,
              ),
            ]),
          ),
          _RideStopRow(
            label: 'Điểm đón',
            address: pickupAddress,
            placeName: pickupPlaceName,
            icon: Icons.radio_button_checked_rounded,
            color: accent,
            onTap: onPickup,
          ),
          const Divider(
              height: 1, indent: 58, endIndent: 14, color: HomeStyle.divider),
          _RideStopRow(
            label: 'Điểm đến',
            address: destAddress,
            placeName: destPlaceName,
            icon: Icons.location_on_outlined,
            color: AppColors.info,
            onTap: onDestination,
          ),
        ]),
      );
}

class _RideStopRow extends StatelessWidget {
  const _RideStopRow({
    required this.label,
    required this.address,
    required this.placeName,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String? address, placeName;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = address?.trim().isNotEmpty == true;
    final hasPlace = filled && placeName?.trim().isNotEmpty == true;
    return Semantics(
      button: true,
      label: '$label: ${filled ? address : 'Chọn ${label.toLowerCase()}'}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted)),
                  const SizedBox(height: 3),
                  Text(
                    filled
                        ? (hasPlace ? placeName! : address!)
                        : 'Chọn ${label.toLowerCase()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: filled ? HomeStyle.ink : color,
                    ),
                  ),
                  if (hasPlace) ...[
                    const SizedBox(height: 2),
                    Text(address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: HomeStyle.muted,
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: HomeStyle.muted),
          ]),
        ),
      ),
    );
  }
}

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
        _ => HomeStyle.orange,
      };

  IconData get _serviceIcon => switch (_type) {
        'car' => Icons.directions_car_filled_rounded,
        'motor' => Icons.sports_motorsports_rounded,
        _ => Icons.two_wheeler_rounded,
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
      _pickupPlaceName = r.pickupPlaceName;
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
    if (_fee == null || _loadingFee) return;
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
    final serviceName = ref
            .watch(serviceTypeProvider)
            .valueOrNull
            ?.where((service) => service.key == _type)
            .map((service) => service.label.trim())
            .where((label) => label.isNotEmpty)
            .firstOrNull ??
        _serviceLabel;
    final availableHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final panelHeight = availableHeight * .48;
    final headerHeight = 60.0 +
        (MediaQuery.textScalerOf(context).scale(12) - 12)
            .clamp(0.0, double.infinity);
    final netFee = ((_fee ?? 0) - _voucherDiscount).clamp(0, _fee ?? 0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: HomeStyle.background,
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
                    top: headerHeight + 190 + MediaQuery.paddingOf(context).top,
                    bottom: panelHeight,
                  ),
                )
              else
                const Positioned.fill(
                  child: ColoredBox(
                    color: HomeStyle.background,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: HomeStyle.orange,
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: Row(children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      fixedSize: Size(44, headerHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: HomeStyle.card,
                      side: const BorderSide(color: HomeStyle.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: HomeStyle.ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: headerHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE9DE),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child:
                              Icon(_serviceIcon, size: 19, color: rideAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(serviceName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: AppFontSize.bodyLarge,
                                      fontWeight: FontWeight.w800,
                                      color: HomeStyle.ink)),
                              const Text('Chọn điểm đón và điểm đến',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: AppFontSize.caption,
                                      color: HomeStyle.muted)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),

              // Address selection scrolls independently when space is limited.
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, headerHeight + 18, 16, 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: availableHeight * .32,
                      ),
                      child: SingleChildScrollView(
                        child: _RideAddressCard(
                          pickupAddress: _pickupAddr,
                          pickupPlaceName: _pickupPlaceName,
                          destAddress: _destAddr,
                          destPlaceName: _destPlaceName,
                          accent: rideAccent,
                          onPickup: () => _pickAddress(isPickup: true),
                          onDestination: () => _pickAddress(isPickup: false),
                          onSwap: _pickupAddr != null && _destAddr != null
                              ? _swapAddresses
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── My location button ────────────────────────────────────────
              Positioned(
                right: 16,
                bottom: panelHeight + 12,
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
                      color: HomeStyle.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: HomeStyle.divider),
                    ),
                    child: Icon(Icons.my_location_rounded,
                        color: rideAccent, size: 23),
                  ),
                ),
              ),

              // Scroll within the panel when the keyboard or a small screen limits space.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelHeight),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: HomeStyle.card,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card)),
                      border: Border(
                          top: BorderSide(color: HomeStyle.divider),
                          left: BorderSide(color: HomeStyle.divider),
                          right: BorderSide(color: HomeStyle.divider)),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            color: HomeStyle.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: rideAccent.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_serviceIcon,
                                        size: 21, color: rideAccent),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Chuyến đi của bạn',
                                            style: TextStyle(
                                                fontSize: AppFontSize.bodyLarge,
                                                fontWeight: FontWeight.w800,
                                                color: HomeStyle.ink)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _nearbyDrivers.isEmpty
                                              ? 'Chọn hành trình để đặt chuyến'
                                              : '${_nearbyDrivers.length} tài xế đang ở gần bạn',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: AppFontSize.caption,
                                              fontWeight: FontWeight.w600,
                                              color: _nearbyDrivers.isEmpty
                                                  ? HomeStyle.muted
                                                  : AppColors.success),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _nearbyDrivers.isEmpty
                                          ? HomeStyle.muted
                                          : AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _noteCtrl,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: bookingFieldDecoration(
                                    hint: 'Ghi chú cho tài xế (tùy chọn)',
                                    prefixIcon: Icons.notes_rounded,
                                  ).copyWith(
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.auto),
                                ),
                                const SizedBox(height: 12),
                                DeliveryVoucherCard(
                                  code: _voucherCode,
                                  discount: _voucherDiscount,
                                  onTap: _fee != null && !_loadingFee
                                      ? _showVoucherSheet
                                      : null,
                                  onRemove: () => setState(() {
                                    _voucherCode = null;
                                    _voucherDiscount = 0;
                                  }),
                                ),
                              ]),
                        ),
                        BookingSummaryBar(
                          serviceName: serviceName,
                          buttonLabel: 'Đặt ${serviceName.toLowerCase()}',
                          feeLabel: 'Cước chuyến đi',
                          emptyPriceHint:
                              'Chọn điểm đón và điểm đến để xem cước',
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
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
