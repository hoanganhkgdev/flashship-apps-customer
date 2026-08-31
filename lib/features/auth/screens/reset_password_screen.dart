import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.phone,
    required this.otp,
  });

  final String phone;
  final String otp;

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

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).resetPassword(
          phone: widget.phone,
          otp: widget.otp,
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
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 18, 24, keyboardBottom + 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(onTap: () => context.pop()),
                const SizedBox(height: 26),
                Text(
                  'Đặt lại mật khẩu',
                  style: _style(AppFontSize.xlarge, FontWeight.w600, _ink),
                ),
                const SizedBox(height: 7),
                Text(
                  'Tạo mật khẩu mới cho tài khoản của bạn',
                  style: _style(AppFontSize.bodyLarge, FontWeight.w500, _muted),
                ),
                const SizedBox(height: 28),
                _PasswordField(
                  label: 'Mật khẩu mới',
                  controller: _passwordCtrl,
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
                const Padding(
                  padding: EdgeInsets.only(left: 2, top: 6),
                  child: Text(
                    'Tối thiểu 6 ký tự',
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w500,
                      color: _softMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _PasswordField(
                  label: 'Xác nhận mật khẩu mới',
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  onVisibilityPressed: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
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
                if (auth.error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorMessage(message: auth.error!),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _orange,
                      disabledBackgroundColor: _orange.withValues(alpha: .5),
                      shape: const StadiumBorder(),
                      elevation: 0,
                      textStyle: _style(AppFontSize.bodyLarge, FontWeight.w600),
                    ),
                    child: auth.isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Xác nhận'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: _ink,
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onVisibilityPressed,
    required this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onVisibilityPressed;
  final FormFieldValidator<String> validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _style(AppFontSize.body, FontWeight.w600, _ink)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: _style(AppFontSize.bodyLarge, FontWeight.w600, _softMuted),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 22,
              color: _muted,
            ),
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
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
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
    return OutlineInputBorder(
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
              style: _style(AppFontSize.body, FontWeight.w500, AppColors.danger),
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
const _orange = AppColors.primary;

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
