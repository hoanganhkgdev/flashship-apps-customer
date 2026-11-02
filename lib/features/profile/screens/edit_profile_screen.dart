import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../home/widgets/home_style.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cities_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  int? _cityId;
  String _cityName = '';
  DateTime? _birthDate;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _cityId = user.cityId;
      _cityName = user.cityName ?? '';
      _birthDate = user.birthDate;
      _birthDateCtrl.text = _birthDateLabel;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_saving || _uploadingAvatar) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _profileError = null;
    });

    final err = await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          birthDate: _birthDate,
          cityId: _cityId,
          cityName: _cityName,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      setState(() => _profileError = err);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thành công'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      if (mounted) context.pop();
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      showDragHandle: false,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GlassBottomSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Text('Ảnh đại diện',
                      style: TextStyle(
                          fontSize: AppFontSize.display,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: HomeStyle.cardMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 24, color: AppColors.textSecondary),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(children: [
                  Expanded(
                    child: _AvatarSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Thư viện',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AvatarSourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Máy ảnh',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        requestFullMetadata: false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Không thể mở ảnh: $e'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    final err = await ref.read(authProvider.notifier).uploadAvatar(picked.path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _pickCity(List<CityItem> cities) async {
    final picked = await showModalBottomSheet<CityItem>(
      showDragHandle: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _CityPicker(cities: cities, selectedId: _cityId),
    );
    if (picked != null && mounted) {
      setState(() {
        _cityId = picked.id;
        _cityName = picked.name;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(1900);
    final savedDate = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final initialDate = savedDate.isBefore(firstDate)
        ? firstDate
        : savedDate.isAfter(now)
            ? now
            : savedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: HomeStyle.orange,
                surface: AppColors.surface,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _birthDateCtrl.text = _birthDateLabel;
      });
    }
  }

  String get _birthDateLabel {
    final value = _birthDate;
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final citiesAsync = ref.watch(citiesProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: HomeStyle.card,
          border: Border(top: BorderSide(color: HomeStyle.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving || _uploadingAvatar ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      HomeStyle.orange.withValues(alpha: .5),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w700),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Lưu thay đổi'),
                      ]),
              ),
            ),
          ),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9DE),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => context.pop(),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: HomeStyle.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chỉnh sửa hồ sơ',
                          style: TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      SizedBox(height: 3),
                      Text('Thông tin để liên hệ thuận tiện hơn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
            child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              _FlatCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: HomeStyle.peach,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: user?.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _AvatarInitials(initials: user.initials),
                                errorWidget: (_, __, ___) =>
                                    _AvatarInitials(initials: user.initials),
                              )
                            : _AvatarInitials(initials: user?.initials ?? 'U'),
                      ),
                      if (_uploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.black.withValues(alpha: .4),
                            ),
                            child: const Center(
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: HomeStyle.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera_outlined,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ảnh hồ sơ',
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink)),
                        const SizedBox(height: 4),
                        const Text('Ảnh được cập nhật ngay sau khi chọn',
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                height: 1.35,
                                color: HomeStyle.muted)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                          style: TextButton.styleFrom(
                            foregroundColor: HomeStyle.orange,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(_uploadingAvatar
                              ? 'Đang tải ảnh...'
                              : 'Thay đổi ảnh'),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Fields card ───────────────────────────────────────────────
              _FlatCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(children: [
                      _FlatIcon(
                          icon: Icons.person_outline_rounded,
                          color: HomeStyle.orange),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('Thông tin cá nhân',
                              style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w700,
                                  color: HomeStyle.ink))),
                    ]),
                  ),
                  _FormRow(
                    label: 'Họ và tên *',
                    child: _FilledField(
                      controller: _nameCtrl,
                      hint: 'Nhập họ và tên',
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nhập họ tên'
                          : null,
                    ),
                  ),
                  _FormRow(
                    label: 'Ngày sinh',
                    trailing: const Icon(Icons.calendar_month_outlined,
                        size: 20, color: AppColors.textSecondary),
                    child: _FilledField(
                      controller: _birthDateCtrl,
                      onTap: _pickBirthDate,
                      hint: 'Chọn ngày sinh',
                      prefixIcon: Icons.cake_outlined,
                      readOnly: true,
                    ),
                  ),
                  citiesAsync.when(
                    loading: () => _FormRow(
                      label: 'Thành phố',
                      child: _FilledField(
                          hint: 'Đang tải...',
                          prefixIcon: Icons.location_city_outlined,
                          readOnly: true),
                    ),
                    error: (_, __) => _FormRow(
                      label: 'Thành phố',
                      trailing: TextButton.icon(
                        onPressed: () => ref.invalidate(citiesProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Thử lại'),
                      ),
                      child: _FilledField(
                          hint: 'Không tải được',
                          prefixIcon: Icons.location_city_outlined,
                          readOnly: true),
                    ),
                    data: (cities) => _FormRow(
                      label: 'Thành phố',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: HomeStyle.orange, size: 20),
                      child: _FilledField(
                        key: ValueKey('city-$_cityId'),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _pickCity(cities);
                        },
                        initialValue: _cityName,
                        hint: 'Chọn thành phố',
                        prefixIcon: Icons.location_city_outlined,
                        readOnly: true,
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),
              _FlatCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(children: [
                        _FlatIcon(
                            icon: Icons.lock_outline_rounded,
                            color: AppColors.info),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Thông tin đăng nhập',
                                style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w700,
                                  color: HomeStyle.ink,
                                ))),
                      ]),
                    ),
                    _FormRow(
                      label: 'Số điện thoại',
                      trailing: const Icon(Icons.lock_outline_rounded,
                          size: 17, color: HomeStyle.muted),
                      child: _FilledField(
                        initialValue: user?.phone ?? '',
                        prefixIcon: Icons.phone_outlined,
                        readOnly: true,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                          'Số điện thoại dùng để đăng nhập, không chỉnh sửa tại đây.',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            height: 1.4,
                            color: HomeStyle.muted,
                          )),
                    ),
                  ],
                ),
              ),

              if (_profileError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_profileError!,
                          style: TextStyle(
                              fontSize: AppFontSize.body,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        )),
      ]),
    );
  }
}

