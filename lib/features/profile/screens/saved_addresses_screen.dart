import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/booking/screens/widgets/address_field.dart';
import '../models/address_model.dart';
import '../providers/addresses_provider.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        leadingWidth: 64,
        title: Text('Địa chỉ đã lưu',
            style: GoogleFonts.beVietnamPro(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          GestureDetector(
            onTap: () => _openForm(context, ref),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Thêm',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ]),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
        error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(addressesProvider.notifier).refresh()),
        data: (list) => list.isEmpty
            ? _EmptyView(onAdd: () => _openForm(context, ref))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(addressesProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final addr = list[i];
                    return _AddressCard(
                      address: addr,
                      onEdit: () => _openForm(context, ref, existing: addr),
                      onSetDefault: addr.isDefault
                          ? null
                          : () => ref
                              .read(addressesProvider.notifier)
                              .setDefault(addr.id),
                      onDelete: () => _confirmDelete(context, ref, addr),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref,
      {AddressModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressForm(existing: existing, ref: ref),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AddressModel address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 30),
            ),
            const SizedBox(height: 16),
            Text('Xoá địa chỉ?',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '"${address.label.isEmpty ? address.address : address.label}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Huỷ'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Xoá'),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true) ref.read(addressesProvider.notifier).delete(address.id);
  }
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  IconData get _icon => switch (address.label) {
        'Nhà'     => Icons.home_rounded,
        'Cơ quan' => Icons.business_rounded,
        _         => Icons.location_on_rounded,
      };

  Color get _iconColor => switch (address.label) {
        'Nhà'     => AppColors.primary,
        'Cơ quan' => const Color(0xFF3B82F6),
        _         => const Color(0xFF8B5CF6),
      };

  @override
  Widget build(BuildContext context) {
    final color = _iconColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          address.label.isEmpty ? 'Địa chỉ' : address.label,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Mặc định',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        address.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (address.displaySubtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          address.displaySubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3-dot menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.textPrimary),
                          const SizedBox(width: 10),
                          const Text('Chỉnh sửa'),
                        ])),
                    if (!address.isDefault)
                      PopupMenuItem(value: 'default',
                          child: Row(children: [
                            const Icon(Icons.star_outline_rounded,
                                size: 18, color: AppColors.warning),
                            const SizedBox(width: 10),
                            const Text('Đặt làm mặc định'),
                          ])),
                    PopupMenuItem(value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.danger),
                          const SizedBox(width: 10),
                          const Text('Xoá',
                              style: TextStyle(color: AppColors.danger)),
                        ])),
                  ],
                  onSelected: (v) {
                    if (v == 'edit')    onEdit();
                    if (v == 'default') onSetDefault?.call();
                    if (v == 'delete')  onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Address form (bottom sheet) ───────────────────────────────────────────────

class _AddressForm extends StatefulWidget {
  final AddressModel? existing;
  final WidgetRef ref;
  const _AddressForm({this.existing, required this.ref});

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _formKey    = GlobalKey<FormState>();
  final _addrCtrl   = TextEditingController();
  final _customCtrl = TextEditingController();

  String  _label     = 'Nhà';
  bool    _isDefault = false;
  double? _lat;
  double? _lng;
  bool    _saving    = false;
  String? _error;

  static const _presets = ['Nhà', 'Cơ quan', 'Khác'];
  static const _presetIcons = {
    'Nhà':     Icons.home_rounded,
    'Cơ quan': Icons.business_rounded,
    'Khác':    Icons.location_on_rounded,
  };

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _addrCtrl.text = a.address;
      _lat           = a.latitude;
      _lng           = a.longitude;
      _isDefault     = a.isDefault;
      if (_presets.contains(a.label)) {
        _label = a.label;
      } else {
        _label           = 'Khác';
        _customCtrl.text = a.label;
      }
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final finalLabel = _label == 'Khác'
        ? (_customCtrl.text.trim().isEmpty ? 'Khác' : _customCtrl.text.trim())
        : _label;

    setState(() { _saving = true; _error = null; });
    try {
      if (widget.existing == null) {
        await widget.ref.read(addressesProvider.notifier).add(
          label: finalLabel, address: _addrCtrl.text.trim(),
          lat: _lat, lng: _lng, isDefault: _isDefault,
        );
      } else {
        await widget.ref.read(addressesProvider.notifier).edit(
          id: widget.existing!.id, label: finalLabel,
          address: _addrCtrl.text.trim(),
          lat: _lat, lng: _lng, isDefault: _isDefault,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() {
        _error = 'Không lưu được. Thử lại sau.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ mới',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // Label picker
                Text('Nhãn địa chỉ',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  children: _presets.map((p) {
                    final selected = _label == p;
                    return Padding(
                      padding:
                          EdgeInsets.only(right: p == _presets.last ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _label = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_presetIcons[p]!, size: 15,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(p,
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textSecondary)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_label == 'Khác') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tên nhãn (vd: Nhà bạn, Gym...)',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Address field
                Text('Địa chỉ',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                AddressField(
                  controller: _addrCtrl,
                  label: 'Nhập địa chỉ...',
                  icon: Icons.location_on_outlined,
                  required: true,
                  onLocationPicked: (addr, lat, lng) {
                    setState(() { _lat = lat; _lng = lng; });
                  },
                ),

                const SizedBox(height: 20),

                // Default toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        setState(() => _isDefault = !_isDefault),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.star_outline_rounded,
                            size: 20, color: AppColors.warning),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Đặt làm địa chỉ mặc định',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                        ),
                        Switch.adaptive(
                          value: _isDefault,
                          onChanged: (v) =>
                              setState(() => _isDefault = v),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ]),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity, height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      textStyle: GoogleFonts.beVietnamPro(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Cập nhật' : 'Lưu địa chỉ'),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.location_off_rounded,
                  size: 44, color: Color(0xFFBBBBBB)),
            ),
            const SizedBox(height: 20),
            Text('Chưa có địa chỉ nào',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Lưu địa chỉ để đặt đơn nhanh hơn',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  textStyle: GoogleFonts.beVietnamPro(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                label: const Text('Thêm địa chỉ đầu tiên'),
              ),
            ),
          ]),
        ),
      );
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 40, color: Color(0xFFBBBBBB)),
          ),
          const SizedBox(height: 16),
          const Text('Không tải được địa chỉ',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Vui lòng kiểm tra kết nối',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Thử lại'),
          ),
        ]),
      );
}
