import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../version/providers/app_version_provider.dart';

final splashReadyProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final checkFuture = ref.read(appVersionProvider.notifier).check();
      final delayFuture = Future.delayed(const Duration(seconds: 2));
      await Future.wait([checkFuture, delayFuture]);
      if (!mounted) return;
      final version = ref.read(appVersionProvider);
      if (!version.needsForceUpdate) {
        ref.read(splashReadyProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider);

    if (version.isChecked && !_dialogShown) {
      if (version.needsForceUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceUpdateDialog(context, version);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Vector background
          Positioned.fill(
            child: CustomPaint(painter: _SplashPainter()),
          ),

          // Content
          Column(
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/logo-login.png',
                  width: 160,
                  height: 160,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: 0.6),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showForceUpdateDialog(BuildContext context, AppVersionState v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
          content: Text(
            v.message,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
}

// ── Background vector ─────────────────────────────────────────────────────────

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final light  = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final medium = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final dark   = Paint()..color = Colors.white.withValues(alpha: 0.10);

    // Top-right: 3 concentric arcs
    canvas.drawCircle(Offset(size.width + 40, -60), 180, light);
    canvas.drawCircle(Offset(size.width + 40, -60), 130, medium);
    canvas.drawCircle(Offset(size.width + 40, -60),  80, dark);

    // Bottom-left: 3 concentric arcs
    canvas.drawCircle(Offset(-50, size.height + 40), 180, light);
    canvas.drawCircle(Offset(-50, size.height + 40), 130, medium);
    canvas.drawCircle(Offset(-50, size.height + 40),  80, dark);

    // Mid-left: small decorative ring (stroke only)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28;
    canvas.drawCircle(Offset(-30, size.height * 0.38), 90, ringPaint);

    // Mid-right: small dot cluster
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        canvas.drawCircle(
          Offset(size.width - 36 + col * 14.0, size.height * 0.55 + row * 14.0),
          2.5,
          dot,
        );
      }
    }

    // Top-left: small dot cluster
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(28 + col * 14.0, size.height * 0.20 + row * 14.0),
          2.5,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
