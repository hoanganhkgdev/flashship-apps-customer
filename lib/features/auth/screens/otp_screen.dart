import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const SizedBox(height: 16),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: _otpSending
                    ? const Center(
                        child: SizedBox(
                          width: 26, height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.mark_chat_read_outlined,
                        color: AppColors.primary, size: 32),
              ),

              const SizedBox(height: 20),

              Text(
                _otpSending ? 'Đang gửi lại mã...' : 'Xác thực OTP',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
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
                      height: 1.5),
                  children: [
                    const TextSpan(text: 'Mã 6 chữ số đã gửi qua Zalo tới\n'),
                    TextSpan(
                      text: _maskedPhone,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              if (!_otpSending) ...[

                // OTP boxes
                _OtpInputRow(
                  controller: _otpCtrl,
                  onFilled: () {
                    setState(() => _error = null);
                    _submit();
                  },
                  onChanged: () => setState(() => _error = null),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                        child: Text(_error!,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      textStyle: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Xác nhận'),
                  ),
                ),

                const SizedBox(height: 24),

                // Resend
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _resendSeconds > 0
                      ? RichText(
                          key: const ValueKey('countdown'),
                          text: TextSpan(
                            style: GoogleFonts.beVietnamPro(fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Gửi lại sau ',
                                style: GoogleFonts.beVietnamPro(
                                    color: AppColors.textSecondary),
                              ),
                              TextSpan(
                                text: '${_resendSeconds}s',
                                style: GoogleFonts.beVietnamPro(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('resend'),
                          onTap: _resend,
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.beVietnamPro(fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Không nhận được mã? ',
                                  style: GoogleFonts.beVietnamPro(
                                      color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: 'Gửi lại',
                                  style: GoogleFonts.beVietnamPro(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── OTP input boxes ────────────────────────────────────────────────────────────

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
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              enableSuggestions: false,
              autofillHints: const [],
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
              ),
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
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : filled
                          ? const Color(0xFFF5F5F5)
                          : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // cursor blink khi active và chưa nhập
                    if (active && !filled)
                      AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                          width: 2,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    if (filled)
                      Text(
                        code[i],
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
