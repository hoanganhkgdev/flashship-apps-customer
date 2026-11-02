import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';
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
    final ok = await ref.read(authProvider.notifier).sendOtp(phone);
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
                  _ForgotHero(
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
                                const _ForgotHeading(),
                                const SizedBox(height: 20),
                                const _ResetSteps(),
                                const SizedBox(height: 20),
                                Text(
                                  'Số điện thoại đã đăng ký',
                                  style: _style(
                                      AppFontSize.body, FontWeight.w600, _ink),
                                ),
                                const SizedBox(height: 7),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: _style(AppFontSize.bodyLarge,
                                      FontWeight.w600, _ink),
                                  decoration: InputDecoration(
                                    hintText: 'Nhập số điện thoại',
                                    hintStyle: _style(AppFontSize.bodyLarge,
                                        FontWeight.w500, _softMuted),
                                    prefixIcon: const Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 20,
                                      color: HomeStyle.muted,
                                    ),
                                    filled: true,
                                    fillColor: HomeStyle.cardMuted,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    border: _border(HomeStyle.divider),
                                    enabledBorder: _border(HomeStyle.divider),
                                    focusedBorder: _border(_orange, width: 1.5),
                                    errorBorder: _border(AppColors.danger),
                                    focusedErrorBorder:
                                        _border(AppColors.danger, width: 1.5),
                                    errorStyle: _style(AppFontSize.caption,
                                        null, AppColors.danger),
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
                                const SizedBox(height: 12),
                                const _OtpNote(),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorMessage(message: auth.error!),
                                ],
                                const SizedBox(height: 24),
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
                                              Text('Gửi mã xác thực'),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => context.pop(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _muted,
                                      minimumSize: const Size(0, 44),
                                      textStyle: _style(
                                          AppFontSize.body, FontWeight.w600),
                                    ),
                                    icon: const Icon(Icons.arrow_back_rounded,
                                        size: 18),
                                    label: const Text('Quay lại đăng nhập'),
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

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return GlassInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ForgotHero extends StatelessWidget {
  const _ForgotHero({
    required this.onBack,
    required this.compact,
    required this.height,
  });

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
                  child: Text('Khôi phục tài khoản',
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
                        Icons.lock_reset_rounded,
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

class _ForgotHeading extends StatelessWidget {
  const _ForgotHeading();

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
                Text('Quên mật khẩu?',
                    style: _style(
                        AppFontSize.heading, FontWeight.w800, HomeStyle.ink)),
                const SizedBox(height: 4),
                Text(
                  'Lấy lại mật khẩu trong vài bước',
                  style:
                      _style(AppFontSize.body, FontWeight.w500, _muted, 1.35),
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
                number: '1',
                label: 'Số điện thoại',
                active: true,
              ),
            ),
            _StepLine(),
            Expanded(child: _ResetStep(number: '2', label: 'Xác thực')),
            _StepLine(),
            Expanded(child: _ResetStep(number: '3', label: 'Mật khẩu mới')),
          ],
        ),
      );
}

class _ResetStep extends StatelessWidget {
  const _ResetStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _orange : HomeStyle.cardMuted,
              shape: BoxShape.circle,
              border: active ? null : Border.all(color: HomeStyle.divider),
            ),
            child: Text(
              number,
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
  const _StepLine();

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 1,
        margin: const EdgeInsets.only(bottom: 23),
        color: HomeStyle.divider,
      );
}

class _OtpNote extends StatelessWidget {
  const _OtpNote();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 17, color: AppColors.info),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Mã xác thực sẽ được gửi đến số điện thoại này.',
              style: _style(
                  AppFontSize.caption, FontWeight.w500, HomeStyle.muted, 1.4),
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
