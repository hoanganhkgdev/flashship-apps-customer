import 'package:flutter/gestures.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class _City {
  const _City({required this.id, required this.name});

  final int id;
  final String name;
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _agreed = true;
  bool _agreementError = false;
  List<_City> _cities = [];
  _City? _selectedCity;
  bool _loadingCities = false;
  bool _citiesLoadFailed = false;
  bool _cityError = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    if (_selectedCity == null) {
      setState(() => _cityError = true);
    }
    if (!_agreed) {
      setState(() => _agreementError = true);
    }
    if (!valid || !_agreed || _selectedCity == null) return;

    final phone = _phoneCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: {
        'phone': phone,
        'name': _nameCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'city_id': _selectedCity!.id,
      });
    }
  }

  Future<void> _loadCities() async {
    setState(() {
      _loadingCities = true;
      _citiesLoadFailed = false;
    });
    try {
      final response = await Dio().get('${AppConstants.baseUrl}/cities');
      final data = response.data['data'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _cities = data
            .map((item) => _City(
                  id: item['id'] as int,
                  name: item['name'] as String,
                ))
            .toList();
        _citiesLoadFailed = _cities.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _citiesLoadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _openCityPicker() async {
    if (_loadingCities) return;
    if (_cities.isEmpty) {
      await _loadCities();
      if (!mounted || _cities.isEmpty) return;
    }
    final city = await showModalBottomSheet<_City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySheet(
        cities: _cities,
        selected: _selectedCity,
      ),
    );
    if (city != null && mounted) {
      setState(() {
        _selectedCity = city;
        _cityError = false;
      });
    }
  }

  void _toggleAgreement() {
    setState(() {
      _agreed = !_agreed;
      if (_agreed) _agreementError = false;
    });
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
                _BackButton(onTap: () => context.go('/login')),
                const SizedBox(height: 26),
                Text(
                  'Tạo tài khoản mới',
                  style: _style(AppFontSize.xlarge, FontWeight.w600, _ink),
                ),
                const SizedBox(height: 7),
                Text(
                  'Đăng ký để bắt đầu đặt dịch vụ Flash Ship',
                  style: _style(
                      AppFontSize.bodyLarge, FontWeight.w500, _muted, 1.35),
                ),
                const SizedBox(height: 24),
                _RegisterField(
                  label: 'Họ và tên',
                  controller: _nameCtrl,
                  hint: 'Nguyễn Văn A',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập họ và tên'
                      : null,
                ),
                const SizedBox(height: 14),
                _RegisterField(
                  label: 'Số điện thoại',
                  controller: _phoneCtrl,
                  hint: '0912 345 678',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 14),
                _CityField(
                  selected: _selectedCity,
                  loading: _loadingCities,
                  loadFailed: _citiesLoadFailed,
                  hasError: _cityError,
                  onTap: _openCityPicker,
                ),
                const SizedBox(height: 14),
                _RegisterField(
                  label: 'Mật khẩu',
                  controller: _passwordCtrl,
                  hint: 'Tối thiểu 6 ký tự',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffixIcon: _VisibilityButton(
                    obscure: _obscurePassword,
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu phải tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _RegisterField(
                  label: 'Xác nhận mật khẩu',
                  controller: _confirmPasswordCtrl,
                  hint: 'Nhập lại mật khẩu',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: _VisibilityButton(
                    obscure: _obscureConfirmation,
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    if (value != _passwordCtrl.text) {
                      return 'Mật khẩu xác nhận không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _AgreementRow(
                  checked: _agreed,
                  hasError: _agreementError,
                  onToggle: _toggleAgreement,
                  onTerms: () => context.push(
                    '/legal/terms?title=Điều%20khoản%20dịch%20vụ',
                  ),
                  onPrivacy: () => context.push(
                    '/legal/privacy-policy?title=Chính%20sách%20bảo%20mật',
                  ),
                ),
                if (_agreementError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      'Vui lòng đồng ý với điều khoản để tiếp tục',
                      style: _style(AppFontSize.caption, FontWeight.w500,
                          AppColors.danger),
                    ),
                  ),
                ],
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
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
                        : const Text('Đăng ký'),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Đã có tài khoản? ',
                        style:
                            _style(AppFontSize.body, FontWeight.w500, _muted),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Đăng nhập',
                          style: _style(
                              AppFontSize.body, FontWeight.w600, _orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        child:
            const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _ink),
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.suffixIcon,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _style(AppFontSize.body, FontWeight.w600, _ink)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: inputFormatters,
          style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                _style(AppFontSize.bodyLarge, FontWeight.w600, _softMuted),
            prefixIcon: Icon(prefixIcon, size: 22, color: _muted),
            suffixIcon: suffixIcon,
            suffixIconColor: _muted,
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
          validator: validator,
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _CityField extends StatelessWidget {
  const _CityField({
    required this.selected,
    required this.loading,
    required this.loadFailed,
    required this.hasError,
    required this.onTap,
  });

  final _City? selected;
  final bool loading;
  final bool loadFailed;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final error = hasError || loadFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thành phố',
            style: _style(AppFontSize.body, FontWeight.w600, _ink)),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: error ? Border.all(color: AppColors.danger) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    size: 22,
                    color: error ? AppColors.danger : _muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: loading
                        ? Text(
                            'Đang tải danh sách...',
                            style: _style(AppFontSize.bodyLarge,
                                FontWeight.w600, _softMuted),
                          )
                        : Text(
                            loadFailed
                                ? 'Chạm để tải lại'
                                : selected?.name ?? 'Chọn thành phố',
                            style: _style(
                              AppFontSize.bodyLarge,
                              selected == null
                                  ? FontWeight.w600
                                  : FontWeight.w600,
                              loadFailed
                                  ? AppColors.danger
                                  : selected == null
                                      ? _softMuted
                                      : _ink,
                            ),
                          ),
                  ),
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _orange,
                      ),
                    )
                  else
                    Icon(
                      loadFailed
                          ? Icons.refresh_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: error ? AppColors.danger : _muted,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Vui lòng chọn thành phố',
              style: _style(AppFontSize.caption, null, AppColors.danger),
            ),
          ),
        ],
      ],
    );
  }
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.cities, required this.selected});

  final List<_City> cities;
  final _City? selected;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final _searchCtrl = TextEditingController();
  late List<_City> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.cities;
    _searchCtrl.addListener(_filterCities);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterCities() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.cities
          : widget.cities
              .where((city) => city.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.location_city_outlined,
                        color: _orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn thành phố',
                            style: _style(
                                AppFontSize.display, FontWeight.w600, _ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.cities.length} khu vực đang hoạt động',
                            style: _style(
                                AppFontSize.body, FontWeight.w500, _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        minimumSize: const Size(40, 40),
                      ),
                      tooltip: 'Đóng',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _muted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  style: _style(AppFontSize.bodyLarge, FontWeight.w600, _ink),
                  decoration: InputDecoration(
                    hintText: 'Tìm thành phố...',
                    hintStyle: _style(
                        AppFontSize.bodyLarge, FontWeight.w500, _softMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: _searchCtrl.clear,
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 19,
                              color: _softMuted,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: _orange, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _searchCtrl.text.isEmpty
                          ? 'Tất cả thành phố'
                          : '${_filtered.length} kết quả',
                      style: _style(AppFontSize.body, FontWeight.w600, _ink),
                    ),
                    if (widget.selected != null) ...[
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'Đã chọn: ${widget.selected!.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(
                              AppFontSize.body, FontWeight.w600, _orange),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_off_outlined,
                                  color: _softMuted,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Không tìm thấy thành phố',
                                style: _style(AppFontSize.bodyLarge,
                                    FontWeight.w600, _ink),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Thử tìm kiếm bằng tên khác',
                                style: _style(
                                    AppFontSize.body, FontWeight.w500, _muted),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _searchCtrl.clear,
                                child: const Text('Xóa tìm kiếm'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16 + bottomInset,
                        ),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final city = _filtered[index];
                          final selected = city.id == widget.selected?.id;
                          return Material(
                            color: selected
                                ? const Color(0xFFFFE9E0)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, city),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _orange
                                            : AppColors.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: selected ? Colors.white : _muted,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        city.name,
                                        style: _style(
                                          AppFontSize.bodyLarge,
                                          selected
                                              ? FontWeight.w600
                                              : FontWeight.w600,
                                          selected ? _orange : _ink,
                                        ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _orange
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected
                                              ? _orange
                                              : const Color(0xFFD8CEC8),
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.obscure, required this.onPressed});

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: onPressed,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

class _AgreementRow extends StatefulWidget {
  const _AgreementRow({
    required this.checked,
    required this.hasError,
    required this.onToggle,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool checked;
  final bool hasError;
  final VoidCallback onToggle;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<_AgreementRow> createState() => _AgreementRowState();
}

class _AgreementRowState extends State<_AgreementRow> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = widget.onPrivacy;
  }

  @override
  void didUpdateWidget(covariant _AgreementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _termsRecognizer.onTap = widget.onTerms;
    _privacyRecognizer.onTap = widget.onPrivacy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: widget.checked,
          button: true,
          label: 'Đồng ý với điều khoản dịch vụ và chính sách bảo mật',
          child: GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: widget.checked ? _orange : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.hasError ? AppColors.danger : _orange,
                  width: 1.5,
                ),
              ),
              child: widget.checked
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _style(AppFontSize.body, FontWeight.w500, _muted, 1.4),
              children: [
                const TextSpan(text: 'Tôi đồng ý với '),
                TextSpan(
                  text: 'Điều khoản dịch vụ',
                  recognizer: _termsRecognizer,
                  style: _style(AppFontSize.body, FontWeight.w600, _orange),
                ),
                const TextSpan(text: ' và '),
                TextSpan(
                  text: 'Chính sách bảo mật',
                  recognizer: _privacyRecognizer,
                  style: _style(AppFontSize.body, FontWeight.w600, _orange),
                ),
                const TextSpan(text: ' của Flash Ship'),
              ],
            ),
          ),
        ),
      ],
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 17),
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
