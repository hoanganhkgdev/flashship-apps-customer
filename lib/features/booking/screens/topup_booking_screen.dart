import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../features/order/providers/order_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';

const _quickAmounts = [500000, 1000000, 2000000, 5000000];

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
  String? _placeName;
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

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _locationCtrl.text = result.address;
      _placeName = result.placeName;
      _lat = result.lat;
      _lng = result.lng;
    });
  }

  static String _formatNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  void _pickAmount(int amount) {
    _amountCtrl.text = _formatNumber(amount.toString());
    _amountCtrl.selection = TextSelection.collapsed(
        offset: _amountCtrl.text.length);
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
        'receiver_name':    ref.read(authProvider).user?.name ?? '',
        if (_placeName?.isNotEmpty == true)
          'pickup_place_name': _placeName,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [

                  // ── Số tiền ─────────────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 15, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text('Số tiền cần nạp',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            TextInputFormatter.withFunction((old, newVal) {
                              final formatted = _formatNumber(newVal.text);
                              return TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                    offset: formatted.length),
                              );
                            }),
                          ],
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
                            fillColor: AppColors.primary
                                .withValues(alpha: 0.05),
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
                            if (v == null || v.trim().isEmpty) {
                              return 'Nhập số tiền';
                            }
                            final n = int.tryParse(v.replaceAll(',', ''));
                            if (n == null || n <= 0) {
                              return 'Số tiền không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: _quickAmounts.asMap().entries.map((e) {
                            final selected = parsedAmount == e.value;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    left: e.key == 0 ? 0 : 4,
                                    right: e.key == _quickAmounts.length - 1
                                        ? 0 : 4),
                                child: GestureDetector(
                                  onTap: () => _pickAmount(e.value),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.1)
                                          : const Color(0xFFF5F5F5),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(Fmt.shortAmount(e.value),
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors
                                                      .textSecondary)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Thông tin nạp ───────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text('Thông tin nạp',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )],
                    ),
                    child: Column(children: [
                      GestureDetector(
                        onTap: _pickLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Icon(Icons.location_on_outlined,
                                size: 16,
                                color: _locationCtrl.text.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _loadingGps
                                  ? const Text('Đang lấy vị trí...',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary))
                                  : _locationCtrl.text.isNotEmpty
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _placeName ??
                                                  ref.read(authProvider)
                                                      .user?.name ??
                                                  'Vị trí của bạn',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: AppColors
                                                      .textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _locationCtrl.text,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textSecondary),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Chọn địa điểm nạp tiền *',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors
                                                  .textSecondary)),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.textSecondary),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FlatField(
                        controller: _phoneCtrl,
                        hint: 'SĐT liên hệ *',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập SĐT liên hệ' : null,
                      ),
                      const SizedBox(height: 12),
                      _FlatField(
                        controller: _noteCtrl,
                        hint: 'Ghi chú (tuỳ chọn)',
                        icon: Icons.note_alt_outlined,
                      ),
                    ]),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12))),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom bar ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary row
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.serviceLabel('topup'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (parsedAmount != null && parsedAmount > 0)
                          Text('Nạp ${Fmt.currency(parsedAmount)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_loadingFee)
                    const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                  else
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text(
                        _fee != null ? Fmt.currency(_fee!) : '—',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: _fee != null
                                ? AppColors.primary
                                : AppColors.textSecondary),
                      ),
                      if (_fee != null)
                        const Text('Phí dịch vụ',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      if (!_loadingFee && _nightSurcharge > 0)
                        Text('+${Fmt.currency(_nightSurcharge)} đêm',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.warning)),
                    ]),
                ]),

                const SizedBox(height: 14),

                SizedBox(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flat Field ────────────────────────────────────────────────────────────────

class _FlatField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const _FlatField({
    required this.controller,
    required this.hint,
    this.icon,
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
      prefixIcon: icon != null
          ? Icon(icon, size: 16, color: AppColors.textSecondary)
          : null,
      prefixIconConstraints: icon != null
          ? const BoxConstraints(minWidth: 40, minHeight: 40)
          : null,
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
