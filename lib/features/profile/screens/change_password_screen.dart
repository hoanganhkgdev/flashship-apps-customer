import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';
import '../../auth/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ChangePasswordScreen> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _showCur = false;
  bool _showNew = false;
  bool _showConf = false;
  bool _saving = false;
  String? _error;

  void _onChanged(String value) => setState(() => _error = null);

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_curCtrl.text.isEmpty) {
      setState(() => _error = 'Nhập mật khẩu hiện tại');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }
    if (_newCtrl.text == _curCtrl.text) {
      setState(() => _error = 'Mật khẩu mới phải khác mật khẩu hiện tại');
      return;
    }
    if (_newCtrl.text != _confCtrl.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref.read(authProvider.notifier).changePassword(
          current: _curCtrl.text,
          next: _newCtrl.text,
        );
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeStyle.background,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: HomeStyle.card,
          border: Border(top: BorderSide(color: HomeStyle.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      HomeStyle.orange.withValues(alpha: .5),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w700),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Cập nhật mật khẩu'),
                      ]),
              ),
            ),
          ),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9DE),
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
                    backgroundColor: HomeStyle.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đổi mật khẩu',
                          style: TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      SizedBox(height: 3),
                      Text('Tăng cường bảo mật cho tài khoản',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: HomeStyle.peach,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        size: 23, color: HomeStyle.orange),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bảo vệ tài khoản của bạn',
                            style: TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink)),
                        SizedBox(height: 3),
                        Text('Dùng mật khẩu dễ nhớ với bạn nhưng khó đoán.',
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                height: 1.35,
                                color: HomeStyle.muted)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              _FlatCard(
                child: Column(children: [
                  const _CardHeading(
                    icon: Icons.password_rounded,
                    label: 'Thông tin bảo mật',
                  ),
                  const Divider(height: 1, color: HomeStyle.divider),
                  _PassRow(
                    label: 'Mật khẩu hiện tại',
                    hint: 'Nhập mật khẩu hiện tại',
                    controller: _curCtrl,
                    show: _showCur,
                    onChanged: (_) => setState(() {}),
                    onToggle: () => setState(() => _showCur = !_showCur),
                  ),
                  const Divider(height: 1, color: HomeStyle.divider),
                  _PassRow(
                    label: 'Mật khẩu mới',
                    hint: 'Tối thiểu 6 ký tự',
                    controller: _newCtrl,
                    show: _showNew,
                    onChanged: (_) => setState(() {}),
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  const Divider(height: 1, color: HomeStyle.divider),
                  _PassRow(
                    label: 'Xác nhận mật khẩu mới',
                    hint: 'Nhập lại mật khẩu mới',
                    controller: _confCtrl,
                    show: _showConf,
                    onChanged: (_) => setState(() {}),
                    onToggle: () => setState(() => _showConf = !_showConf),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _FlatCard(
                child: Column(children: [
                  const _CardHeading(
                    icon: Icons.lock_outline_rounded,
                    label: 'Xác nhận tài khoản',
                  ),
                  _PassRow(
                    label: 'Mật khẩu hiện tại',
                    hint: 'Nhập mật khẩu đang sử dụng',
                    controller: _curCtrl,
                    show: _showCur,
                    autofillHints: const [AutofillHints.password],
                    onChanged: _onChanged,
                    onToggle: () => setState(() => _showCur = !_showCur),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              _FlatCard(
                child: Column(children: [
                  const _CardHeading(
                    icon: Icons.lock_reset_rounded,
                    label: 'Tạo mật khẩu mới',
                  ),
                  _PassRow(
                    label: 'Mật khẩu mới',
                    hint: 'Tối thiểu 6 ký tự',
                    controller: _newCtrl,
                    show: _showNew,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: _onChanged,
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  _PassRow(
                    label: 'Xác nhận mật khẩu mới',
                    hint: 'Nhập lại mật khẩu mới',
                    controller: _confCtrl,
                    show: _showConf,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: _onChanged,
                    onToggle: () => setState(() => _showConf = !_showConf),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HomeStyle.cardMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Yêu cầu mật khẩu',
                              style: TextStyle(
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.ink,
                              )),
                          const SizedBox(height: 12),
                          _PasswordRule(
                            passed: _newCtrl.text.length >= 6,
                            label: 'Tối thiểu 6 ký tự',
                          ),
                          const SizedBox(height: 10),
                          _PasswordRule(
                            passed: _curCtrl.text.isNotEmpty &&
                                _newCtrl.text.isNotEmpty &&
                                _newCtrl.text != _curCtrl.text,
                            label: 'Khác với mật khẩu hiện tại',
                          ),
                          const SizedBox(height: 10),
                          _PasswordRule(
                            passed: _confCtrl.text.isNotEmpty &&
                                _newCtrl.text == _confCtrl.text,
                            label: 'Mật khẩu xác nhận trùng khớp',
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: AppFontSize.body))),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HomeStyle.peach,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: HomeStyle.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.ink)),
          ),
        ]),
      );
}

class _FlatCard extends StatelessWidget {
  const _FlatCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: HomeStyle.divider),
        ),
        child: child,
      );
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.passed, required this.label});
  final bool passed;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(
          passed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: passed ? AppColors.success : HomeStyle.muted,
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: passed ? FontWeight.w600 : FontWeight.w500,
                    color: passed ? HomeStyle.ink : HomeStyle.muted))),
      ]);
}

// ── Password row (label + filled field) ──────────────────────────────────────

class _PassRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  const _PassRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.show,
    required this.onToggle,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: HomeStyle.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: !show,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w600,
                color: HomeStyle.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: HomeStyle.cardMuted,
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  size: 19, color: HomeStyle.muted),
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: AppFontSize.body, color: HomeStyle.muted),
              border: _border(HomeStyle.divider),
              enabledBorder: _border(HomeStyle.divider),
              focusedBorder: _border(HomeStyle.orange, 1.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: IconButton(
                tooltip: show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                onPressed: onToggle,
                icon: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 22,
                  color: HomeStyle.muted,
                ),
              ),
            ),
          ),
        ]),
      );
}
