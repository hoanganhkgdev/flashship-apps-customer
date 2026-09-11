import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../home/widgets/home_style.dart';

class LegalPageScreen extends ConsumerStatefulWidget {
  final String slug;
  final String title;
  const LegalPageScreen({super.key, required this.slug, required this.title});

  @override
  ConsumerState<LegalPageScreen> createState() => _State();
}

class _State extends ConsumerState<LegalPageScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'Không tải được nội dung';
            });
          }
        },
      ));
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/customer/legal/${widget.slug}');
      final data = res.data['data'] as Map<String, dynamic>;
      final content = data['content'] as String? ?? '';
      final title = data['title'] as String? ?? widget.title;
      final updatedAt = data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null;
      if (mounted) setState(() => _updatedAt = updatedAt);

      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
      font-size: 16px;
      line-height: 1.7;
      color: #465166;
      background: transparent;
      overflow-wrap: anywhere;
      padding: 16px 16px 32px;
    }
    h1, h2, h3 { margin: 22px 0 10px; font-weight: 800; color: #141B2E; }
    h1 { font-size: 23px; }
    h2 { font-size: 20px; }
    h3 { font-size: 18px; }
    p  { margin-bottom: 15px; color: #465166; }
    ul, ol { padding-left: 20px; margin-bottom: 12px; }
    li { margin-bottom: 4px; }
    a  { color: #C64B00; }
    img, video { max-width: 100%; height: auto; }
    table { display: block; max-width: 100%; overflow-x: auto; }
    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
  </style>
</head>
<body>$content</body>
</html>
''';
      _controller.loadHtmlString(html);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được nội dung';
        });
      }
    }
  }

  String get _updatedLabel {
    final value = _updatedAt;
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(children: [
              IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .45),
                      shape: RoundedRectangleBorder(
                          borderRadius: HomeStyle.radius)),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: AppFontSize.display,
                          fontWeight: FontWeight.w800,
                          color: HomeStyle.ink))),
            ]),
          ),
          Expanded(
              child: _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _fetchContent();
                          },
                          child: const Text('Thử lại')),
                    ]))
                  : Column(children: [
                      if (_updatedAt != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: LiquidGlass(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              GlassIcon(
                                  icon: widget.slug == 'privacy-policy'
                                      ? Icons.shield_outlined
                                      : Icons.description_outlined,
                                  color: HomeStyle.orange,
                                  size: 34,
                                  iconSize: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      'Cập nhật lần cuối: $_updatedLabel',
                                      style: const TextStyle(
                                          fontSize: AppFontSize.caption,
                                          color: HomeStyle.muted))),
                            ]),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: LiquidGlass(
                            child: Stack(children: [
                              WebViewWidget(controller: _controller),
                              if (_loading)
                                const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary, strokeWidth: 2),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ])),
        ])),
      ),
    );
  }
}
