import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).forgotPassword(phone);
    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: {
        'flow': 'reset-password',
        'phone': phone,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return LiquidBackdrop(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _BackButton(onTap: () => context.pop()),
            ),
            Expanded(
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                    child: GlassIcon(
                                        icon: Icons.lock_reset_rounded,
                                        color: _orange,
                                        size: 72,
                                        iconSize: 36)),
                                const SizedBox(height: 20),
                                Center(
                                    child: Text(
                                  'Quên mật khẩu?',
                                  style: _style(AppFontSize.xlarge,
                                      FontWeight.w800, _ink),
                                )),
                                const SizedBox(height: 8),
                                Center(
                                    child: Text(
                                  'Nhận mã để đặt lại mật khẩu',
                                  textAlign: TextAlign.center,
                                  style: _style(AppFontSize.bodyLarge,
                                      FontWeight.w500, _muted, 1.45),
                                )),
                                const SizedBox(height: 26),
                                LiquidGlass(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Số điện thoại',
                                          style: _style(AppFontSize.body,
                                              FontWeight.w600, _ink),
                                        ),
                                        const SizedBox(height: 7),
                                        TextFormField(
                                          controller: _phoneCtrl,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _submit(),
                                          style: _style(AppFontSize.bodyLarge,
                                              FontWeight.w600, _ink),
                                          decoration: InputDecoration(
                                            hintText: '0912 345 678',
                                            hintStyle: _style(
                                                AppFontSize.bodyLarge,
                                                FontWeight.w600,
                                                _softMuted),
                                            prefixIcon: const Padding(
                                                padding: EdgeInsets.all(9),
                                                child: GlassIcon(
                                                    icon: Icons.phone_outlined,
                                                    color: _orange,
                                                    size: 32,
                                                    iconSize: 17)),
                                            filled: true,
                                            fillColor: Colors.white
                                                .withValues(alpha: .46),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 17,
                                            ),
                                            border: _border(Colors.transparent),
                                            enabledBorder: _border(Colors.white
                                                .withValues(alpha: .8)),
                                            focusedBorder:
                                                _border(_orange, width: 1.5),
                                            errorBorder:
                                                _border(AppColors.danger),
                                            focusedErrorBorder: _border(
                                                AppColors.danger,
                                                width: 1.5),
                                            errorStyle: _style(
                                                AppFontSize.caption,
                                                null,
                                                AppColors.danger),
                                          ),
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
                                        if (auth.error != null) ...[
                                          const SizedBox(height: 12),
                                          _ErrorMessage(message: auth.error!),
                                        ],
                                        const SizedBox(height: 28),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFF9454),
                                                    _orange
                                                  ]),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: _orange.withValues(
                                                        alpha: .2),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 6))
                                              ],
                                            ),
                                            child: FilledButton(
                                              onPressed: auth.isLoading
                                                  ? null
                                                  : _submit,
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: _orange
                                                    .withValues(alpha: .5),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18)),
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
                                                  : const Text(
                                                      'Gửi mã xác thực'),
                                            ),
                                          ),
                                        ),
                                      ]),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                    child: TextButton(
                                  onPressed: () => context.pop(),
                                  child: const Text('Quay lại đăng nhập'),
                                )),
                              ],
                            ),
                          ),
                        )))),
          ],
        ),
      ),
    ));
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return GlassInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
              tooltip: 'Quay lại',
              onPressed: onTap,
              icon:
                  const Icon(Icons.arrow_back_rounded, size: 22, color: _ink))),
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
