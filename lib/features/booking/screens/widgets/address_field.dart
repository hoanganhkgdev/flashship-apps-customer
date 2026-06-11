import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/address_search_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../map_picker_screen.dart';

class AddressField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool required;
  final ValueChanged<String>? onChanged;
  final void Function(String address, double lat, double lng)? onLocationPicked;
  final void Function(String name, String address)? onPlaceSelected;
  final LatLng? focusPoint;
  final String? filterKeyword;

  const AddressField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.required = false,
    this.onChanged,
    this.onLocationPicked,
    this.onPlaceSelected,
    this.focusPoint,
    this.filterKeyword,
  });

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  List<AddressResult> _suggestions = [];
  bool _searching = false;
  bool _selecting = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  double? _pickedLat;
  double? _pickedLng;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _hideOverlay();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _searching = false);
      _hideOverlay();
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final focus = widget.focusPoint;
      final results = await AddressSearchService.search(
        value,
        lat: focus?.latitude,
        lng: focus?.longitude,
        circleRadius: focus != null ? kAddressSearchRadiusKm : null,
        filterKeyword: widget.filterKeyword,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  void _showOverlay() {
    _hideOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: renderBox.size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, renderBox.size.height + 4),
          child: _SuggestionsList(
            suggestions: _suggestions,
            onSelect: _select,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _select(AddressResult r) async {
    _hideOverlay();
    _focusNode.unfocus();
    final name = r.mainText.isNotEmpty ? r.mainText : r.display;
    widget.controller.text = name;
    widget.onChanged?.call(name);

    setState(() => _selecting = true);
    final detail = await AddressSearchService.getDetail(r);
    if (!mounted) return;
    setState(() => _selecting = false);

    if (detail?.lat != null && detail?.lng != null) {
      _pickedLat = detail!.lat;
      _pickedLng = detail.lng;
      widget.controller.text = detail.display;
      widget.onChanged?.call(detail.display);
      widget.onLocationPicked?.call(detail.display, detail.lat!, detail.lng!);
      widget.onPlaceSelected?.call(name, detail.display);
    }
  }

  Future<void> _openMapPicker() async {
    _hideOverlay();
    _focusNode.unfocus();
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _pickedLat,
          initialLng: _pickedLng,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _pickedLat = result.lat;
    _pickedLng = result.lng;
    widget.controller.text = result.address;
    widget.onChanged?.call(result.address);
    widget.onLocationPicked?.call(result.address, result.lat, result.lng);
    widget.onPlaceSelected?.call(result.address, result.address);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: widget.label.isEmpty ? null : widget.label,
          prefixIcon: Icon(widget.icon, color: widget.iconColor),
          suffixIcon: _selecting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.textSecondary),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.map_outlined),
                      color: AppColors.textSecondary,
                      tooltip: 'Chọn trên bản đồ',
                      onPressed: _openMapPicker,
                    ),
        ),
        validator: widget.required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Trường này bắt buộc' : null
            : null,
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<AddressResult> suggestions;
  final Future<void> Function(AddressResult) onSelect;

  const _SuggestionsList({
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 48, color: Color(0xFFF0F0F5)),
            itemBuilder: (_, i) {
              final s = suggestions[i];
              return _SuggestionTile(result: s, onTap: () => onSelect(s));
            },
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final AddressResult result;
  final VoidCallback onTap;

  const _SuggestionTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.mainText.isNotEmpty ? result.mainText : result.display,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.secondaryText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
