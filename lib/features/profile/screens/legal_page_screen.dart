import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

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
      ..setBackgroundColor(AppColors.background)
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
      font-family: "Arial Narrow", "Roboto Condensed", Arial, sans-serif;
      font-size: 17px;
      line-height: 1.7;
      color: #6E6561;
      background: #FCF7F3;
      padding: 8px 24px 48px;
    }
    h1, h2, h3 { margin: 22px 0 10px; font-weight: 800; color: #211A17; }
    h1 { font-size: 23px; }
    h2 { font-size: 20px; }
    h3 { font-size: 18px; }
    p  { margin-bottom: 15px; color: #6E6561; }
    ul, ol { padding-left: 20px; margin-bottom: 12px; }
    li { margin-bottom: 4px; }
    a  { color: #E8720C; }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 60,
        title: Text(widget.title,
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.textSecondary)),
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          size: 22, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text('Cập nhật lần cuối: $_updatedLabel',
                        style: TextStyle(
                            fontSize: AppFontSize.bodyLarge, color: AppColors.textTertiary)),
                  ]),
                ),
              Expanded(
                child: Stack(children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                ]),
              ),
            ]),
    );
  }
}
