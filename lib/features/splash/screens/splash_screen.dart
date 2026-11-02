import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';
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
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
      backgroundColor: HomeStyle.peach,
      body: Stack(
        children: [
          const Positioned(
            top: -92,
            right: -70,
            child: _DecorativeCircle(size: 230, opacity: .09),
          ),
          const Positioned(
            top: 96,
            right: 34,
            child: _DecorativeCircle(size: 28, opacity: .14),
          ),
          const Positioned(
            bottom: 76,
            left: -58,
            child: _DecorativeCircle(size: 150, opacity: .07),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 4),
                      AnimatedBuilder(
                        animation: _loadingController,
                        builder: (context, child) => Transform.scale(
                          scale: .985 + (_loadingController.value * .03),
                          child: child,
                        ),
                        child: Container(
                          width: 116,
                          height: 116,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .9),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _orange.withValues(alpha: .10),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'Flash Ship',
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: HomeStyle.ink,
                            height: 1.1,
                            letterSpacing: -.8,
                          ),
                          children: const [
                            TextSpan(text: 'Flash '),
                            TextSpan(
                              text: 'Ship',
                              style: TextStyle(color: _orange),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Mọi hành trình, một ứng dụng',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: HomeStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ServiceLine(),
                      const Spacer(flex: 5),
                      _LoadingStatus(animation: _loadingController),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _orange = HomeStyle.orange;

  void _showForceUpdateDialog(BuildContext context, AppVersionState v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: HomeStyle.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/images/logo.png',
                  fit: BoxFit.contain),
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
                  backgroundColor: HomeStyle.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
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

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HomeStyle.orange.withValues(alpha: opacity),
        ),
      );
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine();

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: const [
          _ServiceLabel(label: 'Giao hàng'),
          _ServiceDot(),
          _ServiceLabel(label: 'Mua hộ'),
          _ServiceDot(),
          _ServiceLabel(label: 'Đặt xe'),
        ],
      );
}

class _ServiceLabel extends StatelessWidget {
  const _ServiceLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w600,
          color: HomeStyle.muted,
        ),
      );
}

class _ServiceDot extends StatelessWidget {
  const _ServiceDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: HomeStyle.orange,
          shape: BoxShape.circle,
        ),
      );
}

class _LoadingStatus extends StatelessWidget {
  const _LoadingStatus({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final activeDot = (animation.value * 2.99).floor();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == activeDot ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: HomeStyle.orange.withValues(
                          alpha: index == activeDot ? 1 : .22,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 9),
            const Flexible(
              child: Text(
                'Đang chuẩn bị trải nghiệm của bạn',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.muted,
                ),
              ),
            ),
          ],
        ),
      );
}
