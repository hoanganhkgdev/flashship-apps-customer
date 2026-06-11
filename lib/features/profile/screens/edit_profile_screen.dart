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
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int?   _cityId;
  String _cityName        = '';
  bool   _saving          = false;
  bool   _uploadingAvatar = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text  = user.name;
      _emailCtrl.text = user.email ?? '';
      _cityId         = user.cityId;
      _cityName       = user.cityName ?? '';
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
    setState(() { _saving = true; _profileError = null; });

    final err = await ref.read(authProvider.notifier).updateProfile(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      cityId:   _cityId,
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
      if (mounted) GoRouter.of(context).pop();
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ảnh đại diện',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              // Options row
              Row(children: [
                Expanded(
                  child: _AvatarSourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Thư viện',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AvatarSourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Máy ảnh',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    // Let the bottom sheet fully dismiss before presenting the image picker
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
          backgroundColor: AppColors.danger,
        ),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CityPicker(cities: cities, selectedId: _cityId),
    );
    if (picked != null) {
      setState(() { _cityId = picked.id; _cityName = picked.name; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user        = ref.watch(authProvider).user;
    final citiesAsync = ref.watch(citiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chỉnh sửa hồ sơ',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            // ── Avatar ────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: GestureDetector(
                  onTap: _uploadingAvatar ? null : _pickAvatar,
                  child: Stack(children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2.5),
                      ),
                      child: ClipOval(
                        child: user?.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _AvatarInitials(initials: user.initials),
                                errorWidget: (_, __, ___) => _AvatarInitials(initials: user.initials),
                              )
                            : _AvatarInitials(initials: user?.initials ?? 'U'),
                      ),
                    ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                          child: const Center(child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )),
                        ),
                      ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Thông tin cơ bản ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _SectionHeader('Thông tin cơ bản'),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _InputField(
                  label: 'Họ và tên',
                  icon: Icons.person_outline_rounded,
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Số điện thoại',
                  icon: Icons.phone_outlined,
                  initialValue: user?.phone ?? '',
                  readOnly: true,
                  suffixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'Tuỳ chọn',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                if (_profileError != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBox(message: _profileError!),
                ],
              ]),
            ),

            const SizedBox(height: 8),

            // ── Khu vực ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _SectionHeader('Khu vực'),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: citiesAsync.when(
                loading: () => _InputField(
                  label: 'Thành phố',
                  icon: Icons.location_city_outlined,
                  readOnly: true,
                  hint: 'Đang tải...',
                ),
                error: (_, __) => _InputField(
                  label: 'Thành phố',
                  icon: Icons.location_city_outlined,
                  readOnly: true,
                  hint: 'Không tải được',
                ),
                data: (cities) => GestureDetector(
                  onTap: () => _pickCity(cities),
                  child: _InputField(
                    label: 'Thành phố',
                    icon: Icons.location_city_outlined,
                    readOnly: true,
                    initialValue: _cityName,
                    hint: 'Chọn thành phố',
                    suffixIcon: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.divider,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Lưu thay đổi',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar initials fallback ──────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8720C),
    child: Center(
      child: Text(
        initials,
        style: const TextStyle(
            fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
  );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 4, height: 16,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 8),
    Text(text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
  ]);
}

// ── Input field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.icon,
    this.controller,
    this.initialValue,
    this.hint,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: readOnly ? AppColors.textSecondary : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
            fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
        hintText: hint,
        prefixIcon: Icon(icon, size: 18,
            color: readOnly ? AppColors.textSecondary : AppColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      validator: validator,
    );
  }
}

// ── Error box ─────────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
          style: const TextStyle(color: AppColors.danger, fontSize: 13))),
    ]),
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
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Chọn thành phố',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Tìm thành phố...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final city     = _filtered[i];
              final selected = city.id == widget.selectedId;
              return ListTile(
                title: Text(city.name,
                    style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? AppColors.primary : AppColors.textPrimary)),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, city),
              );
            },
          ),
        ),
      ]),
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ]),
    ),
  );
}
