import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';

class MapPickResult {
  final String address;
  final double lat;
  final double lng;
  final String? placeName;

  const MapPickResult({
    required this.address,
    required this.lat,
    required this.lng,
    this.placeName,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  gm.GoogleMapController? _controller;
  double _centerLat = 10.0452; // fallback Cần Thơ
  double _centerLng = 105.7469;
  String? _address;
  bool _loadingAddress = false;
  bool _mapReady = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _centerLat = widget.initialLat!;
      _centerLng = widget.initialLng!;
    } else {
      _loadGpsLocation();
    }
  }

  Future<void> _loadGpsLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final Position pos;
    try {
      pos = await LocationService.getCurrentPosition();
    } on LocationException {
      if (mounted) setState(() => _locating = false);
      return;
    }
    if (!mounted) return;
    setState(() => _locating = false);
    _centerLat = pos.latitude;
    _centerLng = pos.longitude;
    if (_mapReady && _controller != null) {
      await _controller!.animateCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(
            target: gm.LatLng(_centerLat, _centerLng),
            zoom: 15.5,
          ),
        ),
      );
    } else {
      setState(() {});
    }
    _reverseGeocode(_centerLat, _centerLng);
  }

  void _onMapCreated(gm.GoogleMapController controller) {
    _controller = controller;
    _mapReady = true;
    _reverseGeocode(_centerLat, _centerLng);
  }

  void _onCameraMove(gm.CameraPosition position) {
    _centerLat = position.target.latitude;
    _centerLng = position.target.longitude;
  }

  void _onCameraIdle() {
    _reverseGeocode(_centerLat, _centerLng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _loadingAddress = true);
    final addr = await LocationService.addressFromCoords(lat, lng);
    if (!mounted) return;
    setState(() {
      _address = addr ?? 'Không xác định được địa chỉ';
      _loadingAddress = false;
    });
  }

  void _confirm() {
    if (_address == null || _loadingAddress) return;
    Navigator.of(context).pop(MapPickResult(
      address: _address!,
      lat: _centerLat,
      lng: _centerLng,
    ));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DD),
      body: Stack(
        children: [
          Positioned.fill(
            child: gm.GoogleMap(
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(_centerLat, _centerLng),
                zoom: 15.5,
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 96,
                bottom: MediaQuery.of(context).padding.bottom + 190,
              ),
            ),
          ),

          // Ghim đứng yên, bản đồ di chuyển phía dưới.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 86),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_pin,
                      color: AppColors.primary,
                      size: 64,
                      shadows: [
                        Shadow(
                          color: Color(0x44000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        )
                      ],
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _loadingAddress ? 30 : 22,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0x55382E29),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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

          Positioned(
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 224,
            child: Material(
              color: AppColors.surface,
              elevation: 2,
              shadowColor: const Color(0x22000000),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _loadGpsLocation,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(17),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.primary),
                        )
                      : const Icon(Icons.my_location_rounded,
                          size: 25, color: AppColors.primary),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  )
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                22,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('VỊ TRÍ ĐÃ CHỌN',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loadingAddress
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: LinearProgressIndicator(
                                  color: AppColors.primary,
                                  backgroundColor: AppColors.primarySoft,
                                ),
                              )
                            : Text(
                                _address ?? 'Đang xác định...',
                                style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_loadingAddress || _address == null)
                          ? null
                          : _confirm,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFFFC8B5),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Chọn địa điểm này',
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
