import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../home/widgets/home_style.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ok) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return LiquidBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(child: _BrandHeader()),
                          const SizedBox(height: 24),
                          LiquidGlass(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Chào mừng trở lại!',
                                      style: TextStyle(
                                          fontSize: AppFontSize.xlarge,
                                          fontWeight: FontWeight.w800,
                                          color: HomeStyle.ink)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Đăng nhập để tiếp tục',
                                    style: _style(AppFontSize.bodyLarge,
                                        FontWeight.w500, _muted, 1.35),
                                  ),
                                  const SizedBox(height: 22),
                                  _AuthField(
                                    label: 'Số điện thoại',
                                    controller: _phoneCtrl,
                                    hint: '0912 345 678',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    prefixIcon: Icons.phone_outlined,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Vui lòng nhập số điện thoại';
                                      }
                                      if (value.trim().length < 9) {
                                        return 'Số điện thoại không hợp lệ';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _AuthField(
                                    label: 'Mật khẩu',
                                    controller: _passwordCtrl,
                                    hint: '••••••••',
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    prefixIcon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Hiện mật khẩu'
                                          : 'Ẩn mật khẩu',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Vui lòng nhập mật khẩu';
                                      }
                                      if (value.length < 6) {
                                        return 'Mật khẩu phải tối thiểu 6 ký tự';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          context.push('/forgot-password'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _orange,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        minimumSize: const Size(0, 44),
                                        textStyle: _style(
                                            AppFontSize.body, FontWeight.w600),
                                      ),
                                      child: const Text('Quên mật khẩu?'),
                                    ),
                                  ),
                                  if (auth.error != null) ...[
                                    const SizedBox(height: 12),
                                    _ErrorMessage(message: auth.error!),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: HomeStyle.radius,
                                        gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFF9454),
                                              Color(0xFFF56333)
                                            ]),
                                        boxShadow: [
                                          BoxShadow(
                                              color: _orange.withValues(
                                                  alpha: .22),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6))
                                        ],
                                      ),
                                      child: FilledButton(
                                        onPressed:
                                            auth.isLoading ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 54),
                                          disabledBackgroundColor:
                                              _orange.withValues(alpha: .5),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: HomeStyle.radius,
                                              side: BorderSide(
                                                  color: _orange.withValues(
                                                      alpha: .2))),
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.transparent,
                                          elevation: 0,
                                          textStyle: _style(
                                              AppFontSize.bodyLarge,
                                              FontWeight.w600),
                                        ),
                                        child: auth.isLoading
                                            ? const SizedBox.square(
                                                dimension: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                    Text('Đăng nhập'),
                                                    SizedBox(width: 10),
                                                    Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 20),
                                                  ]),
                                      ),
                                    ),
                                  ),
                                ]),
                          ),
                          const SizedBox(height: 22),
                          Center(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Chưa có tài khoản? ',
                                  style: _style(AppFontSize.body,
                                      FontWeight.w500, _muted),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/register'),
                                  child: Text(
                                    'Đăng ký ngay',
                                    style: _style(AppFontSize.body,
                                        FontWeight.w600, _orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 86,
          child: Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: -.14,
              child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: .15),
                    borderRadius: HomeStyle.radius,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .7)),
                  )),
            ),
            const GlassIcon(
                icon: Icons.local_shipping_rounded,
                color: _orange,
                size: 64,
                iconSize: 32),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Flash Ship', style: _style(30, FontWeight.w800, HomeStyle.ink)),
        const SizedBox(height: 8),
        const Text('Giao hàng · Mua hộ · Đặt xe',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: AppFontSize.body, color: HomeStyle.muted)),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

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
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _style(
                AppFontSize.bodyLarge, FontWeight.w600, AppColors.textTertiary),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(9),
              child: GlassIcon(
                  icon: prefixIcon, color: _orange, size: 32, iconSize: 17),
            ),
            suffixIcon: suffixIcon,
            suffixIconColor: _muted,
            filled: true,
            fillColor: Colors.white.withValues(alpha: .46),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: _border(AppColors.divider),
            enabledBorder: _border(AppColors.divider),
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
      borderRadius: BorderRadius.circular(AppRadius.glass),
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 17),
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
