import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/utils/formatters.dart';
import '../../home/widgets/home_style.dart';
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

class _State extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
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
    _statusSub =
        FirebaseDatabase.instance.ref('orders/$code').onValue.listen((event) {
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
        setState(() {
          _order = _order?.copyWith(status: newStatus);
        });

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
        .ref('locations/driver_$driverId')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null || !mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _realtimeLat = lat;
          _realtimeLng = lng;
        });
      }
    }, onError: (_) {});
  }

  void _stopRTDBListeners() {
    _statusSub?.cancel();
    _locationSub?.cancel();
  }

  Future<void> _fetchOrderSilent() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/customer/orders/${widget.orderCode}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final order = OrderModel.fromJson(data);
      if (!mounted) return;

      final prevDriverId = _order?.driverId;
      setState(() {
        _order = order;
      });

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/customer/orders/${widget.orderCode}');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final order = OrderModel.fromJson(data);
      setState(() {
        _order = order;
        _loading = false;
      });
      if (_activeStatuses.contains(order.status)) _startRTDBListeners();
      if ((_order?.canRate ?? false) &&
          !_ratingDone &&
          !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showRatingPrompt() {
    if (_order == null ||
        !_order!.canRate ||
        _ratingDone ||
        _hasShownRatingPrompt) {
      return;
    }
    _hasShownRatingPrompt = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 38),
              ),
              const SizedBox(height: 16),
              Text('Đơn hàng hoàn thành!',
                  style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Hành trình kết thúc tốt đẹp.\nBạn có muốn đánh giá tài xế không?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeStyle.orange,
                    elevation: 0,
                    textStyle: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600),
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
                width: double.infinity,
                height: 40,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: TextStyle(fontSize: AppFontSize.body)),
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
      showDragHandle: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _RatingSheet(
        orderCode: widget.orderCode,
        driverName: _order!.driverName ?? '',
        onDone: () {
          Navigator.pop(context);
          setState(() {
            _ratingDone = true;
            _fetchOrder();
          });
        },
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text('Bạn có chắc muốn hủy đơn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hủy đơn',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
          SnackBar(
              content: Text(_parseError(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _parseError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        return data['message']?.toString() ?? 'Lỗi không xác định';
      }
    } catch (_) {}
    return 'Không thể hủy đơn. Thử lại sau.';
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = _order?.canCancel ?? false;
    final bottomBar = _buildBottomBar(canCancel);
    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFFFE9DE),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
          child: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: HomeStyle.card,
              side: const BorderSide(color: HomeStyle.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: HomeStyle.ink),
          ),
        ),
        title: const Text(
          'Chi tiết đơn hàng',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HomeStyle.title,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              tooltip: 'Tùy chọn',
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              onSelected: (value) {
                if (value == 'cancel') _cancelOrder();
                if (value == 'rate') _showRating();
                if (value == 'copy' && _order != null) {
                  Clipboard.setData(ClipboardData(text: _order!.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã đơn')),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'copy', child: Text('Sao chép mã đơn')),
                if (_order?.canRate ?? false)
                  const PopupMenuItem(
                      value: 'rate', child: Text('Đánh giá tài xế')),
                if (canCancel)
                  const PopupMenuItem(
                      value: 'cancel', child: Text('Hủy đơn hàng')),
              ],
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: HomeStyle.card,
                  border: Border.all(color: HomeStyle.divider),
                ),
                child:
                    const Icon(Icons.more_vert_rounded, color: HomeStyle.ink),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: HomeStyle.orange))
          : _error != null
              ? _ErrorView(onRetry: _fetchOrder)
              : _OrderDetailBody(
                  order: (_realtimeLat != null && _realtimeLng != null)
                      ? _order!.withDriverLocation(_realtimeLat!, _realtimeLng!)
                      : _order!,
                  onRefresh: _fetchOrder,
                ),
      bottomNavigationBar: bottomBar == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: HomeStyle.card,
                border: Border(top: BorderSide(color: HomeStyle.divider)),
              ),
              child: bottomBar,
            ),
    );
  }

  Widget? _buildBottomBar(bool canCancel) {
    final order = _order;
    if (order == null) return null;

    if (canCancel) {
      return Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  textStyle: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600),
                ),
                onPressed: _cancelling ? null : _cancelOrder,
                child: _cancelling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.danger))
                    : const Text('Hủy đơn hàng'),
              ),
            ),
          ),
        ),
      );
    }

    if ((order.isCompleted || order.isCancelled) &&
        order.serviceType != 'topup') {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          color: Colors.transparent,
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Flash Ship sẽ hỗ trợ bạn ngay.')),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.ink,
                  side: const BorderSide(color: HomeStyle.divider),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  textStyle: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600),
                ),
                child: const Text('Hỗ trợ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  elevation: 0,
                  textStyle: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  switch (order.serviceType) {
                    case 'delivery':
                      context.push('/booking/delivery', extra: order);
                    case 'shopping':
                      context.push('/booking/shopping', extra: order);
                    default:
                      context.push('/booking/${order.serviceType}',
                          extra: order);
                  }
                },
                child: const Text('Đặt lại'),
              ),
            ),
          ]),
        ),
      );
    }

    return null;
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order, required this.onRefresh});

  final OrderModel order;
  final Future<void> Function() onRefresh;

  static const _orange = HomeStyle.orange;
  int get _progress => switch (order.status) {
        'pending' => 0,
        'assigned' => 1,
        'processing' => 2,
        'completed' => 3,
        _ => -1,
      };

  Future<void> _callDriver() async {
    final phone = order.driverPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openDriverLocation(BuildContext context) async {
    var lat = order.driverLat;
    var lng = order.driverLng;

    // The realtime listener may not have emitted yet when the user taps.
    // Read the latest fix directly once before reporting that it is missing.
    if ((lat == null || lng == null) && order.driverId != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('locations/driver_${order.driverId}')
            .get();
        final value = snapshot.value;
        if (value is Map) {
          final data = Map<String, dynamic>.from(value);
          lat = (data['lat'] as num?)?.toDouble();
          lng = (data['lng'] as num?)?.toDouble();
        }
      } catch (error) {
        debugPrint('Unable to get driver location: $error');
      }
    }

    if (lat == null || lng == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa nhận được vị trí của tài xế.')),
      );
      return;
    }

    final Uri mapUri;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      mapUri = Uri.https('maps.apple.com', '/', {
        'll': '$lat,$lng',
        'q': order.driverName ?? 'Tài xế',
      });
    } else {
      mapUri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(order.driverName ?? 'Tài xế')})',
      );
    }

    try {
      final opened = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('No maps application available');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng bản đồ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _orange,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.paddingOf(context).bottom + 28),
        children: [
          _OrderOverviewCard(order: order),
          const SizedBox(height: 14),
          _ProgressCard(progress: _progress, cancelled: order.isCancelled),
          if (order.status == 'pending' &&
              order.cancelReason == 'no_driver') ...[
            const SizedBox(height: 14),
            const _NoDriverSupportCard(),
          ],
          if (order.pickupAddress != null || order.deliveryAddress != null) ...[
            const SizedBox(height: 14),
            _MockRouteCard(order: order),
          ],
          if (order.driverName != null) ...[
            const SizedBox(height: 14),
            _MockDriverCard(
              order: order,
              onCall: _callDriver,
              onTrack:
                  order.isActive ? () => _openDriverLocation(context) : null,
            ),
          ],
          const SizedBox(height: 14),
          _PaymentCard(order: order),
          if (order.orderNote?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            _NoteCard(note: order.orderNote!),
          ],
        ],
      ),
    );
  }
}

