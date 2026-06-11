import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text('Địa chỉ đã lưu',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Thêm địa chỉ',
            onPressed: () => _openForm(context, ref),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
        error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(addressesProvider.notifier).refresh()),
        data: (list) => list.isEmpty
            ? _EmptyView(onAdd: () => _openForm(context, ref))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(addressesProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: list.asMap().entries.map((entry) {
                          final i    = entry.key;
                          final addr = entry.value;
                          return Column(children: [
                            _AddressRow(
                              address: addr,
                              onEdit:       () => _openForm(context, ref, existing: addr),
                              onSetDefault: addr.isDefault ? null
                                  : () => ref.read(addressesProvider.notifier).setDefault(addr.id),
                              onDelete: () => _confirmDelete(context, ref, addr),
                            ),
                            if (i < list.length - 1)
                              const Divider(height: 1, indent: 64, color: Color(0xFFF5F5F5)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: async.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Thêm địa chỉ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            )
          : null,
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {AddressModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddressForm(existing: existing, ref: ref),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AddressModel address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoá địa chỉ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'Xoá "${address.label.isEmpty ? address.address : address.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(addressesProvider.notifier).delete(address.id);
  }
}

// ── Address row (Grab-style flat) ─────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  const _AddressRow({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  static const _labelIcons = {
    'Nhà':     Icons.home_rounded,
    'Cơ quan': Icons.business_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon      = _labelIcons[address.label] ?? Icons.location_on_rounded;
    final iconColor = address.isDefault ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          // Icon
          SizedBox(
            width: 24,
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),

          // Label + address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    address.label.isEmpty ? 'Địa chỉ' : address.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                  if (address.isDefault) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Mặc định',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(address.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

          // More menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10), Text('Chỉnh sửa'),
                ])),
              if (!address.isDefault)
                const PopupMenuItem(value: 'default',
                  child: Row(children: [
                    Icon(Icons.star_outline_rounded, size: 18),
                    SizedBox(width: 10), Text('Đặt làm mặc định'),
                  ])),
              const PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Xoá', style: TextStyle(color: AppColors.danger)),
                ])),
            ],
            onSelected: (v) {
              if (v == 'edit')    onEdit();
              if (v == 'default') onSetDefault?.call();
              if (v == 'delete')  onDelete();
            },
          ),
        ]),
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
      setState(() { _error = 'Không lưu được. Thử lại sau.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ mới',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Label picker ─────────────────────────────────────────────
              const Text('Nhãn',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Row(
                children: _presets.map((p) {
                  final selected = _label == p;
                  return Padding(
                    padding: EdgeInsets.only(right: p == _presets.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _label = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_presetIcons[p]!, size: 15,
                              color: selected ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(p,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : AppColors.textSecondary)),
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
                    prefixIcon: const Icon(Icons.label_outline_rounded,
                        color: AppColors.primary, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Address field ────────────────────────────────────────────
              const Text('Địa chỉ',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              AddressField(
                controller: _addrCtrl,
                label: 'Nhập địa chỉ...',
                icon: Icons.location_on_outlined,
                required: true,
              ),

              const SizedBox(height: 20),

              // ── Default toggle (flat Grab style) ─────────────────────────
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              InkWell(
                onTap: () => setState(() => _isDefault = !_isDefault),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.star_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Đặt làm địa chỉ mặc định',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                    ),
                    Switch.adaptive(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ]),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13))),
                ]),
              ],

              const SizedBox(height: 24),

              // ── Save button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.divider,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Cập nhật' : 'Lưu địa chỉ',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
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
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_off_rounded,
              size: 44, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        const Text('Chưa có địa chỉ nào',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Lưu địa chỉ để đặt đơn nhanh hơn',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Thêm địa chỉ đầu tiên',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
      const SizedBox(height: 12),
      const Text('Không tải được địa chỉ',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );
}
