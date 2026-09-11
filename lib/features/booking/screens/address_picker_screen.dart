import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/address_history_service.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/glass_input_border.dart';
import '../../home/widgets/home_style.dart';
import '../../profile/models/address_model.dart';
import '../../profile/providers/active_city_provider.dart';
import '../../profile/providers/addresses_provider.dart';
import '../../profile/providers/cities_provider.dart';
import 'map_picker_screen.dart';

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  ConsumerState<AddressPickerScreen> createState() =>
      _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<AddressHistoryItem> _history = [];
  List<AddressModel> _savedAddresses = [];
  List<AddressResult> _suggestions = [];
  bool _searching = false;
  bool _searchError = false;
  bool _selecting = false;
  bool _showAllHistory = false;
  Timer? _debounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSavedAddresses();
    // Khởi động sớm để có lat/lng khu vực kịp lúc gõ tìm kiếm.
    ref.read(citiesProvider);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
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
    final requestId = ++_searchRequestId;
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _searchError = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = false;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final region = ref.read(activeCityProvider);
      final cityName = region.cityName.trim();
      // Toạ độ khu vực lấy động từ danh sách city (API /cities, có lat/lng) —
      // khớp theo cityId đã đăng ký trước, tên khu vực sau. Fallback về map
      // tĩnh kCityCenters cho city cũ chưa có lat/lng trong DB.
      // Chờ đúng danh sách city tải xong (thay vì đọc giá trị tạm còn null)
      // — tránh gõ tìm ngay lúc mới mở màn bị mất bo vùng khu vực.
      final cities = await ref.read(citiesProvider.future).catchError(
            (_) => const <CityItem>[],
          );
      CityItem? city;
      for (final c in cities) {
        if (c.id == region.cityId) {
          city = c;
          break;
        }
      }
      city ??= () {
        for (final c in cities) {
          if (c.name == cityName) return c;
        }
        return null;
      }();
      final center = (city?.lat != null && city?.lng != null)
          ? LatLng(city!.lat!, city.lng!)
          : kCityCenters[cityName];
      try {
        // Chỉ bo vùng theo toạ độ (giống trang tổng đài backend) — không
        // chèn tên khu vực vào câu tìm và không lọc lại theo từ khoá, vì 2
        // lớp lọc chồng lên strictbounds dễ làm rớt hết kết quả hợp lệ.
        final results = await AddressSearchService.search(
          value,
          lat: center?.latitude,
          lng: center?.longitude,
          circleRadius: kAddressSearchRadiusKm,
          restrictToBounds: center != null,
        );
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _suggestions = [];
          _searching = false;
          _searchError = true;
        });
      }
    });
  }

  Future<void> _selectFromSearch(AddressResult r) async {
    setState(() => _selecting = true);
    final detail = await AddressSearchService.getDetail(r);
    if (!mounted) return;
    setState(() => _selecting = false);
    if (detail != null && detail.lat != null && detail.lng != null) {
      final placeName = r.mainText.isNotEmpty && r.mainText != detail.display
          ? r.mainText
          : null;
      final item = AddressHistoryItem(
          address: detail.display,
          lat: detail.lat!,
          lng: detail.lng!,
          placeName: placeName);
      await AddressHistoryService.save(item);
      if (!mounted) return;
      Navigator.of(context).pop(MapPickResult(
        address: detail.display,
        lat: detail.lat!,
        lng: detail.lng!,
        placeName: placeName,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Không lấy được tọa độ. Thử lại hoặc chọn từ bản đồ.')),
      );
    }
  }

  Future<void> _selectFromHistory(AddressHistoryItem item) async {
    await AddressHistoryService.save(item);
    if (!mounted) return;
    Navigator.of(context).pop(MapPickResult(
      address: item.address,
      lat: item.lat,
      lng: item.lng,
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
      address: addr.address,
      lat: addr.latitude!,
      lng: addr.longitude!,
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
        AddressHistoryItem(
            address: result.address, lat: result.lat, lng: result.lng),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    }
  }

  bool get _showHistory => _controller.text.trim().length < 3;

  @override
  Widget build(BuildContext context) {
    return LiquidBackdrop(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ColoredBox(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Chọn địa chỉ',
                          style: TextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    LiquidGlass(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: HomeStyle.radius),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded,
                              size: 22, color: HomeStyle.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onChanged,
                          textAlignVertical: TextAlignVertical.center,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Địa chỉ, tên địa điểm...',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: .45),
                            enabledBorder: const GlassInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.white, width: 1.2)),
                            focusedBorder: const GlassInputBorder(
                                borderSide:
                                    BorderSide(color: HomeStyle.orange)),
                            hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: AppFontSize.bodyLarge),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 21, color: HomeStyle.orange),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.textSecondary),
                                    ),
                                  )
                                : _controller.text.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'Xóa tìm kiếm',
                                        onPressed: () {
                                          _debounce?.cancel();
                                          _searchRequestId++;
                                          _controller.clear();
                                          setState(() {
                                            _suggestions = [];
                                            _searching = false;
                                            _searchError = false;
                                          });
                                        },
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18, color: HomeStyle.muted),
                                      )
                                    : null,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                if (_selecting)
                  const LinearProgressIndicator(
                      minHeight: 2, color: AppColors.primary),
                const SizedBox(height: 4),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _showHistory
                ? DefaultTabController(
                    length: 2,
                    child: Column(children: [
                      const SizedBox(height: 18),
                      _mapCard(),
                      _quickSavedRow(),
                      Container(
                        color: Colors.transparent,
                        child: const TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600),
                          unselectedLabelStyle: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w600),
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 2,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: AppColors.divider,
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
                      _searchRegionLabel(),
                      _mapCard(),
                      if (_suggestions.isEmpty && !_searching && _searchError)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 28, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              const Text(
                                  'Lỗi kết nối, không tải được gợi ý địa chỉ',
                                  style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _onChanged(_controller.text),
                                child: const Text('Thử lại'),
                              ),
                            ]),
                          ),
                        )
                      else if (_suggestions.isEmpty && !_searching)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('Không tìm thấy địa chỉ',
                                style: TextStyle(
                                    fontSize: AppFontSize.body,
                                    color: AppColors.textSecondary)),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _card(children: [
                            for (int i = 0; i < _suggestions.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1,
                                    indent: 60,
                                    color: AppColors.divider),
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
    ));
  }

  Widget _searchRegionLabel() {
    final cityName = ref.watch(activeCityProvider).cityName.trim();
    if (cityName.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Gợi ý trong khu vực $cityName',
              style: const TextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Icon(Icons.history_rounded,
                size: 34, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Text('Chưa có lịch sử tìm kiếm',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
    }
    const kInitial = 3;
    final visible =
        _showAllHistory ? _history : _history.take(kInitial).toList();
    final hasMore = !_showAllHistory && _history.length > kInitial;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _card(children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: AppColors.divider),
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
            const Divider(height: 1, indent: 60, color: AppColors.divider),
            InkWell(
              onTap: () => setState(() => _showAllHistory = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Xem thêm ${_history.length - kInitial} địa chỉ',
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        color: AppColors.primary,
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
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary)),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Icon(Icons.bookmark_outline_rounded,
                size: 34, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Text('Chưa có địa chỉ đã lưu',
              style: TextStyle(
                  fontSize: AppFontSize.body, color: AppColors.textSecondary)),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _card(children: [
          for (int i = 0; i < _savedAddresses.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: AppColors.divider),
            _SavedAddressItem(
              addr: _savedAddresses[i],
              onTap: () => _selectFromSaved(_savedAddresses[i]),
            ),
          ],
        ]),
      ],
    );
  }

  // 2 ô nhanh Nhà/Công ty từ addressesProvider — bấm vào set địa chỉ ngay,
  // không cần gõ tìm. Ẩn hẳn nếu chưa có địa chỉ nào thuộc 2 nhãn này.
  Widget _quickSavedRow() {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    AddressModel? home;
    AddressModel? office;
    for (final a in addresses) {
      home ??= a.label == 'Nhà' ? a : null;
      office ??= (a.label == 'Cơ quan' || a.label == 'Công ty') ? a : null;
    }
    final quick = [if (home != null) home, if (office != null) office];
    if (quick.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          for (int i = 0; i < quick.length; i++) ...[
            Expanded(
              child: _QuickSavedTile(
                addr: quick[i],
                onTap: () => _selectFromSaved(quick[i]),
              ),
            ),
            if (i < quick.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _mapCard() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: GestureDetector(
          onTap: _openMap,
          behavior: HitTestBehavior.opaque,
          child: LiquidGlass(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(children: [
              const GlassIcon(
                  icon: Icons.map_rounded,
                  color: HomeStyle.orange,
                  size: 40,
                  iconSize: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn vị trí trên bản đồ',
                        style: TextStyle(
                            fontSize: AppFontSize.bodyLarge,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Kéo ghim để xác định chính xác',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textSecondary),
            ]),
          ),
        ),
      );

  Widget _card({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LiquidGlass(
            child: Material(
                color: Colors.transparent, child: Column(children: children))),
      );
}

// ── Quick saved address tile (Nhà/Công ty) ──────────────────────────────────────

class _QuickSavedTile extends StatelessWidget {
  final AddressModel addr;
  final VoidCallback onTap;
  const _QuickSavedTile({required this.addr, required this.onTap});

  Color get _color => addr.label == 'Nhà' ? AppColors.primary : AppColors.info;
  IconData get _icon =>
      addr.label == 'Nhà' ? Icons.home_rounded : Icons.business_rounded;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.glass),
          ),
          child: Row(children: [
            GlassIcon(icon: _icon, color: _color, size: 30, iconSize: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(addr.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFontSize.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: _color)),
            ),
          ]),
        ),
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
    if (label == 'cơ quan') return AppColors.info;
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            GlassIcon(icon: _icon, color: _iconColor, size: 34, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr.label.isNotEmpty ? addr.label : addr.displayTitle,
                      style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      addr.placeName?.isNotEmpty == true
                          ? '${addr.placeName} · ${addr.address}'
                          : addr.address,
                      style: const TextStyle(
                          fontSize: AppFontSize.body,
                          color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            GlassIcon(
                icon: Icons.history_rounded,
                color: HomeStyle.muted,
                size: 34,
                iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: item.placeName != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(item.placeName!,
                              style: const TextStyle(
                                  fontSize: AppFontSize.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(item.address,
                              style: const TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ])
                  : Text(item.address,
                      style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            GlassIcon(
                icon: Icons.location_on_rounded,
                color: HomeStyle.orange,
                size: 34,
                iconSize: 18),
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
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(suggestion.secondaryText,
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
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
}
