import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderCode;
  final bool fromBooking;
  const OrderDetailScreen({
    super.key,
    required this.orderCode,
    this.fromBooking = false,
  });

  @override
  ConsumerState<OrderDetailScreen> createState() => _State();
}

const _activeStatuses = {'pending', 'assigned', 'processing'};

class _State extends ConsumerState<OrderDetailScreen> with WidgetsBindingObserver {
  OrderModel? _order;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  bool _ratingDone = false;
  bool _hasShownRatingPrompt = false;

  StreamSubscription? _fcmSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;
  double? _realtimeLat;
  double? _realtimeLng;
  bool _rtdbInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOrder();
    _listenFcmStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final status = _order?.status;
      if (status != null && _activeStatuses.contains(status)) {
        _fetchOrderSilent();
      }
    }
  }

  void _startRTDBListeners() {
    final code = widget.orderCode;
    _rtdbInitialized = false;

    _statusSub?.cancel();
    // Lắng nghe toàn bộ node để bắt cả khi node bị xóa (completed/cancelled)
    _statusSub = FirebaseDatabase.instance
        .ref('orders/$code')
        .onValue
        .listen((event) {
      if (!mounted) return;
      try {
        final data = event.snapshot.value;

        if (data == null) {
          if (_rtdbInitialized) _fetchOrderSilent();
          _rtdbInitialized = true;
          return;
        }

        _rtdbInitialized = true;
        final map = Map<String, dynamic>.from(data as Map);
        final newStatus = map['status'] as String?;
        if (newStatus == null) return;
        if (_order?.status == newStatus) return;

        final prevDriverId = _order?.driverId;
        setState(() { _order = _order?.copyWith(status: newStatus); });

        if (!_activeStatuses.contains(newStatus)) {
          _stopRTDBListeners();
        } else if (newStatus == 'assigned' && prevDriverId == null) {
          _fetchOrderSilent();
        }
      } catch (e) {
        debugPrint('[RTDB] listener error on orders/$code: $e');
      }
    }, onError: (e) => debugPrint('[RTDB] stream error on orders/$code: $e'));

    final driverId = _order?.driverId;
    if (driverId != null) _startLocationListener(driverId);
  }

  void _startLocationListener(int driverId) {
    _locationSub?.cancel();
    _locationSub = FirebaseDatabase.instance
        .ref('flashship_main/locations/driver_$driverId')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null || !mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() { _realtimeLat = lat; _realtimeLng = lng; });
      }
    }, onError: (_) {});
  }

  void _stopRTDBListeners() {
    _statusSub?.cancel();
    _locationSub?.cancel();
  }

  Future<void> _fetchOrderSilent() async {
    try {
      final res = await ref.read(apiClientProvider).get(
          '/customer/orders/${widget.orderCode}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final order = OrderModel.fromJson(data);
      if (!mounted) return;

      final prevDriverId = _order?.driverId;
      setState(() { _order = order; });

      if (!_activeStatuses.contains(order.status)) {
        _stopRTDBListeners();
      } else if (order.driverId != null && order.driverId != prevDriverId) {
        // Driver vừa được assign — khởi động location listener
        _startLocationListener(order.driverId!);
      }

      if (order.canRate && !_ratingDone && !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (_) {}
  }

  void _listenFcmStatus() {
    _fcmSub = NotificationService.orderStatusStream.listen((code) {
      if (!mounted || code != widget.orderCode) return;
      _fetchOrderSilent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    _statusSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrder() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).get(
          '/customer/orders/${widget.orderCode}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final order = OrderModel.fromJson(data);
      setState(() {
        _order = order;
        _loading = false;
      });
      if (_activeStatuses.contains(order.status)) _startRTDBListeners();
      if ((_order?.canRate ?? false) && !_ratingDone && !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showRatingPrompt() {
    if (_order == null || !_order!.canRate || _ratingDone || _hasShownRatingPrompt) return;
    _hasShownRatingPrompt = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 38),
              ),
              const SizedBox(height: 16),
              Text('Đơn hàng hoàn thành!',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Hành trình kết thúc tốt đẹp.\nBạn có muốn đánh giá tài xế không?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    textStyle: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRating();
                  },
                  child: const Text('Đánh giá ngay'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity, height: 40,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: GoogleFonts.beVietnamPro(fontSize: 14)),
                  child: const Text('Để sau'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRating() {
    if (_order == null || !_order!.canRate || _ratingDone) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        orderCode: widget.orderCode,
        driverName: _order!.driverName ?? '',
        onDone: () {
          Navigator.pop(context);
          setState(() { _ratingDone = true; _fetchOrder(); });
        },
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy đơn hàng?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Bạn có chắc muốn hủy đơn này không?',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hủy đơn', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(apiClientProvider).post(
        '/customer/orders/${widget.orderCode}/cancel',
      );
      ref.read(orderListProvider.notifier).fetch();
      await _fetchOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _parseError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Lỗi không xác định';
    } catch (_) {}
    return 'Không thể hủy đơn. Thử lại sau.';
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = _order?.canCancel ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => context.pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 60,
        title: Text(
          _order != null ? 'Đơn #${_order!.code}' : 'Chi tiết đơn',
          style: GoogleFonts.beVietnamPro(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8720C)))
          : _error != null
              ? _ErrorView(onRetry: _fetchOrder)
              : _Body(
                  order: (_realtimeLat != null && _realtimeLng != null)
                      ? _order!.withDriverLocation(_realtimeLat!, _realtimeLng!)
                      : _order!,
                  onRate: _showRating,
                  onRefresh: _fetchOrder,
                ),
      bottomNavigationBar: _buildBottomBar(canCancel),
    );
  }

  Widget? _buildBottomBar(bool canCancel) {
    final order = _order;
    if (order == null) return null;

    if (canCancel) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.beVietnamPro(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              onPressed: _cancelling ? null : _cancelOrder,
              child: _cancelling
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.danger))
                  : const Text('Hủy đơn hàng'),
            ),
          ),
        ),
      );
    }

    if ((order.isCompleted || order.isCancelled) && order.serviceType != 'topup') {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                textStyle: GoogleFonts.beVietnamPro(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Đặt lại'),
              onPressed: () {
                switch (order.serviceType) {
                  case 'delivery': context.push('/booking/delivery', extra: order);
                  case 'shopping': context.push('/booking/shopping', extra: order);
                  default:         context.push('/booking/${order.serviceType}', extra: order);
                }
              },
            ),
          ),
        ),
      );
    }

    return null;
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onRate;
  final Future<void> Function() onRefresh;
  const _Body({required this.order, required this.onRate, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Status ───────────────────────────────────────────────
          _StatusCard(order: order),
          const SizedBox(height: 12),

          // ── Driver ───────────────────────────────────────────────
          if (order.driverName != null) ...[
            _DriverCard(order: order),
            const SizedBox(height: 12),
          ],

          // ── Map ──────────────────────────────────────────────────
          if (order.driverLat != null && order.isActive) ...[
            _DriverMapCard(order: order),
            const SizedBox(height: 12),
          ],

          // ── Route ────────────────────────────────────────────────
          if (order.pickupAddress != null || order.deliveryAddress != null) ...[
            _RouteCard(order: order),
            const SizedBox(height: 12),
          ],

          // ── Order info ───────────────────────────────────────────
          _OrderInfoCard(order: order),

          // ── Note ─────────────────────────────────────────────────
          if (order.orderNote != null && order.orderNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoteCard(note: order.orderNote!),
          ],

          // ── Rating ───────────────────────────────────────────────
          if (order.canRate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onRate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  textStyle: GoogleFonts.beVietnamPro(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Đánh giá tài xế'),
              ),
            ),
          ],

          if (order.driverRating != null) ...[
            const SizedBox(height: 12),
            _RatingDisplay(rating: order.driverRating!),
          ],
        ],
      ),
    );
  }
}

