import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../features/order/providers/order_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';

const _quickAmounts = [200000, 500000, 1000000, 2000000, 5000000];

class TopupBookingScreen extends ConsumerStatefulWidget {
  const TopupBookingScreen({super.key});

  @override
  ConsumerState<TopupBookingScreen> createState() => _State();
}

class _State extends ConsumerState<TopupBookingScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _amountCtrl   = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _noteCtrl     = TextEditingController();

  bool _loadingGps = false;
  double? _lat, _lng;
  int?  _fee;
  int   _nightSurcharge = 0;
  bool _loadingFee = false;
  bool _submitting  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) _phoneCtrl.text = user.phone;
    _loadGps();
  }

  Future<void> _loadGps() async {
    setState(() => _loadingGps = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos == null || !mounted) {
      if (mounted) setState(() => _loadingGps = false);
      return;
    }
    final addr = await LocationService.addressFromCoords(
        pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      _loadingGps = false;
      _lat = pos.latitude;
      _lng = pos.longitude;
      if (addr != null) _locationCtrl.text = addr;
    });
  }

  @override
  void dispose() {
    for (final c in [_amountCtrl, _locationCtrl, _phoneCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickAmount(int amount) {
    _amountCtrl.text = amount.toString();
    setState(() {});
    _estimate(amount);
  }

  Future<void> _estimate(int amount) async {
    if (amount <= 0) return;
    setState(() { _loadingFee = true; _fee = null; });
    try {
      final res = await ref.read(apiClientProvider).get(
        '/customer/pricing/estimate',
        params: {'service_type': 'topup', 'topup_amount': amount},
      );
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      setState(() {
        _fee            = (data['fee'] as num).toInt();
        _nightSurcharge = (data['night_surcharge'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final amount = int.tryParse(
          _amountCtrl.text.replaceAll(',', '')) ?? 0;
      final res = await ref.read(apiClientProvider).post(
          '/customer/orders', data: {
        'service_type':     'topup',
        'topup_amount':     amount,
        'pickup_address':   _locationCtrl.text.trim(),
        'delivery_address': _locationCtrl.text.trim(),
        'delivery_phone':   _phoneCtrl.text.trim(),
        'order_note':       _noteCtrl.text.trim(),
        if (_lat != null) 'pickup_lat':   _lat,
        if (_lng != null) 'pickup_lng':   _lng,
        if (_lat != null) 'delivery_lat': _lat,
        if (_lng != null) 'delivery_lng': _lng,
      });
      final code = (res.data['data'] ?? res.data)['code'] as String;
      ref.read(orderListProvider.notifier).fetch();
      if (mounted) context.pushReplacement('/order/$code', extra: 'fromBooking');
    } catch (e) {
      String msg = 'Không thể đặt đơn.';
      try { msg = (e as dynamic).response?.data['message'] ?? msg; } catch (_) {}
      setState(() { _error = msg; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = int.tryParse(
        _amountCtrl.text.replaceAll(',', ''));
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(Fmt.serviceLabel('topup'),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),

                  // ── Số tiền ─────────────────────────────────────────────
                  _SectionHeader(title: 'Số tiền cần nạp'),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount input
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                          textAlign: TextAlign.center,
                          onChanged: (v) {
                            setState(() {});
                            final n = int.tryParse(v.replaceAll(',', ''));
                            if (n != null && n > 0) _estimate(n);
                          },
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary),
                            suffixText: 'đ',
                            suffixStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.primary.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5)),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.danger)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.danger, width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nhập số tiền';
                            final n = int.tryParse(v.replaceAll(',', ''));
                            if (n == null || n <= 0) return 'Số tiền không hợp lệ';
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // Quick chips
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _quickAmounts.map((a) {
                            final selected = parsedAmount == a;
                            return GestureDetector(
                              onTap: () => _pickAmount(a),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Text(Fmt.shortAmount(a),
                                    style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textSecondary)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Thông tin nạp ───────────────────────────────────────
                  _SectionHeader(title: 'Thông tin nạp'),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(children: [
                      _FlatField(
                        controller: _locationCtrl,
                        hint: _loadingGps
                            ? 'Đang lấy vị trí...'
                            : 'Địa điểm nạp tiền *',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập địa điểm nạp tiền' : null,
                      ),
                      const SizedBox(height: 10),
                      _FlatField(
                        controller: _phoneCtrl,
                        hint: 'SĐT liên hệ *',
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập SĐT liên hệ' : null,
                      ),
                    ]),
                  ),

                  // ── Summary ─────────────────────────────────────────────
                  if (parsedAmount != null && parsedAmount > 0 &&
                      _locationCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(children: [
                        Container(
                          width: 4, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Fmt.currency(parsedAmount),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                              const Text('Số tiền cần nạp',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          if (_loadingFee)
                            const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary))
                          else
                            Text(_fee != null ? Fmt.currency(_fee!) : '—',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          const Text('Phí dịch vụ',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                          if (!_loadingFee && _nightSurcharge > 0)
                            Text('+${Fmt.currency(_nightSurcharge)} đêm',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.warning)),
                        ]),
                      ]),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom bar ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad + 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Đặt ${Fmt.serviceLabel('topup').toLowerCase()} ngay',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
    ]),
  );
}

// ── Flat Field ────────────────────────────────────────────────────────────────

class _FlatField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  final FormFieldValidator<String>? validator;

  const _FlatField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: 1,
    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
    decoration: InputDecoration(
      labelText: hint,
      labelStyle: const TextStyle(
          fontSize: 14, color: AppColors.textSecondary),
      floatingLabelStyle: const TextStyle(
          fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.danger, width: 1.5)),
    ),
    validator: validator,
  );
}
