import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../home/widgets/home_style.dart';
import '../../../features/booking/screens/widgets/address_field.dart';
import '../models/address_model.dart';
import '../providers/addresses_provider.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    final addressCount = async.valueOrNull?.length;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      bottomNavigationBar: addressCount != null && addressCount > 0
          ? DecoratedBox(
              decoration: const BoxDecoration(
                color: HomeStyle.card,
                border: Border(top: BorderSide(color: HomeStyle.divider)),
              ),
              child: SafeArea(
                top: false,
                child: _AddAddressButton(onTap: () => _openForm(context, ref)),
              ),
            )
          : null,
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
                  style: _barButtonStyle,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: HomeStyle.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Địa chỉ đã lưu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      const SizedBox(height: 3),
                      Text(
                        addressCount == null
                            ? 'Quản lý các địa điểm quen thuộc'
                            : '$addressCount địa chỉ · Chạm để chỉnh sửa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
            child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: HomeStyle.orange, strokeWidth: 2)),
          error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.read(addressesProvider.notifier).refresh()),
          data: (list) => list.isEmpty
              ? _EmptyView(onAdd: () => _openForm(context, ref))
              : RefreshIndicator(
                  color: HomeStyle.orange,
                  onRefresh: () =>
                      ref.read(addressesProvider.notifier).refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
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
        )),
      ]),
    );
  }

  static final _barButtonStyle = IconButton.styleFrom(
    fixedSize: const Size.square(44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    backgroundColor: HomeStyle.card,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md)),
  );

  void _openForm(BuildContext context, WidgetRef ref,
      {AddressModel? existing}) {
    showModalBottomSheet(
      showDragHandle: false,
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
        backgroundColor: HomeStyle.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 30),
            ),
            const SizedBox(height: 16),
            Text('Xoá địa chỉ?',
                style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '"${address.label.isEmpty ? address.address : address.label}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: HomeStyle.divider),
                      foregroundColor: HomeStyle.ink,
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
        'Nhà' || 'Nhà riêng' => Icons.home_rounded,
        'Công ty' => Icons.business_center_outlined,
        'Cơ quan' => Icons.business_rounded,
        _ => Icons.location_on_rounded,
      };

  Color get _iconColor => switch (address.label) {
        'Nhà' || 'Nhà riêng' => HomeStyle.orange,
        'Công ty' => AppColors.info,
        'Cơ quan' => AppColors.info,
        _ => AppColors.accent2,
      };

  @override
  Widget build(BuildContext context) {
    final color = _iconColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _FlatCard(
        highlighted: address.isDefault,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FlatIcon(icon: _icon, color: color),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(
                            address.label.isEmpty ? 'Địa chỉ' : address.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppFontSize.bodyLarge,
                                fontWeight: FontWeight.w800,
                                color: HomeStyle.ink),
                          )),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          address.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFontSize.body,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: HomeStyle.ink),
                        ),
                        if (address.displaySubtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            address.displaySubtitle!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                height: 1.35,
                                color: HomeStyle.muted),
                          ),
                        ],
                        if (address.isDefault) ...[
                          const SizedBox(height: 10),
                          const Row(children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: HomeStyle.orange),
                            SizedBox(width: 5),
                            Expanded(
                                child: Text('Địa chỉ mặc định',
                                    style: TextStyle(
                                      fontSize: AppFontSize.caption,
                                      fontWeight: FontWeight.w600,
                                      color: HomeStyle.orange,
                                    ))),
                          ]),
                        ],
                      ],
                    ),
                  ),

                  // 3-dot menu
                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn địa chỉ',
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: HomeStyle.muted, size: 21),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    color: HomeStyle.card,
                    elevation: 2,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.textPrimary),
                            const SizedBox(width: 10),
                            const Text('Chỉnh sửa'),
                          ])),
                      if (!address.isDefault)
                        PopupMenuItem(
                            value: 'default',
                            child: Row(children: [
                              const Icon(Icons.star_outline_rounded,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: 10),
                              const Text('Đặt làm mặc định'),
                            ])),
                      PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            const Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.danger),
                            const SizedBox(width: 10),
                            const Text('Xoá',
                                style: TextStyle(color: AppColors.danger)),
                          ])),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'default') onSetDefault?.call();
                      if (v == 'delete') onDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: HomeStyle.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 21),
          label: const Text('Thêm địa chỉ mới',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
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
  final _formKey = GlobalKey<FormState>();
  final _addrCtrl = TextEditingController();
  final _customCtrl = TextEditingController();

  String _label = 'Nhà';
  bool _isDefault = false;
  double? _lat;
  double? _lng;
  bool _saving = false;
  String? _error;

  static const _presets = ['Nhà', 'Cơ quan', 'Khác'];
  static const _presetIcons = {
    'Nhà': Icons.home_rounded,
    'Cơ quan': Icons.business_rounded,
    'Khác': Icons.location_on_rounded,
  };

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _addrCtrl.text = a.address;
      _lat = a.latitude;
      _lng = a.longitude;
      _isDefault = a.isDefault;
      if (_presets.contains(a.label)) {
        _label = a.label;
      } else {
        _label = 'Khác';
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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final finalLabel = _label == 'Khác'
        ? (_customCtrl.text.trim().isEmpty ? 'Khác' : _customCtrl.text.trim())
        : _label;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing == null) {
        await widget.ref.read(addressesProvider.notifier).add(
              label: finalLabel,
              address: _addrCtrl.text.trim(),
              lat: _lat,
              lng: _lng,
              isDefault: _isDefault,
            );
      } else {
        await widget.ref.read(addressesProvider.notifier).edit(
              id: widget.existing!.id,
              label: finalLabel,
              address: _addrCtrl.text.trim(),
              lat: _lat,
              lng: _lng,
              isDefault: _isDefault,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
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
      child: GlassBottomSheet(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 24 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 24),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ mới',
                          style: const TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEdit
                              ? 'Cập nhật thông tin địa điểm đã lưu'
                              : 'Lưu địa điểm để đặt đơn nhanh hơn',
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted),
                        ),
                      ],
                    ),
                  ),
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
                          size: 23, color: AppColors.textSecondary),
                    ),
                  ),
                ]),

                const SizedBox(height: 26),

                // Label picker
                Text('Nhãn địa chỉ',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  runSpacing: 8,
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
                              horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? HomeStyle.orange : HomeStyle.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected
                                  ? HomeStyle.orange.withValues(alpha: .3)
                                  : HomeStyle.divider,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_presetIcons[p]!,
                                size: 18,
                                color:
                                    selected ? Colors.white : HomeStyle.muted),
                            const SizedBox(width: 6),
                            Text(p,
                                style: TextStyle(
                                    fontSize: AppFontSize.body,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : HomeStyle.muted)),
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
                      fillColor: HomeStyle.cardMuted,
                      hintStyle: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          color: AppColors.textTertiary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 17),
                      border: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              const BorderSide(color: HomeStyle.divider)),
                      enabledBorder: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              const BorderSide(color: HomeStyle.divider)),
                      focusedBorder: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                              color: HomeStyle.orange, width: 1.5)),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Address field
                Text('Địa chỉ',
                    style: TextStyle(
                        fontSize: AppFontSize.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: HomeStyle.cardMuted,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      border: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              const BorderSide(color: HomeStyle.divider)),
                      enabledBorder: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide:
                              const BorderSide(color: HomeStyle.divider)),
                      focusedBorder: GlassInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                              color: HomeStyle.orange, width: 1.5)),
                    ),
                  ),
                  child: AddressField(
                    controller: _addrCtrl,
                    label: 'Nhập địa chỉ...',
                    icon: Icons.location_on_outlined,
                    required: true,
                    onLocationPicked: (addr, lat, lng) {
                      setState(() {
                        _lat = lat;
                        _lng = lng;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Default toggle
                Container(
                  decoration: BoxDecoration(
                    color: HomeStyle.cardMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: HomeStyle.divider),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => setState(() => _isDefault = !_isDefault),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(children: [
                        const Icon(Icons.star_outline_rounded,
                            size: 24, color: HomeStyle.orange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Đặt làm địa chỉ mặc định',
                              style: TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        Switch.adaptive(
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: HomeStyle.orange,
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
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: AppFontSize.body))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeStyle.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      disabledBackgroundColor:
                          HomeStyle.orange.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      textStyle: TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.location_off_rounded,
                  size: 44, color: HomeStyle.orange),
            ),
            const SizedBox(height: 20),
            Text('Chưa có địa chỉ nào',
                style: TextStyle(
                    fontSize: AppFontSize.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Lưu địa chỉ để đặt đơn nhanh hơn',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeStyle.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: HomeStyle.cardMuted,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: HomeStyle.divider),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 40, color: HomeStyle.muted),
          ),
          const SizedBox(height: 16),
          const Text('Không tải được địa chỉ',
              style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Vui lòng kiểm tra kết nối',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: HomeStyle.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Thử lại'),
          ),
        ]),
      );
}

// ── Flat building blocks ──────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  const _FlatCard({required this.child, this.highlighted = false});
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFFAF7) : HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: highlighted
                ? HomeStyle.orange.withValues(alpha: .3)
                : HomeStyle.divider,
          ),
        ),
        child: child,
      );
}

class _FlatIcon extends StatelessWidget {
  const _FlatIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  static const double size = 36;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: size * .5, color: color),
      );
}
