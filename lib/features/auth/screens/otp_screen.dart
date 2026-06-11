import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> regData;
  const OtpScreen({super.key, required this.regData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();

  bool    _loading       = false;
  String? _error;
  bool    _otpSending    = false;
  int     _resendSeconds = 60;
  Timer?  _resendTimer;

  String get _phone => widget.regData['phone'] as String? ?? '';

  String get _maskedPhone {
    if (_phone.length < 6) return _phone;
    return '${_phone.substring(0, 3)}****${_phone.substring(_phone.length - 3)}';
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
      setState(() { if (_resendSeconds > 0) _resendSeconds--; });
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    setState(() { _otpSending = true; _error = null; _otpCtrl.clear(); });
    final ok = await ref.read(authProvider.notifier).sendOtp(_phone);
    if (!mounted) return;
    setState(() => _otpSending = false);
    if (ok) {
      _startResendTimer();
    } else {
      setState(() => _error = ref.read(authProvider).error ?? 'Gửi lại OTP thất bại');
    }
  }

  Future<void> _submit() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final d = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
      phone:    _phone,
      otp:      otp,
      name:     d['name']     as String? ?? '',
      password: d['password'] as String? ?? '',
      cityId:   d['city_id']  as int?,
    );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() {
        _loading = false;
        _error = ref.read(authProvider).error ?? 'Mã OTP không đúng hoặc đã hết hạn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Xác thực OTP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            // Icon
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _otpSending
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.mark_chat_read_outlined,
                        color: AppColors.primary, size: 34),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                _otpSending ? 'Đang gửi lại mã...' : 'Xác thực OTP',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                  children: [
                    const TextSpan(text: 'Mã 6 chữ số đã gửi qua Zalo tới '),
                    TextSpan(
                      text: _maskedPhone,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            if (!_otpSending) ...[
              _OtpInputRow(
                controller: _otpCtrl,
                onFilled: () {
                  setState(() => _error = null);
                  _submit();
                },
                onChanged: () => setState(() => _error = null),
              ),

              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.divider,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Xác nhận OTP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _resendSeconds > 0
                      ? Container(
                          key: const ValueKey('countdown'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13),
                              children: [
                                TextSpan(
                                  text: 'Gửi lại sau ',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: '${_resendSeconds}s',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('resend'),
                          onTap: _resend,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Text(
                              'Không nhận được mã? Gửi lại',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtpInputRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFilled;
  final VoidCallback onChanged;
  const _OtpInputRow({
    required this.controller,
    required this.onFilled,
    required this.onChanged,
  });

  @override
  State<_OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<_OtpInputRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          SizedBox(
            height: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              decoration: const InputDecoration(border: InputBorder.none),
              onChanged: (v) {
                widget.onChanged();
                setState(() {});
                if (v.length == 6) widget.onFilled();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final code   = widget.controller.text;
              final filled = i < code.length;
              final active = i == code.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: filled
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : filled
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.divider,
                    width: active ? 2 : 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    filled ? code[i] : '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
