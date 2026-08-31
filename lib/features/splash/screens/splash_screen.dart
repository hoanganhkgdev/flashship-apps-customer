import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../version/providers/app_version_provider.dart';

final splashReadyProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _dialogShown = false;
  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
  void dispose() {
    _loadingController.dispose();
    super.dispose();
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
          Center(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Flash Ship',
                    style: TextStyle(
                      fontSize: AppFontSize.xlarge,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giao hàng, mua hộ, đặt xe trong 1 chạm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .92),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 52,
            child: Center(
              child: AnimatedBuilder(
                animation: _loadingController,
                builder: (context, _) {
                  final activeDot = (_loadingController.value * 3).floor() % 3;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: index == activeDot ? 1 : .45,
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
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
          title: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
}
