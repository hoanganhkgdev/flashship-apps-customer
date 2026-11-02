part of '../screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _BannersSection extends ConsumerStatefulWidget {
  const _BannersSection({required this.onBook});
  final VoidCallback onBook;

  @override
  ConsumerState<_BannersSection> createState() => _BannersSectionState();
}

class _BannersSectionState extends ConsumerState<_BannersSection> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bannerProvider);
    final banners = state.valueOrNull ?? [];
    final loading = state.isLoading && banners.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [HomeStyle.orangeLight, HomeStyle.orange],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Khám phá '),
                          TextSpan(
                            text: 'hôm nay',
                            style: TextStyle(color: HomeStyle.orange),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.25,
                        color: HomeStyle.ink,
                      ),
                    ),
                    SizedBox(height: 5),
                    Row(children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 15,
                        color: HomeStyle.orange,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Dịch vụ và chương trình mới',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            height: 1.25,
                            color: HomeStyle.muted,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 176 +
                (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) -
                        1) *
                    32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: HomeStyle.cardRadius,
              border: Border.all(color: HomeStyle.divider),
              boxShadow: HomeStyle.shadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: loading
                ? const _BannerSkeleton()
                : Stack(children: [
                    Positioned.fill(
                      child: banners.isEmpty
                          ? _BannerCard(onBook: widget.onBook)
                          : PageView.builder(
                              controller: _pageCtrl,
                              itemCount: banners.length,
                              onPageChanged: (i) =>
                                  setState(() => _current = i),
                              itemBuilder: (_, i) => _BannerCard(
                                banner: banners[i],
                                onBook: widget.onBook,
                              ),
                            ),
                    ),
                    if (banners.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Semantics(
                          label:
                              'Banner ${_current + 1} trên ${banners.length}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB31C2434),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${_current + 1} / ${banners.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _current ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _current
                        ? HomeStyle.orange
                        : HomeStyle.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F1F4), Color(0xFFE5E8ED)],
          ),
        ),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HomeStyle.orange,
            ),
          ),
        ),
      );
}

class _BannerCard extends StatelessWidget {
  final BannerModel? banner;
  final VoidCallback onBook;
  const _BannerCard({this.banner, required this.onBook});

  Future<void> _open(BuildContext context) async {
    final link = banner?.linkUrl;
    if (link == null || link.isEmpty) {
      onBook();
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri != null) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Keep the banner visible when the external destination is unavailable.
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa mở được liên kết. Vui lòng thử lại.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HeroArtwork(banner: banner, onBook: () => _open(context));
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({this.banner, required this.onBook});
  final BannerModel? banner;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final imageUrl = banner?.imageUrl;
    final hasImage = imageUrl?.isNotEmpty == true;
    final fallback = Image.asset('assets/images/home_v2_delivery.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerRight,
        excludeFromSemantics: true,
        cacheWidth: 1200);
    return Material(
      color: const Color(0xFFFF8B3D),
      child: InkWell(
        onTap: onBook,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            else
              fallback,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: hasImage ? Alignment.topCenter : Alignment.centerLeft,
                  end:
                      hasImage ? Alignment.bottomCenter : Alignment.centerRight,
                  colors: hasImage
                      ? const [Colors.transparent, Color(0x99000000)]
                      : const [Color(0xBFFFFFFF), Color(0x00FFFFFF)],
                  stops: hasImage ? const [.35, 1] : const [0, .68],
                ),
              ),
            ),
            if (!hasImage)
              Positioned(
                left: 18,
                top: 20,
                bottom: 16,
                width: 172,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 172,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giao nhanh,\nsống thảnh thơi',
                          style: TextStyle(
                            fontSize: AppFontSize.titleLarge,
                            height: 1.08,
                            letterSpacing: -.45,
                            fontWeight: FontWeight.w800,
                            color: HomeStyle.ink,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'FlashShip luôn sẵn sàng',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: HomeStyle.orange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Đặt ngay  →',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (hasImage && banner?.title?.trim().isNotEmpty == true)
              Positioned(
                left: 16,
                right: 16,
                bottom: 53,
                child: Text(
                  banner!.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                  ),
                ),
              ),
            if (hasImage)
              Positioned(
                left: 16,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: HomeStyle.orange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Khám phá ngay  →',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
