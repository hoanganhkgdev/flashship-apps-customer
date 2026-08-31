import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/order/providers/order_provider.dart';
import 'features/version/providers/app_version_provider.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const ProviderScope(child: FlashShipApp()));
}

class FlashShipApp extends ConsumerStatefulWidget {
  const FlashShipApp({super.key});

  @override
  ConsumerState<FlashShipApp> createState() => _FlashShipAppState();
}

class _FlashShipAppState extends ConsumerState<FlashShipApp>
    with WidgetsBindingObserver {
  bool _forceDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Đóng socket cũ trước — tránh request bị treo do tái dùng connection
      // mà OS đã đóng băng trong lúc app ở nền lâu.
      ref.read(apiClientProvider).resetConnection();

      final auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        ref.read(authProvider.notifier).refreshUser();
        ref.read(orderListProvider.notifier).fetch();
      }
      // Re-check version mỗi lần app resume
      ref.read(appVersionProvider.notifier).check();
    }
  }

  void _showForceDialog(AppVersionState v) {
    if (_forceDialogShown) return;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    _forceDialogShown = true;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset('assets/images/logo.png',
                  color: Colors.white, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text('Cập nhật bắt buộc',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
          content: Text(
            v.message,
            style: const TextStyle(
                fontSize: AppFontSize.body,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(v.storeUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cập nhật ngay',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Lắng nghe version state — show dialog khi đang dùng app
    ref.listen<AppVersionState>(appVersionProvider, (prev, next) {
      // Splash tự hiển thị dialog lúc khởi động; listener này chỉ dùng khi
      // force update được bật trong lúc khách đang sử dụng ứng dụng.
      final isOnSplash =
          router.routeInformationProvider.value.uri.path == '/splash';
      if (next.needsForceUpdate && !isOnSplash) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceDialog(next);
        });
      }
    });

    return MaterialApp.router(
      title: 'Flash Ship',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Dùng cỡ chữ chuẩn của hệ điều hành, không phóng đại toàn app.
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child!,
      ),
    );
  }
}
