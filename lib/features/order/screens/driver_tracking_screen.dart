import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../../../core/theme/app_theme.dart';
import '../models/order_model.dart';

class DriverTrackingScreen extends StatefulWidget {
  const DriverTrackingScreen({super.key, required this.order});

  final OrderModel order;

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  gm.GoogleMapController? _mapController;
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  double? _driverLat;
  double? _driverLng;

  gm.LatLng get _fallback => gm.LatLng(
        widget.order.pickupLat ?? widget.order.deliveryLat ?? 10.0452,
        widget.order.pickupLng ?? widget.order.deliveryLng ?? 105.7469,
      );

  @override
  void initState() {
    super.initState();
    _driverLat = widget.order.driverLat;
    _driverLng = widget.order.driverLng;
    final driverId = widget.order.driverId;
    if (driverId != null) {
      _locationSubscription = FirebaseDatabase.instance
          .ref('locations/driver_$driverId')
          .onValue
          .listen(_onLocationChanged, onError: _onLocationError);
    }
  }

  void _onLocationError(Object error) {
    // A denied/offline realtime stream must not become an uncaught error when
    // this screen opens. The last API location (or pickup point) remains usable.
    debugPrint('Unable to listen to driver location: $error');
  }

  void _onLocationChanged(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map || !mounted) return;
    final data = Map<String, dynamic>.from(value);
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() {
      _driverLat = lat;
      _driverLng = lng;
    });
    _mapController?.animateCamera(
      gm.CameraUpdate.newLatLng(gm.LatLng(lat, lng)),
    );
  }

  Set<gm.Marker> get _markers {
    final markers = <gm.Marker>{};
    if (_driverLat != null && _driverLng != null) {
      markers.add(gm.Marker(
        markerId: const gm.MarkerId('driver'),
        position: gm.LatLng(_driverLat!, _driverLng!),
        infoWindow: gm.InfoWindow(
          title: widget.order.driverName ?? 'Tài xế',
          snippet: 'Vị trí hiện tại',
        ),
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(
          gm.BitmapDescriptor.hueOrange,
        ),
      ));
    }
    if (widget.order.deliveryLat != null && widget.order.deliveryLng != null) {
      markers.add(gm.Marker(
        markerId: const gm.MarkerId('destination'),
        position: gm.LatLng(
          widget.order.deliveryLat!,
          widget.order.deliveryLng!,
        ),
        infoWindow: const gm.InfoWindow(title: 'Điểm giao hàng'),
      ));
    }
    return markers;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverPosition = _driverLat != null && _driverLng != null
        ? gm.LatLng(_driverLat!, _driverLng!)
        : _fallback;
    final hasLocation = _driverLat != null && _driverLng != null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: gm.GoogleMap(
              initialCameraPosition: gm.CameraPosition(
                target: driverPosition,
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 72,
                bottom: MediaQuery.paddingOf(context).bottom + 180,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surface,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 12),
                        ],
                      ),
                      child: const Text(
                        'Vị trí tài xế',
                        style: TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.order.driverName ?? 'Tài xế của bạn',
                          style: const TextStyle(
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: hasLocation
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasLocation
                                  ? 'Đang cập nhật vị trí trực tiếp'
                                  : 'Đang chờ vị trí tài xế',
                              style: const TextStyle(
                                fontSize: AppFontSize.body,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasLocation)
                    IconButton.filled(
                      onPressed: () => _mapController?.animateCamera(
                        gm.CameraUpdate.newLatLngZoom(driverPosition, 16),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.my_location_rounded),
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