class _OrderOverviewCard extends StatelessWidget {
  const _OrderOverviewCard({required this.order});

  final OrderModel order;

  String get _message => switch (order.status) {
        'pending' => 'Đơn đang chờ tài xế tiếp nhận',
        'assigned' => 'Tài xế đã nhận đơn của bạn',
        'processing' => 'Tài xế đang thực hiện dịch vụ',
        'completed' => 'Dịch vụ đã hoàn thành. Cảm ơn bạn!',
        'cancelled' => 'Đơn hàng đã được hủy',
        _ => Fmt.orderStatus(order.status),
      };

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(order.createdAt)?.toLocal();
    final serviceColor = AppColors.serviceColor(order.serviceType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeStyle.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: HomeStyle.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Fmt.serviceIcon(order.serviceType),
                size: 23, color: serviceColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.serviceLabel(order.serviceType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  created == null
                      ? order.createdAt
                      : 'Đặt lúc ${Fmt.dateTime(created)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    color: HomeStyle.muted,
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: HomeStyle.cardMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mã đơn hàng',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.muted)),
                  const SizedBox(height: 3),
                  Text('#${order.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w800,
                          color: HomeStyle.ink)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sao chép mã đơn',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: order.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã đơn')),
                );
              },
              icon: const Icon(Icons.copy_rounded,
                  size: 19, color: HomeStyle.orange),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _StatusPill(status: order.status),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            order.isCompleted
                ? Icons.check_circle_rounded
                : order.isCancelled
                    ? Icons.cancel_rounded
                    : Icons.local_shipping_rounded,
            size: 18,
            color: order.isCompleted
                ? AppColors.success
                : order.isCancelled
                    ? AppColors.danger
                    : HomeStyle.orange,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(_message,
                style: const TextStyle(
                    fontSize: AppFontSize.body,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: HomeStyle.ink)),
          ),
        ]),
      ]),
    );
  }
}

