import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
                const SizedBox(height: 24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 30,
                    color: _orange,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quên mật khẩu?',
                  style: _style(AppFontSize.xlarge, FontWeight.w600, _ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập số điện thoại đã đăng ký, chúng tôi sẽ gửi mã xác thực để đặt lại mật khẩu',
                  style: _style(AppFontSize.bodyLarge, FontWeight.w500, _muted, 1.45),
                ),
                const SizedBox(height: 26),
                Text(
                  'Số điện thoại',
                  style: _style(AppFontSize.body, FontWeight.w600, _ink),
                ),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
                  decoration: InputDecoration(
                    hintText: '0912 345 678',
                    hintStyle: _style(AppFontSize.bodyLarge, FontWeight.w600, _softMuted),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      size: 22,
                      color: _muted,
                    ),
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
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
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
                        : const Text('Gửi mã xác thực'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
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
