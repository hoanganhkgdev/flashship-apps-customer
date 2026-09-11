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
    final banners = ref.watch(bannerProvider).valueOrNull ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlass(
        borderRadius: HomeStyle.radius,
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
              height: 168,
              child: Stack(children: [
                if (banners.isEmpty)
                  Positioned.fill(child: _BannerCard(onBook: widget.onBook))
                else
                  Positioned.fill(
                      child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: banners.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) =>
                        _BannerCard(banner: banners[i], onBook: widget.onBook),
                  )),
                if (banners.length > 1)
                  Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                          child: LiquidGlass(
                        borderRadius: BorderRadius.circular(18),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < banners.length; i++)
                            Semantics(
                                label: 'Banner ${i + 1} trên ${banners.length}',
                                selected: i == _current % banners.length,
                                child: Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == _current % banners.length
                                            ? HomeStyle.orange
                                            : HomeStyle.muted
                                                .withValues(alpha: .35)))),
                        ]),
                      ))),
              ])),
        ),
      ),
    );
  }
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
    final fallback = Image.asset('assets/images/home_hero.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x52000000)],
                  stops: [.48, 1],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: const GlassIcon(
                icon: Icons.arrow_forward_rounded,
                color: HomeStyle.orange,
                size: 34,
                iconSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
