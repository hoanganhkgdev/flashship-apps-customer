import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/booking_summary_bar.dart';
import '../../home/providers/service_type_provider.dart';
import '../../../core/constants/app_constants.dart';

const _quickAmounts = [500000, 1000000, 2000000, 5000000];

class TopupBookingScreen extends ConsumerStatefulWidget {
  const TopupBookingScreen({super.key});

  @override
  ConsumerState<TopupBookingScreen> createState() => _State();
}

class _State extends ConsumerState<TopupBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loadingGps = false;
  double? _lat, _lng;
  String? _placeName;
  int? _fee;
  int _nightSurcharge = 0;
  bool _loadingFee = false;
  bool _submitting = false;
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
    final result = await LocationService.resolveCurrentLocation(context);
    if (!mounted) return;
    if (result == null) {
      setState(() => _loadingGps = false);
      return;
    }
    final (pos, addr) = result;
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
    _amountCtrl.selection =
        TextSelection.collapsed(offset: _amountCtrl.text.length);
    setState(() {});
    _estimate(amount);
  }

  Future<void> _estimate(int amount) async {
    if (amount <= 0) return;
    setState(() {
      _loadingFee = true;
      _fee = null;
    });
    final estimate = await fetchPricingEstimate(
      ref,
      {'service_type': 'topup', 'topup_amount': amount},
    );
    if (!mounted) return;
    if (estimate != null) {
      setState(() {
        _fee = estimate.fee;
        _nightSurcharge = estimate.nightSurcharge;
      });
    }
    setState(() => _loadingFee = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      setState(() => _error =
          'Vui lòng chọn địa chỉ từ gợi ý hoặc bản đồ để xác định vị trí chính xác.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    await submitBookingOrder(
      ref: ref,
      context: context,
      data: {
        'service_type': 'topup',
        'topup_amount': amount,
        'pickup_address': _locationCtrl.text.trim(),
        'delivery_address': _locationCtrl.text.trim(),
        'delivery_phone': _phoneCtrl.text.trim(),
        'receiver_name': ref.read(authProvider).user?.name ?? '',
        if (_placeName?.isNotEmpty == true) 'pickup_place_name': _placeName,
        'order_note': _noteCtrl.text.trim(),
        if (_lat != null) 'pickup_lat': _lat,
        if (_lng != null) 'pickup_lng': _lng,
        if (_lat != null) 'delivery_lat': _lat,
        if (_lng != null) 'delivery_lng': _lng,
      },
      onError: (message) {
        if (mounted) {
          setState(() {
            _error = message;
            _submitting = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = int.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final serviceName = ref
            .watch(serviceTypeProvider)
            .valueOrNull
            ?.where((service) => service.key == 'topup')
            .map((service) => service.label.trim())
            .where((label) => label.isNotEmpty)
            .firstOrNull ??
        serviceDefOf('topup').label;

    return LiquidBackdrop(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 72,
        centerTitle: false,
        titleSpacing: 0,
        flexibleSpace: const LiquidGlass(
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(AppRadius.glass)),
          child: SizedBox.expand(),
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .35),
              side: BorderSide(color: Colors.white.withValues(alpha: .7)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.glass)),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textPrimary),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(serviceName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFontSize.titleLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ),
      body: Builder(
        builder: (bodyContext) => Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.paddingOf(bodyContext).bottom + 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // ── Số tiền ─────────────────────────────────────────────
              Row(children: [
                const GlassIcon(
                  icon: Icons.credit_card_rounded,
                  color: AppColors.primary,
                  size: 32,
                  iconSize: 17,
                ),
                const SizedBox(width: 8),
                Text('Số tiền cần nạp',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 10),

              LiquidGlass(
                borderRadius: BorderRadius.circular(AppRadius.card),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: AppFontSize.xlarge,
                          fontWeight: FontWeight.w600,
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
                            fontSize: AppFontSize.display,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                        suffixText: 'đ',
                        suffixStyle: const TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                                right:
                                    e.key == _quickAmounts.length - 1 ? 0 : 4),
                            child: GestureDetector(
                              onTap: () => _pickAmount(e.value),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: .14)
                                      : Colors.white.withValues(alpha: .28),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.glass),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: .7),
                                  ),
                                ),
                                child: Center(
                                  child: Text(Fmt.shortAmount(e.value),
                                      style: TextStyle(
                                          fontSize: AppFontSize.body,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.textSecondary)),
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
                const GlassIcon(
                  icon: Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 32,
                  iconSize: 17,
                ),
                const SizedBox(width: 8),
                Text('Thông tin nạp',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 10),

              LiquidGlass(
                borderRadius: BorderRadius.circular(AppRadius.card),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(AppRadius.glass),
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
                                      fontSize: AppFontSize.bodyLarge,
                                      color: AppColors.textSecondary))
                              : _locationCtrl.text.isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _placeName ??
                                              ref
                                                  .read(authProvider)
                                                  .user
                                                  ?.name ??
                                              'Vị trí của bạn',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: AppFontSize.bodyLarge,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _locationCtrl.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: AppFontSize.body,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    )
                                  : const Text('Chọn địa điểm nạp tiền *',
                                      style: TextStyle(
                                          fontSize: AppFontSize.bodyLarge,
                                          color: AppColors.textSecondary)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textSecondary),
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
                        ? 'Nhập SĐT liên hệ'
                        : null,
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
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: AppFontSize.caption))),
                ]),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BookingSummaryBar(
        serviceName: parsedAmount != null && parsedAmount > 0
            ? 'Nạp ${Fmt.currency(parsedAmount)}'
            : serviceName,
        buttonLabel: 'Đặt nạp tiền hộ',
        feeLabel: 'Phí dịch vụ',
        emptyPriceHint: 'Nhập số tiền cần nạp để xem phí dịch vụ',
        canEstimate: (parsedAmount ?? 0) > 0,
        onRetry: () => _estimate(parsedAmount ?? 0),
        distanceKm: null,
        fee: (parsedAmount ?? 0) > 0 ? _fee : null,
        netFee: _fee ?? 0,
        nightSurcharge: _nightSurcharge,
        loadingFee: _loadingFee,
        error: null,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    ));
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
        style: const TextStyle(
            fontSize: AppFontSize.bodyLarge, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: const TextStyle(
              fontSize: AppFontSize.bodyLarge, color: AppColors.textSecondary),
          floatingLabelStyle: const TextStyle(
              fontSize: AppFontSize.body,
              color: AppColors.primary,
              fontWeight: FontWeight.w500),
          prefixIcon: icon != null
              ? Icon(icon, size: 16, color: AppColors.textSecondary)
              : null,
          prefixIconConstraints: icon != null
              ? const BoxConstraints(minWidth: 40, minHeight: 40)
              : null,
          alignLabelWithHint: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      );
}
