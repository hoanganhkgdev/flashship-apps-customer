part of '../screens/home_screen.dart';

// ── Banners section ───────────────────────────────────────────────────────────

class _BannersSection extends ConsumerStatefulWidget {
  const _BannersSection();

  @override
  ConsumerState<_BannersSection> createState() => _BannersSectionState();
}

class _BannersSectionState extends ConsumerState<_BannersSection> {
  final _pageCtrl = PageController(initialPage: _bigCount ~/ 2);
  Timer? _timer;
  int _current = 0;

  static const _bigCount = 10000;

  void _startTimer(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bannerProvider);

    return async.maybeWhen(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        if (_timer == null) _startTimer(banners.length);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Nổi bật',
                  style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                children: [
                  SizedBox(
                    height: 170,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _bigCount,
                      onPageChanged: (i) =>
                          setState(() => _current = i % banners.length),
                      itemBuilder: (_, i) =>
                          _BannerCard(banner: banners[i % banners.length]),
                    ),
                  ),
                  // Dots overlay at bottom center
                  if (banners.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(banners.length, (i) {
                          final active = i == _current;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerModel banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final card = banner.imageUrl != null
        ? CachedNetworkImage(
            imageUrl: banner.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 170,
            placeholder: (_, __) =>
                Container(color: AppColors.primary.withValues(alpha: 0.06)),
            errorWidget: (_, __, ___) =>
                _BannerPlaceholder(title: banner.title),
          )
        : _BannerPlaceholder(title: banner.title);

    if (banner.linkUrl != null && banner.linkUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(banner.linkUrl!);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: card,
      );
    }
    return card;
  }
}

class _BannerPlaceholder extends StatelessWidget {
  final String? title;
  const _BannerPlaceholder({this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: title != null
          ? Text(title!,
              style: const TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary))
          : Icon(Icons.image_outlined,
              size: 40, color: AppColors.primary.withValues(alpha: 0.3)),
    );
  }
}
