import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';

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
                    SizedBox(
                      width: 58,
                      height: 64,
                      child: Stack(alignment: Alignment.topCenter, children: [
                        Positioned(
                          bottom: 5,
                          child: Transform.rotate(
                            angle: .785398,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .85)),
                              ),
                            ),
                          ),
                        ),
                        LiquidGlass(
                          child: Container(
                            width: 54,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: .8),
                                  AppColors.primary.withValues(alpha: .3)
                                ],
                              ),
                            ),
                            child: const Center(
                                child: Icon(Icons.location_on_rounded,
                                    size: 28, color: AppColors.primary)),
                          ),
                        ),
                      ]),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _loadingAddress ? 30 : 22,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .22),
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LiquidGlass(
                    child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 22, color: AppColors.textPrimary)),
                )),
                const SizedBox(width: 10),
                const Expanded(
                    child: SizedBox(
                  height: 48,
                  child: LiquidGlass(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    child: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chọn vị trí',
                                  style: TextStyle(
                                      fontSize: AppFontSize.bodyLarge,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              SizedBox(height: 2),
                              Text('Di chuyển bản đồ để đặt ghim',
                                  style: TextStyle(
                                      fontSize: AppFontSize.caption,
                                      color: AppColors.textSecondary)),
                            ]),
                      ),
                    ),
                  ),
                )),
              ]),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlass(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Vị trí đã chọn',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary))),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Về vị trí hiện tại',
                      onPressed: _locating ? null : _loadGpsLocation,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: _locating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.my_location_rounded,
                              size: 21, color: AppColors.primary),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const GlassIcon(
                          icon: Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 34,
                          iconSize: 18),
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
                        backgroundColor:
                            AppColors.primary.withValues(alpha: .16),
                        foregroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: .3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                                color:
                                    AppColors.primary.withValues(alpha: .2))),
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
