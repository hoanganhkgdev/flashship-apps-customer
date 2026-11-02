import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../home/widgets/home_style.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.phone,
    required this.idToken,
  });

  final String phone;
  final String idToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  String get _formattedPhone {
    final phone = widget.phone;
    if (phone.length == 10) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).resetPassword(
          phone: widget.phone,
          idToken: widget.idToken,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đặt lại mật khẩu thành công!',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: HomeStyle.peach,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
              constraints.maxHeight < 600;
          final heroHeight = (compact ? 80.0 : 176.0) +
              (MediaQuery.textScalerOf(context).scale(1) - 1)
                      .clamp(0.0, double.infinity) *
                  40;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResetHero(
                    compact: compact,
                    height: heroHeight,
                    onBack: () => context.pop(),
                  ),
                  Container(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - heroHeight)
                          .clamp(0, double.infinity),
                    ),
                    decoration: const BoxDecoration(
                      color: HomeStyle.card,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ResetHeading(phone: _formattedPhone),
                                const SizedBox(height: 20),
                                const _ResetSteps(),
                                const SizedBox(height: 20),
                                _PasswordField(
                                  label: 'Mật khẩu mới',
                                  hint: 'Nhập mật khẩu mới',
                                  controller: _passwordCtrl,
                                  enabled: !auth.isLoading,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  onVisibilityPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Vui lòng nhập mật khẩu mới';
                                    }
                                    if (value.length < 6) {
                                      return 'Mật khẩu phải tối thiểu 6 ký tự';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _PasswordField(
                                  label: 'Xác nhận mật khẩu mới',
                                  hint: 'Nhập lại mật khẩu mới',
                                  controller: _confirmCtrl,
                                  enabled: !auth.isLoading,
                                  obscureText: _obscureConfirmation,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  onVisibilityPressed: () => setState(
                                    () => _obscureConfirmation =
                                        !_obscureConfirmation,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Vui lòng xác nhận mật khẩu';
                                    }
                                    if (value != _passwordCtrl.text) {
                                      return 'Mật khẩu xác nhận không khớp';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AnimatedBuilder(
                                  animation: Listenable.merge(
                                      [_passwordCtrl, _confirmCtrl]),
                                  builder: (context, _) => Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: HomeStyle.cardMuted,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Column(children: [
                                      _PasswordRule(
                                        passed: _passwordCtrl.text.length >= 6,
                                        label: 'Mật khẩu có ít nhất 6 ký tự',
                                      ),
                                      const SizedBox(height: 8),
                                      _PasswordRule(
                                        passed: _confirmCtrl.text.isNotEmpty &&
                                            _passwordCtrl.text ==
                                                _confirmCtrl.text,
                                        label: 'Mật khẩu xác nhận trùng khớp',
                                      ),
                                    ]),
                                  ),
                                ),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorMessage(message: auth.error!),
                                ],
                                const SizedBox(height: 26),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: auth.isLoading ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _orange,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          _orange.withValues(alpha: .5),
                                      disabledForegroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      textStyle: _style(AppFontSize.bodyLarge,
                                          FontWeight.w700),
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Lưu mật khẩu mới'),
                                              SizedBox(width: 8),
                                              Icon(Icons.check_rounded,
                                                  size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const _SecurityNote(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ResetHero extends StatelessWidget {
  const _ResetHero(
      {required this.onBack, required this.compact, required this.height});

  final VoidCallback onBack;
  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) => compact
      ? SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _BackButton(onTap: onBack),
              const SizedBox(width: 14),
              const Icon(Icons.lock_reset_rounded, size: 27, color: _orange),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Tạo mật khẩu mới',
                      style: _style(AppFontSize.bodyLarge, FontWeight.w700,
                          HomeStyle.ink))),
            ]),
          ),
        )
      : SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                top: -44,
                right: -34,
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _orange.withValues(alpha: .08),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: _BackButton(onTap: onBack),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.password_rounded,
                        size: 34,
                        color: _orange,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'FLASH SHIP',
                      style: _style(20, FontWeight.w900, HomeStyle.ink)
                          .copyWith(letterSpacing: .3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
}

