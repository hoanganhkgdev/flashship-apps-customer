import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _otpCtrl      = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).resetPassword(
      phone:    widget.phone,
      otp:      _otpCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đặt lại mật khẩu thành công!',
            style: GoogleFonts.beVietnamPro(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 16),

                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Đặt lại mật khẩu',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Mã OTP đã gửi đến\n'),
                      TextSpan(
                        text: widget.phone,
                        style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // OTP field
                _ResetField(
                  controller: _otpCtrl,
                  hint: 'Mã OTP',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.pin_outlined,
                      size: 20, color: AppColors.textSecondary),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mã OTP';
                    if (v.trim().length < 4) return 'Mã OTP không hợp lệ';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // New password field
                _ResetField(
                  controller: _passwordCtrl,
                  hint: 'Mật khẩu mới',
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePass = !_obscurePass),
                    child: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                    if (v.length < 6) return 'Mật khẩu phải tối thiểu 6 ký tự';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Confirm password field
                _ResetField(
                  controller: _confirmCtrl,
                  hint: 'Xác nhận mật khẩu',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                    if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                    return null;
                  },
                ),

                // Error
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      textStyle: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
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

// ── Input field ────────────────────────────────────────────────────────────────

class _ResetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _ResetField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: GoogleFonts.beVietnamPro(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
          errorStyle: GoogleFonts.beVietnamPro(fontSize: 12),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: prefixIcon,
                )
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
        validator: validator,
      );
}