class _NoDriverSupportCard extends StatelessWidget {
  const _NoDriverSupportCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.warning.withValues(alpha: .3)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa có tài xế nhận đơn. Tổng đài đang hỗ trợ tìm tài xế cho bạn.',
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'assigned' => AppColors.info,
      'processing' || 'completed' => AppColors.success,
      'cancelled' => AppColors.danger,
      _ => HomeStyle.orange,
    };
    final label = Fmt.orderStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFontSize.body,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.cancelled});
  final int progress;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    const labels = ['Đã đặt', 'Có tài xế', 'Thực hiện', 'Hoàn thành'];
    const icons = [
      Icons.receipt_long_rounded,
      Icons.person_rounded,
      Icons.inventory_2_outlined,
      Icons.check_rounded,
    ];
    return _MockCard(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: HomeStyle.peach,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.route_rounded,
                size: 18, color: HomeStyle.orange),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text('Tiến trình đơn hàng',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.ink)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (index) {
            if (index.isOdd) {
              final connector = index ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(top: 17),
                  color: !cancelled && connector < progress
                      ? HomeStyle.orange
                      : HomeStyle.divider,
                ),
              );
            }
            final step = index ~/ 2;
            final done = !cancelled && step <= progress;
            final current = !cancelled && step == progress;
            return Expanded(
              flex: 4,
              child: Column(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: done ? HomeStyle.orange : HomeStyle.cardMuted,
                    shape: BoxShape.circle,
                    border: done ? null : Border.all(color: HomeStyle.divider),
                  ),
                  child: Icon(icons[step],
                      size: 17, color: done ? Colors.white : HomeStyle.muted),
                ),
                const SizedBox(height: 7),
                Text(labels[step],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        height: 1.2,
                        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                        color: current
                            ? HomeStyle.orange
                            : done
                                ? HomeStyle.ink
                                : HomeStyle.muted)),
              ]),
            );
          }),
        ),
        if (cancelled) ...[
          const SizedBox(height: 12),
          const Text('Tiến trình đã dừng do đơn hàng bị huỷ.',
              style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

class _MockRouteCard extends StatelessWidget {
  const _MockRouteCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _MockCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HomeStyle.peach,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.alt_route_rounded,
                size: 19, color: HomeStyle.orange),
          ),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Hành trình',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink))),
        ]),
        const SizedBox(height: 18),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: HomeStyle.orange, shape: BoxShape.circle)),
              Expanded(child: Container(width: 2, color: AppColors.divider)),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.info,
                      borderRadius: BorderRadius.circular(2))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _address('Điểm đi / lấy hàng', order.pickupAddress ?? '—',
                        name: order.senderName, phone: order.pickupPhone),
                    const SizedBox(height: 20),
                    _address(
                        'Điểm đến / giao hàng', order.deliveryAddress ?? '—',
                        name: order.receiverName, phone: order.deliveryPhone),
                  ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _address(String label, String value, {String? name, String? phone}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: AppFontSize.body,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          if (name?.trim().isNotEmpty == true ||
              phone?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Text(
              [
                if (name?.trim().isNotEmpty == true) name!.trim(),
                if (phone?.trim().isNotEmpty == true) phone!.trim()
              ].join(' · '),
              style: const TextStyle(
                fontSize: AppFontSize.caption,
                height: 1.4,
                color: HomeStyle.muted,
              ),
            ),
          ],
        ],
      );
}

