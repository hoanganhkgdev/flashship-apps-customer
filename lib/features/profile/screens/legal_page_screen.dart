import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
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
      color: #475467;
      background: transparent;
      overflow-wrap: anywhere;
      padding: 20px 18px 36px;
    }
    h1, h2, h3 { margin: 24px 0 12px; font-weight: 800; color: #172033; line-height: 1.35; }
    h1 { font-size: 23px; }
    h2 { font-size: 20px; border-left: 4px solid #FF5A1F; padding-left: 10px; }
    h3 { font-size: 18px; }
    p  { margin-bottom: 16px; color: #475467; }
    ul, ol { padding-left: 22px; margin-bottom: 16px; }
    li { margin-bottom: 8px; }
    a  { color: #D9480F; font-weight: 600; }
    strong { color: #172033; }
    blockquote { margin: 16px 0; padding: 14px; background: #FFF3ED; border-radius: 12px; color: #344054; }
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
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9DE),
            border: Border(bottom: BorderSide(color: Color(0xFFFFD7C7))),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.white.withValues(alpha: .86),
                    side: const BorderSide(color: Color(0xFFFFD1BF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      const SizedBox(height: 3),
                      Text(
                        widget.slug == 'privacy-policy'
                            ? 'Cách Flash Ship bảo vệ dữ liệu của bạn'
                            : 'Thông tin và điều kiện sử dụng dịch vụ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: HomeStyle.cardMuted,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: HomeStyle.divider),
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        size: 34, color: HomeStyle.muted),
                  ),
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: AppFontSize.body, color: HomeStyle.muted)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _fetchContent();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeStyle.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ]))
              : Column(children: [
                  if (_updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.white, Color(0xFFFFF2EC)],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: const Color(0xFFFFD1BF)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: HomeStyle.peach,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                                widget.slug == 'privacy-policy'
                                    ? Icons.shield_outlined
                                    : Icons.description_outlined,
                                size: 18,
                                color: HomeStyle.orange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Cập nhật lần cuối: $_updatedLabel',
                                style: const TextStyle(
                                    fontSize: AppFontSize.caption,
                                    fontWeight: FontWeight.w600,
                                    color: HomeStyle.ink)),
                          ),
                        ]),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16,
                          16 + MediaQuery.paddingOf(context).bottom),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: HomeStyle.card,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: HomeStyle.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Stack(children: [
                            WebViewWidget(controller: _controller),
                            if (_loading)
                              const Center(
                                child: CircularProgressIndicator(
                                    color: HomeStyle.orange, strokeWidth: 2),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}
