import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
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

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Đổi mật khẩu',
                          style: TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      SizedBox(height: 4),
                      Text('Cập nhật mật khẩu cho tài khoản',
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ])),
              ]),
            ),
            Expanded(
                child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const LiquidGlass(
                  padding: EdgeInsets.all(14),
                  child: Row(children: [
                    GlassIcon(
                        icon: Icons.lock_outline_rounded,
                        color: HomeStyle.orange,
                        size: 42,
                        iconSize: 22),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Chọn mật khẩu mới dễ nhớ với bạn và khó đoán với người khác.',
                            style: TextStyle(
                                fontSize: AppFontSize.body,
                                height: 1.4,
                                color: HomeStyle.muted))),
                  ]),
                ),
                const SizedBox(height: 12),
                // ── Card 1: mật khẩu hiện tại ──────────────────────────
                _card(
                    child: _PassRow(
                  label: 'Mật khẩu hiện tại',
                  hint: 'Nhập mật khẩu hiện tại',
                  controller: _curCtrl,
                  show: _showCur,
                  onChanged: (_) => setState(() {}),
                  onToggle: () => setState(() => _showCur = !_showCur),
                )),

                const SizedBox(height: 12),

                // ── Card 2: mới + xác nhận ─────────────────────────────
                _card(
                    child: Column(children: [
                  _PassRow(
                    label: 'Mật khẩu mới',
                    hint: 'Tối thiểu 6 ký tự',
                    controller: _newCtrl,
                    show: _showNew,
                    onChanged: (_) => setState(() {}),
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  _PassRow(
                    label: 'Xác nhận mật khẩu mới',
                    hint: 'Nhập lại mật khẩu mới',
                    controller: _confCtrl,
                    show: _showConf,
                    onToggle: () => setState(() => _showConf = !_showConf),
                  ),
                ])),

                const SizedBox(height: 14),
                LiquidGlass(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    _PasswordRule(
                      passed: _newCtrl.text.length >= 6,
                      label: 'Tối thiểu 6 ký tự',
                    ),
                    const SizedBox(height: 12),
                    _PasswordRule(
                      passed: _newCtrl.text.isNotEmpty &&
                          _newCtrl.text != _curCtrl.text,
                      label: 'Khác với mật khẩu hiện tại',
                    ),
                  ]),
                ),

                // ── Error banner ───────────────────────────────────────
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.glass),
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

                // ── Save button ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: LiquidGlass(
                      child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            HomeStyle.orange.withValues(alpha: .16),
                        foregroundColor: HomeStyle.orange,
                        shape: RoundedRectangleBorder(
                            borderRadius: HomeStyle.radius,
                            side: BorderSide(
                                color: HomeStyle.orange.withValues(alpha: .2))),
                        disabledBackgroundColor: AppColors.divider,
                        elevation: 0,
                        textStyle: TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w600),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: HomeStyle.orange))
                          : const Text('Cập nhật mật khẩu'),
                    ),
                  )),
                ),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => LiquidGlass(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
          passed ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
          size: 21,
          color: passed ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    color: passed
                        ? AppColors.textSecondary
                        : AppColors.textTertiary))),
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
  const _PassRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.show,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            obscureText: !show,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: .4),
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  color: AppColors.textTertiary),
              border: const GlassInputBorder(),
              enabledBorder: GlassInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: .8)),
              ),
              focusedBorder: GlassInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}
