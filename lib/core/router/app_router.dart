import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/booking/screens/delivery_booking_screen.dart';
import '../../features/booking/screens/ride_booking_screen.dart';
import '../../features/booking/screens/shopping_booking_screen.dart';
import '../../features/booking/screens/topup_booking_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notification/screens/notification_inbox_screen.dart';
import '../../features/order/models/order_model.dart';
import '../../features/order/screens/order_detail_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';
import '../../features/profile/screens/legal_page_screen.dart';
import '../../features/profile/screens/saved_addresses_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/version/providers/app_version_provider.dart';
import '../../features/voucher/screens/voucher_list_screen.dart';
import '../../features/order/screens/order_stats_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<AppVersionState>(appVersionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth     = ref.read(authProvider);
      final version  = ref.read(appVersionProvider);
      final location = state.matchedLocation;

      if (!auth.isInitialized) return location == '/splash' ? null : '/splash';

      // Keep on splash while force update dialog is shown
      if (version.needsForceUpdate) return '/splash';

      final isAuth   = auth.isAuthenticated;
      final onSplash = location == '/splash';
      final onAuth   = location == '/login' ||
                       location == '/register';

      if (onSplash) return isAuth ? '/home' : '/login';
      if (isAuth && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(
          regData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/booking/delivery',
        builder: (_, state) => DeliveryBookingScreen(
          reorderFrom: state.extra as OrderModel?,
        ),
      ),
      GoRoute(
        path: '/booking/shopping',
        builder: (_, state) => ShoppingBookingScreen(
          reorderFrom: state.extra as OrderModel?,
        ),
      ),
      GoRoute(
        path: '/booking/topup',
        builder: (_, __) => const TopupBookingScreen(),
      ),
      GoRoute(
        path: '/booking/:type',
        builder: (_, state) => RideBookingScreen(
          serviceType: state.pathParameters['type']!,
          reorderFrom: state.extra as OrderModel?,
        ),
      ),
      GoRoute(
        path: '/order/:code',
        builder: (_, state) => OrderDetailScreen(
          orderCode: state.pathParameters['code']!,
          fromBooking: state.extra == 'fromBooking',
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationInboxScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, __) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/legal/:slug',
        builder: (_, state) => LegalPageScreen(
          slug:  state.pathParameters['slug']!,
          title: state.uri.queryParameters['title'] ?? 'Thông tin pháp lý',
        ),
      ),
      GoRoute(
        path: '/vouchers',
        builder: (_, __) => const VoucherListScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (_, __) => const OrderStatsScreen(),
      ),
    ],
  );
});