class _ResetHeading extends StatelessWidget {
  const _ResetHeading({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 56,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đặt lại mật khẩu',
                    style: _style(
                        AppFontSize.heading, FontWeight.w800, HomeStyle.ink)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style:
                        _style(AppFontSize.body, FontWeight.w500, _muted, 1.4),
                    children: [
                      const TextSpan(text: 'Tạo mật khẩu mới cho '),
                      TextSpan(
                        text: phone,
                        style: _style(
                            AppFontSize.body, FontWeight.w700, HomeStyle.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ResetSteps extends StatelessWidget {
  const _ResetSteps();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: HomeStyle.cardMuted,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Row(
          children: [
            Expanded(
              child: _ResetStep(
                  icon: Icons.check_rounded,
                  label: 'Số điện thoại',
                  complete: true),
            ),
            _StepLine(active: true),
            Expanded(
              child: _ResetStep(
                  icon: Icons.check_rounded, label: 'Xác thực', complete: true),
            ),
            _StepLine(active: true),
            Expanded(
              child:
                  _ResetStep(number: '3', label: 'Mật khẩu mới', active: true),
            ),
          ],
        ),
      );
}

class _ResetStep extends StatelessWidget {
  const _ResetStep({
    this.number,
    this.icon,
    required this.label,
    this.active = false,
    this.complete = false,
  });

  final String? number;
  final IconData? icon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active || complete ? _orange : HomeStyle.cardMuted,
              shape: BoxShape.circle,
              border: active || complete
                  ? null
                  : Border.all(color: HomeStyle.divider),
            ),
            child: icon != null
                ? Icon(icon, size: 16, color: Colors.white)
                : Text(
                    number ?? '',
                    style: _style(AppFontSize.caption, FontWeight.w700,
                        active ? Colors.white : _muted),
                  ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _style(
                AppFontSize.caption,
                active ? FontWeight.w700 : FontWeight.w500,
                active ? _orange : _muted),
          ),
        ],
      );
}

class _StepLine extends StatelessWidget {
  const _StepLine({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 23),
        color: active ? _orange : HomeStyle.divider,
      );
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.passed, required this.label});

  final bool passed;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
              passed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: passed ? AppColors.success : HomeStyle.muted),
          const SizedBox(width: 7),
          Expanded(
              child: Text(
            label,
            style:
                _style(AppFontSize.caption, FontWeight.w500, HomeStyle.muted),
          )),
        ],
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 16, color: AppColors.success),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Lưu thành công, bạn sẽ quay lại đăng nhập',
              textAlign: TextAlign.center,
              style:
                  _style(AppFontSize.caption, FontWeight.w500, HomeStyle.muted),
            ),
          ),
        ],
      );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Quay lại',
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: HomeStyle.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      icon: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 18, color: HomeStyle.ink),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscureText,
    required this.onVisibilityPressed,
    required this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onVisibilityPressed;
  final FormFieldValidator<String> validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _style(AppFontSize.body, FontWeight.w600, _ink)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                _style(AppFontSize.bodyLarge, FontWeight.w500, _softMuted),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 20, color: HomeStyle.muted),
            suffixIcon: IconButton(
              tooltip: obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: onVisibilityPressed,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            suffixIconColor: _muted,
            filled: true,
            fillColor: HomeStyle.cardMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(HomeStyle.divider),
            enabledBorder: _border(HomeStyle.divider),
            focusedBorder: _border(_orange, width: 1.5),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, width: 1.5),
            errorStyle: _style(AppFontSize.caption, null, AppColors.danger),
          ),
          validator: validator,
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return GlassInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style:
                  _style(AppFontSize.body, FontWeight.w500, AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

const _ink = AppColors.textPrimary;
const _muted = AppColors.textSecondary;
const _softMuted = AppColors.textTertiary;
const _orange = HomeStyle.orange;

TextStyle _style(
  double size, [
  FontWeight? weight,
  Color? color,
  double? height,
]) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}
