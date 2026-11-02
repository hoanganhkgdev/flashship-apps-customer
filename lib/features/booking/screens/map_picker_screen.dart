import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';

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
  gm.LatLng? _pendingGps;
  double _centerLat = 10.0452; // fallback Cần Thơ
  double _centerLng = 105.7469;
  String? _address;
  double? _resolvedLat;
  double? _resolvedLng;
  bool _loadingAddress = false;
  bool _addressError = false;
  bool _mapReady = false;
  bool _locating = false;
  bool _cameraMoving = false;
  bool _cameraDidMove = false;
  int _geocodeRequest = 0;
  int _movementVersion = 0;

  bool get _canConfirm =>
      !_locating &&
      !_cameraMoving &&
      !_loadingAddress &&
      !_addressError &&
      _address?.trim().isNotEmpty == true &&
      _resolvedLat == _centerLat &&
      _resolvedLng == _centerLng;

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
    final movementVersion = _movementVersion;
    setState(() => _locating = true);
    final Position pos;
    try {
      pos = await LocationService.getCurrentPosition();
    } catch (_) {
      if (mounted) {
        setState(() => _locating = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
                'Chưa lấy được vị trí hiện tại. Bạn có thể di chuyển bản đồ để chọn.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (movementVersion != _movementVersion) {
      setState(() => _locating = false);
      return;
    }
    setState(() => _locating = false);
    final target = gm.LatLng(pos.latitude, pos.longitude);
    if (_mapReady && _controller != null) {
      await _moveCameraToLocation(target);
    } else {
      _pendingGps = target;
    }
  }

  void _onMapCreated(gm.GoogleMapController controller) {
    _controller = controller;
    _mapReady = true;
    final target = _pendingGps;
    _pendingGps = null;
    if (target != null) {
      _moveCameraToLocation(target);
    } else {
      _reverseGeocode(_centerLat, _centerLng);
    }
  }

  Future<void> _moveCameraToLocation(gm.LatLng target) async {
    _invalidateAddress();
    try {
      await _controller!.animateCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(target: target, zoom: 15.5),
        ),
      );
      if (mounted &&
          !_cameraMoving &&
          _centerLat == target.latitude &&
          _centerLng == target.longitude) {
        _reverseGeocode(_centerLat, _centerLng);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAddress = false;
        _addressError = true;
      });
    }
  }

  void _invalidateAddress() {
    _geocodeRequest++;
    setState(() {
      _address = null;
      _resolvedLat = null;
      _resolvedLng = null;
      _addressError = false;
      _loadingAddress = true;
    });
  }

  void _onCameraMoveStarted() {
    _cameraDidMove = false;
    _cameraMoving = true;
    _invalidateAddress();
  }

  void _onCameraMove(gm.CameraPosition position) {
    if (position.target.latitude != _centerLat ||
        position.target.longitude != _centerLng) {
      if (!_cameraDidMove) {
        _movementVersion++;
        _cameraDidMove = true;
      }
      if (!_cameraMoving) {
        _cameraMoving = true;
        _invalidateAddress();
      }
    }
    _centerLat = position.target.latitude;
    _centerLng = position.target.longitude;
  }

  void _onCameraIdle() {
    _cameraMoving = false;
    _reverseGeocode(_centerLat, _centerLng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final request = ++_geocodeRequest;
    setState(() {
      _loadingAddress = true;
      _addressError = false;
      _address = null;
      _resolvedLat = null;
      _resolvedLng = null;
    });
    String? addr;
    try {
      addr = await LocationService.addressFromCoords(lat, lng);
    } catch (_) {
      addr = null;
    }
    if (!mounted ||
        request != _geocodeRequest ||
        _cameraMoving ||
        lat != _centerLat ||
        lng != _centerLng) {
      return;
    }
    final resolved = addr?.trim();
    setState(() {
      _address = resolved?.isNotEmpty == true ? resolved : null;
      _resolvedLat = _address == null ? null : lat;
      _resolvedLng = _address == null ? null : lng;
      _addressError = _address == null;
      _loadingAddress = false;
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
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
    final status = _addressError
        ? 'Chưa tìm được địa chỉ'
        : _loadingAddress || _cameraMoving || _locating || !_mapReady
            ? 'Đang xác định địa chỉ…'
            : _address ?? 'Di chuyển bản đồ để chọn vị trí';
    final subtitle = _addressError
        ? 'Hãy thử lại hoặc di chuyển ghim đến vị trí khác.'
        : _loadingAddress || _cameraMoving || _locating || !_mapReady
            ? 'Vui lòng chờ trong giây lát.'
            : 'Kiểm tra địa chỉ trước khi xác nhận.';

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: gm.GoogleMap(
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(_centerLat, _centerLng),
                zoom: 15.5,
              ),
              onMapCreated: _onMapCreated,
              onCameraMoveStarted: _onCameraMoveStarted,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),
          // Camera target is the map viewport's centre. Keep the pin tip at
          // that exact point; the confirmation panel sits outside the viewport.
          IgnorePointer(
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: HomeStyle.orange.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: const Icon(Icons.location_on_rounded,
                        size: 56, color: HomeStyle.orange),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Quay lại',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: HomeStyle.card,
                          side: const BorderSide(color: HomeStyle.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: HomeStyle.ink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE9DE),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chọn trên bản đồ',
                                  style: TextStyle(
                                      fontSize: AppFontSize.bodyLarge,
                                      fontWeight: FontWeight.w800,
                                      color: HomeStyle.ink)),
                              SizedBox(height: 2),
                              Text('Di chuyển bản đồ để đặt ghim',
                                  style: TextStyle(
                                      fontSize: AppFontSize.caption,
                                      height: 1.3,
                                      color: HomeStyle.muted)),
                            ],
                          ),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: IconButton(
                tooltip: 'Về vị trí hiện tại',
                onPressed: _locating ? null : _loadGpsLocation,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(48),
                  backgroundColor: HomeStyle.card,
                  side: const BorderSide(color: HomeStyle.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                icon: _locating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: HomeStyle.orange))
                    : const Icon(Icons.my_location_rounded,
                        size: 21, color: HomeStyle.orange),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: HomeStyle.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
          border: Border(top: BorderSide(color: HomeStyle.divider)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .48,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HomeStyle.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Vị trí đã chọn',
                      style: TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w800,
                          color: HomeStyle.ink)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HomeStyle.cardMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: HomeStyle.peach,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: _loadingAddress ||
                                  _cameraMoving ||
                                  _locating ||
                                  !_mapReady
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: HomeStyle.orange),
                                )
                              : Icon(
                                  _addressError
                                      ? Icons.location_off_outlined
                                      : Icons.location_on_outlined,
                                  color: _addressError
                                      ? AppColors.danger
                                      : HomeStyle.orange,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(status,
                                    style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: _addressError
                                          ? AppColors.danger
                                          : HomeStyle.ink,
                                    )),
                                const SizedBox(height: 3),
                                Text(subtitle,
                                    style: const TextStyle(
                                      fontSize: AppFontSize.caption,
                                      height: 1.35,
                                      color: HomeStyle.muted,
                                    )),
                                if (_addressError &&
                                    !_cameraMoving &&
                                    !_locating)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _reverseGeocode(_centerLat, _centerLng),
                                    style: TextButton.styleFrom(
                                      foregroundColor: HomeStyle.orange,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 44),
                                      alignment: Alignment.centerLeft,
                                    ),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 17),
                                    label: const Text('Thử lại'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canConfirm ? _confirm : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: HomeStyle.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: HomeStyle.divider,
                        disabledForegroundColor: HomeStyle.muted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: const Text('Xác nhận vị trí',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