// ── Form row (label + field inside card) ─────────────────────────────────────

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const _FormRow({
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: HomeStyle.ink))),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ── Filled borderless input ───────────────────────────────────────────────────

class _FilledField extends StatelessWidget {
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final bool readOnly;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _FilledField({
    super.key,
    this.onTap,
    this.controller,
    this.initialValue,
    this.hint,
    this.readOnly = false,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        onTap: onTap,
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: readOnly,
        textCapitalization: textCapitalization,
        style: TextStyle(
          fontSize: AppFontSize.bodyLarge,
          fontWeight: FontWeight.w600,
          color: readOnly && onTap == null ? HomeStyle.muted : HomeStyle.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 19, color: HomeStyle.muted),
          hintStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppFontSize.bodyLarge,
              fontWeight: FontWeight.w500),
          errorStyle: TextStyle(fontSize: AppFontSize.caption),
          filled: true,
          fillColor: HomeStyle.cardMuted,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: GlassInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: HomeStyle.divider),
          ),
          enabledBorder: GlassInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: HomeStyle.divider),
          ),
          focusedBorder: GlassInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: HomeStyle.orange, width: 1.5),
          ),
          errorBorder: GlassInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: GlassInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
        validator: validator,
      );
}

// ── Avatar initials fallback ──────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
        color: HomeStyle.peach,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
                fontSize: AppFontSize.xxlarge,
                fontWeight: FontWeight.w600,
                color: HomeStyle.orange),
          ),
        ),
      );
}

// ── City picker bottom sheet ──────────────────────────────────────────────────

class _CityPicker extends StatefulWidget {
  final List<CityItem> cities;
  final int? selectedId;
  const _CityPicker({required this.cities, this.selectedId});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  final _search = TextEditingController();
  List<CityItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.cities;
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.cities
            : widget.cities
                .where((c) => c.name.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return GlassBottomSheet(
      child: SizedBox(
        height: (MediaQuery.of(context).size.height * .68 -
                MediaQuery.viewInsetsOf(context).bottom)
            .clamp(160.0, MediaQuery.of(context).size.height),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Chọn khu vực',
                    style: TextStyle(
                        fontSize: AppFontSize.display,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 24, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm tỉnh/thành phố...',
                  hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSize.bodyLarge),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary, size: 19),
                  suffixIcon: _search.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _search.clear(),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary, size: 17),
                        )
                      : null,
                  filled: true,
                  fillColor: HomeStyle.cardMuted,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: GlassInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  enabledBorder: GlassInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: HomeStyle.divider),
                  ),
                  focusedBorder: GlassInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide:
                        const BorderSide(color: HomeStyle.orange, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_off_outlined,
                            size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text('Không tìm thấy thành phố',
                            style: TextStyle(
                                fontSize: AppFontSize.body,
                                color: AppColors.textSecondary)),
                      ]),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(top: 4, bottom: bottom + 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final city = _filtered[i];
                        final selected = city.id == widget.selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, city),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 15),
                            decoration: BoxDecoration(
                              color: selected
                                  ? HomeStyle.peach
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Text(city.name,
                                    style: TextStyle(
                                        fontSize: AppFontSize.bodyLarge,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selected
                                            ? HomeStyle.orange
                                            : AppColors.textPrimary)),
                              ),
                              if (selected)
                                const Icon(Icons.check_rounded,
                                    size: 22, color: HomeStyle.orange),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar source button ──────────────────────────────────────────────────────

class _AvatarSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AvatarSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            color: HomeStyle.cardMuted,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: HomeStyle.divider),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: HomeStyle.orange),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
        ),
      );
}

// ── Flat building blocks ──────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  const _FlatCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: HomeStyle.divider),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
}

class _FlatIcon extends StatelessWidget {
  const _FlatIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 18, color: color),
      );
}
