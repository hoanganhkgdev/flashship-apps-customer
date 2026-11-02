import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/widgets/home_style.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.regData});

  final Map<String, dynamic> regData;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _otpSending = false;
  String? _error;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  String get _phone => widget.regData['phone'] as String? ?? '';

  String get _formattedPhone {
    if (_phone.length == 10) {
      return '${_phone.substring(0, 4)} ${_phone.substring(4, 7)} ${_phone.substring(7)}';
    }
    return _phone;
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_resendSeconds == 0) {
        _resendTimer?.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _otpSending || _loading) return;
    setState(() {
      _otpSending = true;
      _error = null;
      _otpCtrl.clear();
    });
    final ok = await ref.read(authProvider.notifier).sendOtp(_phone);
    if (!mounted) return;
    setState(() => _otpSending = false);
    if (ok) {
      _startResendTimer();
    } else {
      setState(() {
        _error = ref.read(authProvider).error ?? 'Gửi lại OTP thất bại';
      });
    }
  }

  Future<void> _submit() async {
    if (_loading || _otpSending) return;
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final idToken = await ref.read(authProvider.notifier).confirmCode(otp);
    if (!mounted) return;
    if (idToken == null) {
      setState(() {
        _loading = false;
        _error = ref.read(authProvider).error ?? 'Mã OTP không đúng';
      });
      return;
    }
    if (widget.regData['flow'] == 'reset-password') {
      setState(() => _loading = false);
      context.push('/reset-password', extra: {
        'phone': _phone,
        'id_token': idToken,
      });
      return;
    }

    final data = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
          phone: _phone,
          idToken: idToken,
          name: data['name'] as String? ?? '',
          password: data['password'] as String? ?? '',
          cityId: data['city_id'] as int?,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() {
        _loading = false;
        _error =
            ref.read(authProvider).error ?? 'Mã OTP không đúng hoặc đã hết hạn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeComplete = _otpCtrl.text.length == 6;
    final isResetFlow = widget.regData['flow'] == 'reset-password';

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
                  _OtpHero(
                    compact: compact,
                    height: heroHeight,
                    sending: _otpSending,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _OtpHeading(phone: _formattedPhone),
                              if (isResetFlow) ...[
                                const SizedBox(height: 20),
                                const _ResetSteps(),
                              ],
                              const SizedBox(height: 20),
                              Text(
                                'Nhập mã xác thực',
                                style: _style(
                                    AppFontSize.body, FontWeight.w700, _ink),
                              ),
                              const SizedBox(height: 10),
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: _otpSending ? .45 : 1,
                                child: IgnorePointer(
                                  ignoring: _otpSending,
                                  child: _OtpInputRow(
                                    enabled: !_loading && !_otpSending,
                                    controller: _otpCtrl,
                                    onChanged: () =>
                                        setState(() => _error = null),
                                    onFilled: _submit,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                _ErrorMessage(message: _error!),
                              ],
                              const SizedBox(height: 20),
                              _ResendPanel(
                                seconds: _resendSeconds,
                                sending: _otpSending,
                                verifying: _loading,
                                onResend: _resend,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton(
                                  onPressed:
                                      !codeComplete || _loading || _otpSending
                                          ? null
                                          : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _orange,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: HomeStyle.divider,
                                    disabledForegroundColor: _muted,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    textStyle: _style(
                                        AppFontSize.bodyLarge, FontWeight.w700),
                                  ),
                                  child: _loading
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
                                            Text('Xác nhận mã'),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded,
                                                size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.verified_user_outlined,
                                      size: 16, color: AppColors.success),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Không chia sẻ mã OTP với người khác',
                                      textAlign: TextAlign.center,
                                      style: _style(AppFontSize.caption,
                                          FontWeight.w500, HomeStyle.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

class _OtpHero extends StatelessWidget {
  const _OtpHero({
    required this.sending,
    required this.onBack,
    required this.compact,
    required this.height,
  });

  final bool sending;
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
              const Icon(Icons.sms_outlined, size: 27, color: _orange),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      sending ? 'Đang gửi lại mã…' : 'Xác thực số điện thoại',
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
                      child: sending
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _orange,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.sms_outlined,
                              size: 34,
                              color: _orange,
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      sending ? 'Đang gửi lại mã…' : 'FLASH SHIP',
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

class _OtpHeading extends StatelessWidget {
  const _OtpHeading({required this.phone});

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
                Text('Nhập mã OTP',
                    style: _style(
                        AppFontSize.heading, FontWeight.w800, HomeStyle.ink)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style:
                        _style(AppFontSize.body, FontWeight.w500, _muted, 1.4),
                    children: [
                      const TextSpan(text: 'Mã gồm 6 số đã được gửi đến '),
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
                complete: true,
              ),
            ),
            _StepLine(active: true),
            Expanded(
              child: _ResetStep(number: '2', label: 'Xác thực', active: true),
            ),
            _StepLine(),
            Expanded(child: _ResetStep(number: '3', label: 'Mật khẩu mới')),
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

class _ResendPanel extends StatelessWidget {
  const _ResendPanel({
    required this.seconds,
    required this.sending,
    required this.verifying,
    required this.onResend,
  });

  final int seconds;
  final bool sending;
  final bool verifying;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: HomeStyle.peach,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _orange,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 19, color: _orange),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Không nhận được mã?',
                      style: _style(
                          AppFontSize.body, FontWeight.w600, HomeStyle.ink)),
                  const SizedBox(height: 2),
                  Text(
                    sending
                        ? 'Đang gửi lại mã xác thực'
                        : seconds > 0
                            ? 'Có thể gửi lại sau ${seconds}s'
                            : 'Bạn có thể yêu cầu mã mới',
                    style: _style(
                        AppFontSize.caption, FontWeight.w500, HomeStyle.muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed:
                  seconds == 0 && !sending && !verifying ? onResend : null,
              style: TextButton.styleFrom(
                foregroundColor: _orange,
                disabledForegroundColor: _softMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Gửi lại'),
            ),
          ],
        ),
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

class _OtpInputRow extends StatefulWidget {
  const _OtpInputRow({
    required this.controller,
    required this.onFilled,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onFilled;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  State<_OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<_OtpInputRow> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focusNode.requestFocus : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  labelText: 'Mã OTP gồm 6 chữ số',
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (value) {
                  widget.onChanged();
                  setState(() {});
                  if (value.length == 6) widget.onFilled();
                },
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final boxWidth = (constraints.maxWidth - gap * 5) / 6;
              final width = boxWidth.clamp(0.0, 58.0);
              final code = widget.controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final filled = index < code.length;
                  final active = _focusNode.hasFocus && index == code.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: width,
                    height: 56,
                    decoration: BoxDecoration(
                      color: filled ? HomeStyle.peach : HomeStyle.cardMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: active
                              ? _orange
                              : filled
                                  ? _orange.withValues(alpha: .3)
                                  : HomeStyle.divider,
                          width: active ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: filled
                        ? Text(
                            code[index],
                            style: _style(
                                AppFontSize.display, FontWeight.w600, _ink),
                          )
                        : null,
                  );
                }),
              );
            },
          ),
        ],
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
