import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
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
  final _emailCtrl = TextEditingController();

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
      _emailCtrl.text = user.email ?? '';
      _cityId = user.cityId;
      _cityName = user.cityName ?? '';
      _birthDate = user.birthDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _profileError = null;
    });

    final err = await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
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
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 24, color: AppColors.textSecondary),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPicker(cities: cities, selectedId: _cityId),
    );
    if (picked != null) {
      setState(() {
        _cityId = picked.id;
        _cityName = picked.name;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                surface: AppColors.surface,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => context.pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 60,
        title: Text('Chỉnh sửa hồ sơ',
            style: TextStyle(
                fontSize: AppFontSize.display,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 24, 0, bottom + 32),
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Stack(children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
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
                  ),
                  if (_uploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: const Center(
                            child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            // ── Fields card ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                _FormRow(
                  label: 'Họ và tên',
                  child: _FilledField(
                    controller: _nameCtrl,
                    hint: 'Nhập họ và tên',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
                  ),
                ),
                _FormRow(
                  label: 'Số điện thoại',
                  trailing: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.textTertiary),
                  child: _FilledField(
                    initialValue: user?.phone ?? '',
                    hint: 'Số điện thoại',
                    readOnly: true,
                  ),
                ),
                _FormRow(
                  label: 'Email',
                  child: _FilledField(
                    controller: _emailCtrl,
                    hint: 'example@email.com (tuỳ chọn)',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                ),
                GestureDetector(
                  onTap: _pickBirthDate,
                  child: _FormRow(
                    label: 'Ngày sinh',
                    trailing: const Icon(Icons.calendar_month_outlined,
                        size: 20, color: AppColors.textSecondary),
                    child: _FilledField(
                      initialValue: _birthDateLabel,
                      hint: 'Chọn ngày sinh',
                      readOnly: true,
                    ),
                  ),
                ),
                citiesAsync.when(
                  loading: () => _FormRow(
                    label: 'Thành phố',
                    child: _FilledField(hint: 'Đang tải...', readOnly: true),
                  ),
                  error: (_, __) => _FormRow(
                    label: 'Thành phố',
                    child: _FilledField(hint: 'Không tải được', readOnly: true),
                  ),
                  data: (cities) => GestureDetector(
                    onTap: () => _pickCity(cities),
                    child: _FormRow(
                      label: 'Thành phố',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFD0D0D5), size: 20),
                      child: _FilledField(
                        initialValue: _cityName,
                        hint: 'Chọn thành phố',
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            if (_profileError != null) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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

            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    elevation: 0,
                    textStyle:
                        TextStyle(fontSize: AppFontSize.bodyLarge, fontWeight: FontWeight.w600),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Lưu thay đổi'),
                ),
              ),
            ),
          ],
        ),
      ),
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
            Text(label,
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            if (trailing != null) ...[
              const Spacer(),
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
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _FilledField({
    this.controller,
    this.initialValue,
    this.hint,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: readOnly,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: TextStyle(
          fontSize: AppFontSize.bodyLarge,
          fontWeight: FontWeight.w600,
          color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppFontSize.bodyLarge,
              fontWeight: FontWeight.w500),
          errorStyle: TextStyle(fontSize: AppFontSize.caption),
          filled: true,
          fillColor: readOnly ? const Color(0xFFF0E9E5) : AppColors.surfaceAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
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
        color: AppColors.primarySoft,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
                fontSize: AppFontSize.xxlarge,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
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

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 24, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                style: TextStyle(fontSize: AppFontSize.bodyLarge, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm tỉnh/thành phố...',
                  hintStyle:
                      TextStyle(color: AppColors.textSecondary, fontSize: AppFontSize.bodyLarge),
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
                  fillColor: AppColors.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
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
                                fontSize: AppFontSize.body, color: AppColors.textSecondary)),
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
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 15),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFFEEE7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
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
                                            ? AppColors.primary
                                            : AppColors.textPrimary)),
                              ),
                              if (selected)
                                const Icon(Icons.check_rounded,
                                    size: 22, color: AppColors.primary),
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
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 30, color: AppColors.primary),
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