// ─── Status Card (merged header + timeline) ──────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  static (Color, IconData, String) _meta(String status, String type) {
    final isRide = type == 'bike' || type == 'motor' || type == 'car';
    switch (status) {
      case 'pending':
        final who = type == 'topup' ? 'nhân viên' : 'tài xế';
        return (AppColors.warning, Icons.access_time_rounded, 'Đang tìm $who phù hợp...');
      case 'assigned':
        if (isRide) return (AppColors.primary, Icons.person_pin_rounded, 'Tài xế đang trên đường đến điểm đón');
        return (AppColors.primary, Icons.person_pin_rounded, 'Tài xế đang trên đường đến');
      case 'processing':
        return switch (type) {
          'shopping' => (AppColors.primary, Icons.shopping_bag_outlined,           'Tài xế đang mua hàng cho bạn'),
          'topup'    => (AppColors.primary, Icons.account_balance_wallet_outlined, 'Đang thực hiện nạp tiền'),
          'bike'     => (AppColors.primary, Icons.person_pin_circle_rounded,       'Tài xế đã đến điểm đón'),
          'motor'    => (AppColors.primary, Icons.person_pin_circle_rounded,       'Tài xế đã đến điểm đón'),
          'car'      => (AppColors.primary, Icons.person_pin_circle_rounded,       'Tài xế đã đến điểm đón'),
          _          => (AppColors.primary, Icons.inventory_2_outlined,            'Tài xế đang lấy hàng'),
        };
      case 'on_the_way':
        if (isRide)          return (AppColors.info, Icons.directions_bike_rounded, 'Bạn đang trong chuyến đi');
        if (type == 'topup') return (AppColors.info, Icons.local_shipping_rounded,  'Đang trên đường đến bạn');
        return (AppColors.info, Icons.local_shipping_rounded, 'Hàng đang trên đường đến bạn');
      case 'completed':
        if (isRide)          return (AppColors.success, Icons.check_circle_rounded, 'Chuyến đi hoàn thành!');
        if (type == 'topup') return (AppColors.success, Icons.check_circle_rounded, 'Nạp tiền thành công!');
        return (AppColors.success, Icons.check_circle_rounded, 'Giao hàng thành công!');
      case 'cancelled':
        return (AppColors.textSecondary, Icons.cancel_outlined, 'Đơn hàng đã bị huỷ');
      default:
        return (AppColors.textSecondary, Icons.info_outline_rounded, status);
    }
  }

  bool get _isRide => order.serviceType == 'bike' || order.serviceType == 'motor' || order.serviceType == 'car';

  List<(String, String, IconData)> get _steps {
    if (_isRide) {
      return [
        ('pending',    'Tìm tài xế', Icons.schedule_rounded),
        ('assigned',   'Đang đến',   Icons.person_pin_rounded),
        ('processing', 'Đã đến',     Icons.person_pin_circle_rounded),
        ('completed',  'Hoàn thành', Icons.check_circle_rounded),
      ];
    }
    final processingLabel = switch (order.serviceType) {
      'shopping' => 'Mua hàng',
      'topup'    => 'Nạp tiền',
      _          => 'Lấy hàng',
    };
    return [
      ('pending',    'Tìm tài xế',    Icons.schedule_rounded),
      ('assigned',   'Đã nhận',       Icons.person_pin_rounded),
      ('processing', processingLabel,  Icons.inventory_2_outlined),
      ('completed',  'Hoàn thành',    Icons.check_circle_rounded),
    ];
  }

  static const _statusOrder = ['pending', 'assigned', 'processing', 'completed'];

  @override
  Widget build(BuildContext context) {
    final (color, iconData, subtitle) = _meta(order.status, order.serviceType);
    final steps       = _steps;
    final currentIdx  = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Colored banner ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.orderStatus(order.status),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 17, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12.5, color: color.withValues(alpha: 0.8), height: 1.4)),
                    if (order.status == 'pending') ...[
                      const SizedBox(height: 8),
                      _PendingDots(color: color),
                    ],
                  ],
                ),
              ),
            ]),
          ),

          // ── Horizontal timeline ─────────────────────────────────
          if (!isCancelled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.asMap().entries.expand((e) {
                  final i       = e.key;
                  final (key, label, icon) = e.value;
                  final stepIdx = _statusOrder.indexOf(key);
                  final isDone  = currentIdx >= stepIdx && currentIdx != -1;
                  final isLast  = i == steps.length - 1;

                  final stepCol = Expanded(
                    child: Column(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isDone ? color : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16,
                            color: isDone ? Colors.white : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 7),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10.5,
                              fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                              color: isDone ? color : AppColors.textSecondary,
                              height: 1.4)),
                    ]),
                  );

                  if (isLast) return [stepCol];

                  final connector = SizedBox(
                    width: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: stepIdx < currentIdx
                                ? color.withValues(alpha: 0.45)
                                : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  );

                  return [stepCol, connector];
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingDots extends StatefulWidget {
  final Color color;
  const _PendingDots({required this.color});
  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  const _RouteCard({required this.order});

  bool get _isRide =>
      order.serviceType == 'bike' ||
      order.serviceType == 'motor' ||
      order.serviceType == 'car';
  bool get _isTopup => order.serviceType == 'topup';

  String get _pickupLabel => _isRide ? 'Điểm đón' :
      order.serviceType == 'shopping' ? 'Điểm mua' : 'Lấy hàng';
  String get _deliveryLabel => _isRide ? 'Điểm đến' : 'Giao đến';

  @override
  Widget build(BuildContext context) {
    final hasPickup   = order.pickupAddress != null;
    final hasDelivery = order.deliveryAddress != null;

    // Topup: same address for pickup/delivery — show only once
    final isSameAddr = _isTopup &&
        order.pickupAddress == order.deliveryAddress;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connector column
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                if (hasDelivery && !isSameAddr) ...[
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 14),

            // Addresses
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasPickup) ...[
                    _RouteStop(
                      label: _isTopup ? 'Địa điểm' : _pickupLabel,
                      title: order.storeName ?? order.pickupPlaceName,
                      address: order.pickupAddress!,
                      phone: order.pickupPhone,
                    ),
                    if (hasDelivery && !isSameAddr)
                      const SizedBox(height: 16),
                  ],
                  if (hasDelivery && !isSameAddr)
                    _RouteStop(
                      label: _deliveryLabel,
                      title: order.receiverName,
                      address: order.deliveryAddress!,
                      phone: order.deliveryPhone,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final String? title;
  final String address;
  final String? phone;
  const _RouteStop({
    required this.label,
    required this.address,
    this.title,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        if (title != null && title!.isNotEmpty) ...[
          Text(title!,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 1),
        ],
        Text(address,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary)),
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Row(children: [
              const Icon(Icons.phone_outlined,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(phone!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ],
    );
  }
}

// ─── Order Info Card ──────────────────────────────────────────────────────────

String _paymentLabel(String method) => 'Tiền mặt';

class _OrderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final serviceColor = AppColors.serviceColor(order.serviceType);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.receipt_long_outlined,
            label: 'Thông tin đơn hàng',
            iconColor: serviceColor,
          ),
          const SizedBox(height: 12),

          // Service badge + code
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: serviceColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                Fmt.serviceLabel(order.serviceType),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: serviceColor),
              ),
            ),
            const Spacer(),
            Text('#${order.code}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          if (order.distanceKm != null) ...[
            _InfoRow(Icons.straighten_rounded, 'Khoảng cách',
                '${order.distanceKm!.toStringAsFixed(1)} km'),
            const SizedBox(height: 8),
          ],

          if (order.discountAmount > 0) ...[
            _InfoRow(Icons.sell_outlined, 'Phí gốc',
                Fmt.currency(order.shippingFee + order.discountAmount)),
            const SizedBox(height: 8),
            _InfoRow(
              Icons.local_offer_outlined,
              'Giảm giá${order.voucherCode != null ? ' (${order.voucherCode})' : ''}',
              '- ${Fmt.currency(order.discountAmount)}',
              valueColor: AppColors.success,
            ),
            const SizedBox(height: 8),
          ],

          if (order.nightSurcharge > 0) ...[
            _InfoRow(
              Icons.nightlight_round,
              'Phụ thu đêm',
              '+ ${Fmt.currency(order.nightSurcharge)}',
              valueColor: AppColors.warning,
            ),
            const SizedBox(height: 8),
          ],

          // Fee highlight row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: serviceColor.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              Icon(Icons.payments_outlined, size: 18, color: serviceColor),
              const SizedBox(width: 10),
              Text('Phí vận chuyển',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text(Fmt.currency(order.shippingFee),
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: serviceColor)),
            ]),
          ),


          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          _InfoRow(
            Icons.credit_card_outlined,
            'Thanh toán',
            _paymentLabel(order.paymentMethod),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            Icons.access_time_outlined,
            'Thời gian',
            order.createdAt.isNotEmpty
                ? Fmt.dateTime(DateTime.parse(order.createdAt))
                : '—',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: AppColors.textSecondary),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary)),
    const Spacer(),
    Text(value,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary)),
  ]);
}

