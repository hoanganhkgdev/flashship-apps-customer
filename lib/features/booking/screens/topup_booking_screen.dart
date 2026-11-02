import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../home/widgets/home_style.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../utils/booking_submit.dart';
import '../utils/pricing_estimate.dart';
import 'address_picker_screen.dart';
import 'map_picker_screen.dart';
import 'widgets/booking_field_decoration.dart';
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

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFFFE9DE),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        leadingWidth: 72,
        centerTitle: false,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: HomeStyle.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: HomeStyle.ink),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w800,
                      color: HomeStyle.ink)),
              const SizedBox(height: 3),
              const Text('Giao dịch thuận tiện, hỗ trợ tận nơi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.caption, color: HomeStyle.muted)),
            ],
          ),
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
              _SectionCard(
                icon: Icons.credit_card_rounded,
                title: 'Số tiền cần nạp',
                warm: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: AppFontSize.xlarge,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.orange),
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
                      decoration: bookingFieldDecoration(hint: '0').copyWith(
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        hintStyle: const TextStyle(
                            fontSize: AppFontSize.display,
                            fontWeight: FontWeight.w600,
                            color: HomeStyle.muted),
                        suffixText: 'đ',
                        suffixStyle: const TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w600,
                            color: HomeStyle.muted),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
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
                    const Text('Chọn nhanh số tiền',
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: HomeStyle.muted)),
                    const SizedBox(height: 8),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth < 300 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? 2
                          : 4;
                      final width =
                          (constraints.maxWidth - 8 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts.map((amount) {
                          final selected = parsedAmount == amount;
                          return SizedBox(
                            width: width,
                            child: Semantics(
                              label: 'Chọn ${Fmt.currency(amount)}',
                              selected: selected,
                              button: true,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickAmount(amount),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? HomeStyle.orange
                                          : HomeStyle.card,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: selected
                                            ? HomeStyle.orange
                                            : HomeStyle.divider,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(Fmt.shortAmount(amount),
                                          style: TextStyle(
                                              fontSize: AppFontSize.body,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? Colors.white
                                                  : HomeStyle.muted)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Thông tin nạp ───────────────────────────────────────
              _SectionCard(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.info,
                title: 'Địa điểm và liên hệ',
                child: Column(children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickLocation,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: HomeStyle.cardMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: HomeStyle.divider,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 20, color: AppColors.info),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _loadingGps
                                ? const Text('Đang lấy vị trí...',
                                    style: TextStyle(
                                        fontSize: AppFontSize.body,
                                        color: HomeStyle.muted))
                                : _locationCtrl.text.isNotEmpty
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _placeName ?? 'Địa điểm giao dịch',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: AppFontSize.bodyLarge,
                                                fontWeight: FontWeight.w600,
                                                color: HomeStyle.ink),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _locationCtrl.text,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: AppFontSize.body,
                                                color: HomeStyle.muted),
                                          ),
                                        ],
                                      )
                                    : const Text('Chọn địa điểm giao dịch *',
                                        style: TextStyle(
                                            fontSize: AppFontSize.body,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.info)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 22, color: HomeStyle.muted),
                        ]),
                      ),
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

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: .16)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 20, color: AppColors.info),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Số tiền cần nạp chưa bao gồm phí dịch vụ hiển thị bên dưới. Bạn có thể ghi thêm yêu cầu trong phần ghi chú.',
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            height: 1.4,
                            color: HomeStyle.ink),
                      ),
                    ),
                  ],
                ),
              ),
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
        error: _error,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor = HomeStyle.orange,
    this.warm = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color iconColor;
  final bool warm;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: warm ? HomeStyle.peach : HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: warm ? const Color(0xFFFFD1BF) : HomeStyle.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w800,
                          color: HomeStyle.ink)),
                ),
              ]),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

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
            fontSize: AppFontSize.bodyLarge, color: HomeStyle.ink),
        decoration: bookingFieldDecoration(label: hint, prefixIcon: icon),
        validator: validator,
      );
}