class _MockDriverCard extends StatelessWidget {
  const _MockDriverCard({
    required this.order,
    required this.onCall,
    this.onTrack,
  });
  final OrderModel order;
  final VoidCallback onCall;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final initials = order.driverName!
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return _MockCard(
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.md)),
            clipBehavior: Clip.antiAlias,
            child: order.driverAvatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: order.driverAvatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(child: Text(initials)))
                : Center(
                    child: Text(initials,
                        style: TextStyle(
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w600,
                            color: HomeStyle.orange))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(order.driverName!,
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (order.driverPhone?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 3),
                  Text(order.driverPhone!,
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          color: AppColors.textSecondary)),
                ],
              ])),
          if (order.driverPhone?.isNotEmpty ?? false)
            IconButton.filled(
              tooltip: 'Gọi tài xế',
              onPressed: onCall,
              style: IconButton.styleFrom(
                  backgroundColor: HomeStyle.peach,
                  foregroundColor: HomeStyle.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md))),
              icon: const Icon(Icons.phone_outlined),
            ),
        ]),
        if (onTrack != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onTrack,
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeStyle.orange,
                side: const BorderSide(color: HomeStyle.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded, size: 19),
              label: const Text(
                'Xem vị trí tài xế',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final original = order.shippingFee.toInt() + order.discountAmount;
    return _MockCard(
      child: Column(children: [
        Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: HomeStyle.peach,
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 19, color: HomeStyle.orange)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Chi tiết thanh toán',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink))),
        ]),
        const SizedBox(height: 20),
        _row('Cước phí', Fmt.currency(original)),
        if (order.nightSurcharge > 0) ...[
          const SizedBox(height: 12),
          _row('Phụ phí', Fmt.currency(order.nightSurcharge)),
        ],
        if (order.discountAmount > 0) ...[
          const SizedBox(height: 12),
          _row('Giảm giá voucher', '-${Fmt.currency(order.discountAmount)}',
              color: AppColors.success),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        _row('Tổng cộng', Fmt.currency(order.shippingFee), total: true),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? color, bool total = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: total ? AppFontSize.bodyLarge : AppFontSize.body,
                    fontWeight: total ? FontWeight.w600 : FontWeight.w500,
                    color: total
                        ? AppColors.textPrimary
                        : AppColors.textSecondary))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: total ? AppFontSize.display : AppFontSize.body,
                    fontWeight: total ? FontWeight.w800 : FontWeight.w600,
                    color: color ??
                        (total ? HomeStyle.orange : AppColors.textPrimary)))),
      ]);
}

class _MockCard extends StatelessWidget {
  const _MockCard(
      {required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Padding(padding: padding, child: child),
      );
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
                  fontSize: AppFontSize.body,
                  color: AppColors.textPrimary,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => _MockCard(
        child: SizedBox(width: double.infinity, child: child),
      );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _CardHeader(
      {required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary))),
      ]);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 32, color: AppColors.danger),
          ),
          const SizedBox(height: 14),
          const Text('Không thể tải đơn hàng',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppFontSize.bodyLarge)),
          const SizedBox(height: 4),
          const Text('Kiểm tra kết nối và thử lại',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
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
  int _rating = 4;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  final _tags = <String>{};

  static const _labels = [
    '',
    'Rất tệ',
    'Tệ',
    'Bình thường',
    'Tốt',
    'Tuyệt vời!'
  ];
  static const _quickTags = [
    'Giao nhanh',
    'Thân thiện',
    'Cẩn thận',
    'Lịch sự',
    'Đúng giờ',
    'Chuyên nghiệp'
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

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
    final initials = name.isNotEmpty
        ? name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0])
            .join()
            .toUpperCase()
        : 'TX';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassBottomSheet(
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: HomeStyle.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: HomeStyle.peach,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: AppFontSize.xlarge,
                      fontWeight: FontWeight.w600,
                      color: HomeStyle.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name.isEmpty ? 'Tài xế' : name,
                style: TextStyle(
                  fontSize: AppFontSize.display,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text('Đánh giá chuyến đi của bạn',
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      color: AppColors.textSecondary)),

              const SizedBox(height: 26),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return Flexible(
                      child: GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: star <= _rating
                            ? AppColors.warning
                            : const Color(0xFFD0D0D0),
                        size: 40,
                      ),
                    ),
                  ));
                }),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _labels[_rating],
                  key: ValueKey(_rating),
                  style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: _labelColor,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickTags.map((tag) {
                  final selected = _tags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _tags.remove(tag);
                      } else {
                        _tags.add(tag);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? HomeStyle.peach : HomeStyle.card,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: selected
                              ? HomeStyle.orange.withValues(alpha: .3)
                              : HomeStyle.divider,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? HomeStyle.orange : HomeStyle.muted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Note field
              TextField(
                controller: _noteCtrl,
                minLines: 3,
                maxLines: 4,
                style: TextStyle(fontSize: AppFontSize.bodyLarge),
                decoration: InputDecoration(
                  hintText: 'Nhận xét thêm (tuỳ chọn)...',
                  filled: true,
                  fillColor: HomeStyle.cardMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: HomeStyle.orange, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeStyle.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    disabledBackgroundColor:
                        HomeStyle.orange.withValues(alpha: 0.5),
                    elevation: 0,
                    textStyle: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Gửi đánh giá'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ])),
      ),
    );
  }
}