// ─── Note Card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.notes_outlined,
            label: 'Ghi chú',
            iconColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(note,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Rating Display ───────────────────────────────────────────────────────────

class _RatingDisplay extends StatelessWidget {
  final int rating;
  const _RatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
        const SizedBox(width: 6),
        const Text('Đánh giá của bạn',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.warning, size: 20,
          )),
        ),
        const SizedBox(width: 6),
        Text('$rating/5',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

// ─── Driver Card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final OrderModel order;
  const _DriverCard({required this.order});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép mã đơn'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.person_pin_rounded,
            label: 'Tài xế của bạn',
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 14),

          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: ClipOval(
                child: order.driverAvatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: order.driverAvatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(Icons.person_rounded,
                            size: 26, color: AppColors.primary),
                        errorWidget: (_, __, ___) => const Icon(Icons.person_rounded,
                            size: 26, color: AppColors.primary),
                      )
                    : const Icon(Icons.person_rounded,
                        size: 26, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.driverName!,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  if (order.driverPhone != null) ...[
                    const SizedBox(height: 2),
                    Text(order.driverPhone!,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (order.driverPhone != null) ...[
              _ActionBtn(
                icon: Icons.message_rounded,
                color: AppColors.primary,
                onTap: () => _sms(order.driverPhone!),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.call_rounded,
                color: AppColors.success,
                onTap: () => _call(order.driverPhone!),
              ),
            ],
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Order code row
          Row(children: [
            const Icon(Icons.confirmation_number_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            const Text('Mã đơn',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Text('#${order.code}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => _copyCode(context, order.code),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Sao chép',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ─── Driver Map Card ──────────────────────────────────────────────────────────

class _DriverMapCard extends StatefulWidget {
  final OrderModel order;
  const _DriverMapCard({required this.order});

  @override
  State<_DriverMapCard> createState() => _DriverMapCardState();
}

class _DriverMapCardState extends State<_DriverMapCard> {
  gm.GoogleMapController? _ctrl;
  gm.BitmapDescriptor? _shipperIcon;
  gm.BitmapDescriptor? _pickupIcon;
  gm.BitmapDescriptor? _deliveryIcon;
  double _heading = 0.0;
  double? _prevLat, _prevLng;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    _shipperIcon  = await _loadIcon('assets/images/icon_shiper.png',   42);
    _pickupIcon   = await _loadIcon('assets/images/icon_pick.png',     56);
    _deliveryIcon = await _loadIcon('assets/images/icon_delivery.png', 56);
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
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant _DriverMapCard old) {
    super.didUpdateWidget(old);
    final newLat = widget.order.driverLat;
    final newLng = widget.order.driverLng;
    if (newLat != null && newLng != null &&
        (newLat != old.order.driverLat || newLng != old.order.driverLng)) {
      if (_prevLat != null && _prevLng != null) {
        setState(() => _heading = _bearing(_prevLat!, _prevLng!, newLat, newLng));
      }
      _prevLat = newLat;
      _prevLng = newLng;
      _fitCamera();
    }
  }

  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng  = (lng2 - lng1) * toRad;
    final lat1R = lat1 * toRad;
    final lat2R = lat2 * toRad;
    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _fitCamera() {
    if (_ctrl == null) return;
    final dLat = widget.order.driverLat;
    final dLng = widget.order.driverLng;
    if (dLat == null || dLng == null) return;

    final destLat = widget.order.deliveryLat;
    final destLng = widget.order.deliveryLng;

    if (destLat != null && destLng != null) {
      final sw = gm.LatLng(
        dLat < destLat ? dLat : destLat,
        dLng < destLng ? dLng : destLng,
      );
      final ne = gm.LatLng(
        dLat > destLat ? dLat : destLat,
        dLng > destLng ? dLng : destLng,
      );
      _ctrl!.animateCamera(
          gm.CameraUpdate.newLatLngBounds(
              gm.LatLngBounds(southwest: sw, northeast: ne), 60));
    } else {
      _ctrl!.animateCamera(
          gm.CameraUpdate.newLatLngZoom(gm.LatLng(dLat, dLng), 15));
    }
  }

  Set<gm.Marker> get _markers {
    final s   = <gm.Marker>{};
    final o   = widget.order;
    if (o.driverLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('driver'),
        position: gm.LatLng(o.driverLat!, o.driverLng!),
        icon: _shipperIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
        rotation: _heading,
        flat: true,
        infoWindow: gm.InfoWindow(title: o.driverName ?? 'Tài xế'),
      ));
    }
    if (o.pickupLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('pickup'),
        position: gm.LatLng(o.pickupLat!, o.pickupLng!),
        icon: _pickupIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueOrange),
        infoWindow: const gm.InfoWindow(title: 'Điểm lấy'),
      ));
    }
    if (o.deliveryLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('dest'),
        position: gm.LatLng(o.deliveryLat!, o.deliveryLng!),
        icon: _deliveryIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
        infoWindow: const gm.InfoWindow(title: 'Điểm giao'),
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.order.driverLat!;
    final lng = widget.order.driverLng!;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.location_on_rounded,
            label: 'Vị trí tài xế',
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: gm.GoogleMap(
                initialCameraPosition: gm.CameraPosition(
                  target: gm.LatLng(lat, lng),
                  zoom: 15,
                ),
                onMapCreated: (c) => setState(() => _ctrl = c),
                markers: _markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer()),
                  Factory<ScaleGestureRecognizer>(
                      () => ScaleGestureRecognizer()),
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              widget.order.driverName ?? 'Tài xế',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            const Icon(Icons.sync_rounded, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            const Text('Tự động cập nhật',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _CardHeader({required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
  ]);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.error_outline_rounded,
            size: 32, color: AppColors.danger),
      ),
      const SizedBox(height: 14),
      const Text('Không thể tải đơn hàng',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('Kiểm tra kết nối và thử lại',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );
}

// ─── Rating Sheet ─────────────────────────────────────────────────────────────

class _RatingSheet extends ConsumerStatefulWidget {
  final String orderCode, driverName;
  final VoidCallback onDone;
  const _RatingSheet({
    required this.orderCode,
    required this.driverName,
    required this.onDone,
  });

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _rating = 5;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  final _tags = <String>{};

  static const _labels = ['', 'Rất tệ', 'Tệ', 'Bình thường', 'Tốt', 'Tuyệt vời!'];
  static const _quickTags = ['Giao nhanh', 'Thân thiện', 'Cẩn thận', 'Lịch sự', 'Đúng giờ', 'Chuyên nghiệp'];

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post(
        '/customer/orders/${widget.orderCode}/rate',
        data: {
          'rating': _rating,
          if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
          if (_tags.isNotEmpty) 'tags': _tags.toList(),
        },
      );
      widget.onDone();
    } catch (_) {
      setState(() => _submitting = false);
    }
  }

  Color get _labelColor {
    if (_rating >= 4) return AppColors.warning;
    if (_rating == 3) return AppColors.textSecondary;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driverName.trim();
    final initials = name.isNotEmpty ? name.split(' ').last[0].toUpperCase() : 'T';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Avatar
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(name.isEmpty ? 'Tài xế' : name,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text('Đánh giá chuyến đi của bạn',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),

              const SizedBox(height: 24),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: star <= _rating ? AppColors.warning : const Color(0xFFD0D0D0),
                        size: 48,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _labels[_rating],
                  key: ValueKey(_rating),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: _labelColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick tags
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _quickTags.map((tag) {
                  final selected = _tags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) { _tags.remove(tag); } else { _tags.add(tag); }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(tag,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Note field
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nhận xét thêm (tuỳ chọn)...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFFF6F6F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    textStyle: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Gửi đánh giá'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity, height: 40,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Bỏ qua'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
