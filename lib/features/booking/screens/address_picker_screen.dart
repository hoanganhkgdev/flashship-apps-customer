import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/address_history_service.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
import 'map_picker_screen.dart';

class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  List<AddressHistoryItem> _history     = [];
  List<AddressResult>      _suggestions = [];
  bool _searching  = false;
  bool _selecting  = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  Future<void> _loadHistory() async {
    final h = await AddressHistoryService.load();
    if (!mounted) return;
    setState(() => _history = h);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await AddressSearchService.search(value);
      if (!mounted) return;
      setState(() { _suggestions = results; _searching = false; });
    });
  }

  Future<void> _selectFromSearch(AddressResult r) async {
    setState(() => _selecting = true);
    final detail = await AddressSearchService.getDetail(r);
    if (!mounted) return;
    setState(() => _selecting = false);
    if (detail != null && detail.lat != null && detail.lng != null) {
      final item = AddressHistoryItem(address: detail.display, lat: detail.lat!, lng: detail.lng!);
      await AddressHistoryService.save(item);
      if (!mounted) return;
      Navigator.of(context).pop(MapPickResult(address: detail.display, lat: detail.lat!, lng: detail.lng!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được tọa độ. Thử lại hoặc chọn từ bản đồ.')),
      );
    }
  }

  Future<void> _selectFromHistory(AddressHistoryItem item) async {
    await AddressHistoryService.save(item);
    if (!mounted) return;
    Navigator.of(context).pop(MapPickResult(address: item.address, lat: item.lat, lng: item.lng));
  }

  Future<void> _removeHistory(AddressHistoryItem item) async {
    await AddressHistoryService.remove(item.address);
    setState(() => _history.removeWhere((e) => e.address == item.address));
  }

  Future<void> _clearAllHistory() async {
    await AddressHistoryService.clear();
    setState(() => _history = []);
  }

  Future<void> _openMap() async {
    _focusNode.unfocus();
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null && mounted) {
      await AddressHistoryService.save(
        AddressHistoryItem(address: result.address, lat: result.lat, lng: result.lng),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    }
  }

  bool get _showHistory => _controller.text.trim().length < 3;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header: back + search ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(0, topPad + 8, 16, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm địa chỉ...',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 15),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: AppColors.textSecondary),
                              ),
                            )
                          : _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_rounded,
                                      color: AppColors.textSecondary, size: 18),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _suggestions = []);
                                  },
                                )
                              : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selecting)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),

          // ── Chọn từ bản đồ ────────────────────────────────────────────
          const SizedBox(height: 8),
          _MapRow(onTap: _openMap),

          // ── Nội dung: lịch sử hoặc kết quả ───────────────────────────
          if (_showHistory && _history.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionLabel(
              label: 'Đã tìm gần đây',
              trailing: TextButton(
                onPressed: _clearAllHistory,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Xóa tất cả',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, indent: 52, color: Color(0xFFF0F0F0)),
                  itemBuilder: (_, i) {
                    final item = _history[i];
                    return Dismissible(
                      key: ValueKey(item.address),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppColors.danger.withValues(alpha: 0.08),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger, size: 20),
                      ),
                      onDismissed: (_) => _removeHistory(item),
                      child: InkWell(
                        onTap: () => _selectFromHistory(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                          child: Row(children: [
                            const Icon(Icons.history_rounded,
                                size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(item.address,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else if (!_showHistory) ...[
            const SizedBox(height: 8),
            Expanded(
              child: _suggestions.isEmpty && !_searching
                  ? const Center(
                      child: Text('Không tìm thấy địa chỉ',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                    )
                  : Container(
                      color: Colors.white,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 52, color: Color(0xFFF0F0F0)),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return InkWell(
                            onTap: () => _selectFromSearch(s),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                              child: Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.mainText.isNotEmpty ? s.mainText : s.display,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (s.secondaryText.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(s.secondaryText,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

// ── Map row ───────────────────────────────────────────────────────────────────

class _MapRow extends StatelessWidget {
  final VoidCallback onTap;
  const _MapRow({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text('Chọn vị trí trên bản đồ',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.textSecondary),
      ]),
    ),
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
    child: Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
      ),
      if (trailing != null) trailing!,
    ]),
  );
}
