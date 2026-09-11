import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
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
    if (_resendSeconds > 0 || _otpSending) return;
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
    if (_loading) return;
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    if (widget.regData['flow'] == 'reset-password') {
      context.push('/reset-password', extra: {
        'phone': _phone,
        'otp': otp,
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
          phone: _phone,
          otp: otp,
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

    return LiquidBackdrop(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _BackButton(onTap: () => context.pop())),
          Expanded(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                                child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                              ),
                              child: _otpSending
                                  ? const Center(
                                      child: SizedBox.square(
                                        dimension: 26,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: _orange,
                                        ),
                                      ),
                                    )
                                  : const GlassIcon(
                                      icon: Icons.mark_email_read_outlined,
                                      size: 64,
                                      iconSize: 30,
                                      color: _orange),
                            )),
                            const SizedBox(height: 20),
                            Text(
                              _otpSending
                                  ? 'Đang gửi lại mã...'
                                  : 'Xác thực OTP',
                              textAlign: TextAlign.center,
                              style: _style(
                                  AppFontSize.xlarge, FontWeight.w800, _ink),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nhập mã 6 số đã gửi đến',
                              textAlign: TextAlign.center,
                              style: _style(AppFontSize.bodyLarge,
                                  FontWeight.w500, _muted, 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formattedPhone,
                              textAlign: TextAlign.center,
                              style: _style(
                                  AppFontSize.bodyLarge, FontWeight.w600, _ink),
                            ),
                            const SizedBox(height: 30),
                            if (!_otpSending) ...[
                              LiquidGlass(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _OtpInputRow(
                                        controller: _otpCtrl,
                                        onChanged: () =>
                                            setState(() => _error = null),
                                        onFilled: _submit,
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        _ErrorMessage(message: _error!),
                                      ],
                                      const SizedBox(height: 22),
                                      Center(
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: _resendSeconds > 0
                                              ? RichText(
                                                  textAlign: TextAlign.center,
                                                  key: const ValueKey(
                                                      'countdown'),
                                                  text: TextSpan(
                                                    style: _style(
                                                        AppFontSize.body,
                                                        FontWeight.w500,
                                                        _muted),
                                                    children: [
                                                      const TextSpan(
                                                          text:
                                                              'Không nhận được mã? '),
                                                      TextSpan(
                                                        text:
                                                            'Gửi lại sau ${_resendSeconds}s',
                                                        style: _style(
                                                          AppFontSize.body,
                                                          FontWeight.w600,
                                                          _softMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : GestureDetector(
                                                  key: const ValueKey('resend'),
                                                  onTap: _resend,
                                                  child: RichText(
                                                    textAlign: TextAlign.center,
                                                    text: TextSpan(
                                                      style: _style(
                                                          AppFontSize.body,
                                                          FontWeight.w500,
                                                          _muted),
                                                      children: [
                                                        const TextSpan(
                                                            text:
                                                                'Không nhận được mã? '),
                                                        TextSpan(
                                                          text: 'Gửi lại',
                                                          style: _style(
                                                            AppFontSize.body,
                                                            FontWeight.w600,
                                                            _orange,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: FilledButton(
                                          onPressed: !codeComplete || _loading
                                              ? null
                                              : _submit,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _orange,
                                            disabledBackgroundColor:
                                                AppColors.surfaceAlt,
                                            disabledForegroundColor: _softMuted,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18)),
                                            elevation: 0,
                                            textStyle: _style(
                                                AppFontSize.bodyLarge,
                                                FontWeight.w600),
                                          ),
                                          child: _loading
                                              ? const SizedBox.square(
                                                  dimension: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text('Xác nhận'),
                                        ),
                                      ),
                                    ]),
                              ),
                            ],
                          ],
                        ),
                      )))),
        ]),
      ),
    ));
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

class _OtpInputRow extends StatefulWidget {
  const _OtpInputRow({
    required this.controller,
    required this.onFilled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onFilled;
  final VoidCallback onChanged;

  @override
  State<_OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<_OtpInputRow> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
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
                    height: 58,
                    decoration: BoxDecoration(
                      color: filled
                          ? _orange.withValues(alpha: .1)
                          : Colors.white.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: active
                              ? _orange
                              : Colors.white.withValues(alpha: .8),
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
