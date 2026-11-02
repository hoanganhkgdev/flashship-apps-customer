import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: HomeStyle.peach,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
              constraints.maxHeight < 600;
          final extraScale = (MediaQuery.textScalerOf(context).scale(1) - 1)
              .clamp(0.0, double.infinity);
          final heroHeight = (compact ? 104.0 : 200.0) + extraScale * 40;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LoginHero(compact: compact, height: heroHeight),
                  Container(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - heroHeight)
                          .clamp(0, double.infinity),
                    ),
                    decoration: const BoxDecoration(
                      color: HomeStyle.card,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
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
                                const _LoginHeading(),
                                const SizedBox(height: 22),
                                _AuthField(
                                  label: 'Số điện thoại',
                                  controller: _phoneCtrl,
                                  hint: 'Nhập số điện thoại',
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber
                                  ],
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: Icons.phone_iphone_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Vui lòng nhập số điện thoại';
                                    }
                                    if (value.trim().length < 9) {
                                      return 'Số điện thoại không hợp lệ';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _AuthField(
                                  label: 'Mật khẩu',
                                  controller: _passwordCtrl,
                                  hint: 'Nhập mật khẩu',
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.password],
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
                                      size: 21,
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
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push('/forgot-password'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _orange,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      minimumSize: const Size(0, 44),
                                      textStyle: _style(
                                          AppFontSize.body, FontWeight.w700),
                                    ),
                                    child: const Text('Quên mật khẩu?'),
                                  ),
                                ),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 6),
                                  _ErrorMessage(message: auth.error!),
                                ],
                                const SizedBox(height: 10),
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
                                              Text('Đăng nhập'),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const _SafeNote(),
                                const SizedBox(height: 18),
                                Row(children: [
                                  const Expanded(
                                      child: Divider(color: HomeStyle.divider)),
                                  const SizedBox(width: 12),
                                  Flexible(
                                      child: Text('Chưa có tài khoản?',
                                          textAlign: TextAlign.center,
                                          style: _style(AppFontSize.caption,
                                              FontWeight.w500, _muted))),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                      child: Divider(color: HomeStyle.divider)),
                                ]),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => context.go('/register'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 50),
                                      foregroundColor: _orange,
                                      side: const BorderSide(
                                          color: HomeStyle.divider),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Tạo tài khoản',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
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

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.compact, required this.height});

  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -32,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: 22,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: compact
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Image.asset('assets/images/logo.png',
                            semanticLabel: 'Flash Ship'),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text('FLASH SHIP',
                              style:
                                  _style(22, FontWeight.w900, HomeStyle.ink))),
                    ]),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'Flash Ship',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'FLASH SHIP',
                          style: _style(24, FontWeight.w900, HomeStyle.ink)
                              .copyWith(letterSpacing: .4),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Giao hàng · Mua hộ · Đặt xe',
                          textAlign: TextAlign.center,
                          style: _style(AppFontSize.body, FontWeight.w500,
                              HomeStyle.muted),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 48,
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
                Text('Đăng nhập',
                    style: _style(
                        AppFontSize.heading, FontWeight.w800, HomeStyle.ink)),
                const SizedBox(height: 4),
                Text(
                  'Chào mừng bạn trở lại Flash Ship',
                  style:
                      _style(AppFontSize.body, FontWeight.w500, _muted, 1.35),
                ),
              ],
            ),
          ),
        ],
      );
}

class _SafeNote extends StatelessWidget {
  const _SafeNote();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 16, color: AppColors.success),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Không chia sẻ mật khẩu với người khác',
              textAlign: TextAlign.center,
              style:
                  _style(AppFontSize.caption, FontWeight.w500, HomeStyle.muted),
            ),
          ),
        ],
      );
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
    this.autofillHints,
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
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _style(AppFontSize.body, FontWeight.w600, _ink)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          autofillHints: autofillHints,
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
            prefixIcon: Icon(prefixIcon, size: 20, color: HomeStyle.muted),
            suffixIcon: suffixIcon,
            suffixIconColor: _muted,
            filled: true,
            fillColor: HomeStyle.cardMuted,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
