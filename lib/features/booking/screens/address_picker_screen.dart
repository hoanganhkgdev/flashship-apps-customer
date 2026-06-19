import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/address_history_service.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/models/address_model.dart';
import 'map_picker_screen.dart';

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  List<AddressHistoryItem> _history       = [];
  List<AddressModel>       _savedAddresses = [];
  List<AddressResult>      _suggestions   = [];
  bool _searching       = false;
  bool _selecting       = false;
  bool _showAllHistory  = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSavedAddresses();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  Future<void> _loadHistory() async {
    final h = await AddressHistoryService.load();
    if (!mounted) return;
    setState(() => _history = h);
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final res = await ref.read(apiClientProvider).get('/customer/addresses');
      final list = (res.data['data'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(AddressModel.fromJson)
          .toList();
      if (mounted) setState(() => _savedAddresses = list);
    } catch (_) {}
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
      final placeName = r.mainText.isNotEmpty && r.mainText != detail.display ? r.mainText : null;
      final item = AddressHistoryItem(
        address: detail.display, lat: detail.lat!, lng: detail.lng!, placeName: placeName);
      await AddressHistoryService.save(item);
      if (!mounted) return;
      Navigator.of(context).pop(MapPickResult(
        address:   detail.display,
        lat:       detail.lat!,
        lng:       detail.lng!,
        placeName: placeName,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được tọa độ. Thử lại hoặc chọn từ bản đồ.')),
      );
    }
  }

  Future<void> _selectFromHistory(AddressHistoryItem item) async {
    await AddressHistoryService.save(item);
    if (!mounted) return;
    Navigator.of(context).pop(MapPickResult(
      address: item.address, lat: item.lat, lng: item.lng,
      placeName: item.placeName,
    ));
  }

  void _selectFromSaved(AddressModel addr) {
    if (addr.latitude == null || addr.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Địa chỉ này chưa có tọa độ, vui lòng cập nhật lại'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    Navigator.of(context).pop(MapPickResult(
      address:   addr.address,
      lat:       addr.latitude!,
      lng:       addr.longitude!,
      placeName: addr.placeName,
    ));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Column(
        children: [
          // ── Header: back + search ──────────────────────────────────────
          ColoredBox(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                    const SizedBox(width: 10),
                    // Search field
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onChanged,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tìm địa chỉ, tên địa điểm...',
                            hintStyle: const TextStyle(
                                color: Color(0xFFBBBBBB), fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 20, color: AppColors.textSecondary),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.textSecondary),
                                    ),
                                  )
                                : _controller.text.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _controller.clear();
                                          setState(() => _suggestions = []);
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Icon(Icons.cancel_rounded,
                                              size: 18,
                                              color: AppColors.textSecondary),
                                        ),
                                      )
                                    : null,
                            filled: true,
                            fillColor: const Color(0xFFF6F6F6),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 0),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                if (_selecting)
                  const LinearProgressIndicator(
                      minHeight: 2, color: AppColors.primary),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _showHistory
                ? DefaultTabController(
                    length: 2,
                    child: Column(children: [
                      // Map card
                      const SizedBox(height: 8),
                      _mapCard(),
                      // Tab bar
                      Container(
                        color: Colors.white,
                        child: const TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          unselectedLabelStyle: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 2,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Color(0xFFF0F0F0),
                          tabs: [
                            Tab(text: 'Gần đây'),
                            Tab(text: 'Đã lưu'),
                          ],
                        ),
                      ),
                      // Tab content
                      Expanded(
                        child: TabBarView(children: [
                          _buildRecentTab(),
                          _buildSavedTab(),
                        ]),
                      ),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      const SizedBox(height: 12),
                      _mapCard(),
                      if (_suggestions.isEmpty && !_searching)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('Không tìm thấy địa chỉ',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary)),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _card(children: [
                            for (int i = 0; i < _suggestions.length; i++) ...[
                              if (i > 0)
                                const Divider(height: 1, indent: 60,
                                    color: Color(0xFFF0F0F0)),
                              _SuggestionItem(
                                suggestion: _suggestions[i],
                                onTap: () => _selectFromSearch(_suggestions[i]),
                              ),
                            ],
                          ]),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.history_rounded,
                size: 34, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Text('Chưa có lịch sử tìm kiếm',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }
    const kInitial = 10;
    final visible = _showAllHistory ? _history : _history.take(kInitial).toList();
    final hasMore = !_showAllHistory && _history.length > kInitial;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _card(children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
            Dismissible(
              key: ValueKey(visible[i].address),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: AppColors.danger.withValues(alpha: 0.08),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 20),
              ),
              onDismissed: (_) => _removeHistory(visible[i]),
              child: _HistoryItem(
                item: visible[i],
                onTap: () => _selectFromHistory(visible[i]),
              ),
            ),
          ],
          if (hasMore) ...[
            const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
            InkWell(
              onTap: () => setState(() => _showAllHistory = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Xem thêm ${_history.length - kInitial} địa chỉ',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _clearAllHistory,
          child: const Center(
            child: Text('Xóa tất cả lịch sử',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (_savedAddresses.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.bookmark_outline_rounded,
                size: 34, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Text('Chưa có địa chỉ đã lưu',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _card(children: [
          for (int i = 0; i < _savedAddresses.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
            _SavedAddressItem(
              addr: _savedAddresses[i],
              onTap: () => _selectFromSaved(_savedAddresses[i]),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _mapCard() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: GestureDetector(
      onTap: _openMap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chọn vị trí trên bản đồ',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('Kéo ghim để xác định chính xác',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.textSecondary),
        ]),
      ),
    ),
  );

  Widget _card({required List<Widget> children}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

// ── Saved address item ────────────────────────────────────────────────────────

class _SavedAddressItem extends StatelessWidget {
  final AddressModel addr;
  final VoidCallback onTap;
  const _SavedAddressItem({required this.addr, required this.onTap});

  Color get _iconColor {
    final label = addr.label.toLowerCase();
    if (label == 'nhà') return AppColors.primary;
    if (label == 'cơ quan') return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  IconData get _icon {
    final label = addr.label.toLowerCase();
    if (label == 'nhà') return Icons.home_rounded;
    if (label == 'cơ quan') return Icons.business_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _iconColor.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, size: 18, color: _iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(addr.label.isNotEmpty ? addr.label : addr.displayTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(addr.placeName?.isNotEmpty == true
                      ? '${addr.placeName} · ${addr.address}'
                      : addr.address,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textSecondary),
      ]),
    ),
  );
}

// ── History item ──────────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final AddressHistoryItem item;
  final VoidCallback onTap;
  const _HistoryItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.history_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: item.placeName != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.placeName!,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.address,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])
              : Text(item.address,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.north_west_rounded,
            size: 14, color: AppColors.textSecondary),
      ]),
    ),
  );
}

// ── Suggestion item ───────────────────────────────────────────────────────────

class _SuggestionItem extends StatelessWidget {
  final AddressResult suggestion;
  final VoidCallback onTap;
  const _SuggestionItem({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0E6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded,
              size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.mainText.isNotEmpty
                    ? suggestion.mainText
                    : suggestion.display,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (suggestion.secondaryText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(suggestion.secondaryText,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ]),
    ),
  );
}

