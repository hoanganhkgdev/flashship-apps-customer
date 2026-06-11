import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService._();

  // Dùng để navigate khi tap notification (app background/killed).
  static void Function(String orderCode)? onOrderTap;

  // Buffer các thông báo đến trước khi HomeScreen mount
  static final _pendingNotifications = <Map<String, String?>>[];

  // Called when a new notification arrives (foreground + background tap).
  static void Function({
    required String title,
    required String body,
    String? orderCode,
  })? _onIncomingNotification;

  static set onIncomingNotification(void Function({
    required String title,
    required String body,
    String? orderCode,
  })? callback) {
    _onIncomingNotification = callback;
    if (callback != null) {
      // Flush các thông báo đang chờ
      for (final n in _pendingNotifications) {
        callback(
          title:     n['title'] ?? '',
          body:      n['body']  ?? '',
          orderCode: n['orderCode'],
        );
      }
      _pendingNotifications.clear();
    }
  }

  // Lưu subscription để tránh GC
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;

  // Stream để order_detail_screen subscribe khi đang foreground.
  static final _statusController = StreamController<String>.broadcast();
  static Stream<String> get orderStatusStream => _statusController.stream;

  static Future<void> init() async {
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
    } else {
      await FirebaseMessaging.instance.requestPermission();
    }

    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen(_onMessage);
    _onOpenedSub?.cancel();
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial != null) _onTap(initial);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static void _dispatch(String title, String body, {String? orderCode}) {
    if (_onIncomingNotification != null) {
      _onIncomingNotification!(title: title, body: body, orderCode: orderCode);
    } else {
      _pendingNotifications.add({
        'title': title, 'body': body, 'orderCode': orderCode,
      });
    }
  }

  static void _onMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? '';
    final body  = message.notification?.body  ?? message.data['body']  as String? ?? '';
    if (message.data['type'] == 'order_status') {
      final code = message.data['order_code'] as String?;
      if (code != null) _statusController.add(code);
      _dispatch(title, body, orderCode: code);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }

  static void _onTap(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? '';
    final body  = message.notification?.body  ?? message.data['body']  as String? ?? '';
    if (message.data['type'] == 'order_status') {
      final code = message.data['order_code'] as String?;
      _dispatch(title, body, orderCode: code);
      if (code != null) onOrderTap?.call(code);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }
}
