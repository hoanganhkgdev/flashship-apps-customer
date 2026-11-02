import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/address_history_service.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
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
      _suggestions = [];
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
    if (_selecting) return;
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
    if (!mounted) return;
    setState(() => _history.removeWhere((e) => e.address == item.address));
  }

  Future<void> _clearAllHistory() async {
    await AddressHistoryService.clear();
    if (!mounted) return;
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFFE9DE),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.white,
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
                          Text('Chọn địa chỉ',
                              style: TextStyle(
                                  fontSize: AppFontSize.title,
                                  fontWeight: FontWeight.w800,
                                  color: HomeStyle.ink)),
                          SizedBox(height: 3),
                          Text('Tìm địa điểm hoặc chọn trên bản đồ',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppFontSize.caption,
                                  color: HomeStyle.muted)),
                        ],
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _focusNode.unfocus(),
                    style: const TextStyle(
                        fontSize: AppFontSize.bodyLarge, color: HomeStyle.ink),
                    decoration: InputDecoration(
                      hintText: 'Nhập địa chỉ hoặc tên địa điểm',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .92),
                      border: _searchBorder(Colors.transparent),
                      enabledBorder: _searchBorder(Colors.transparent),
                      focusedBorder: _searchBorder(HomeStyle.orange, 1.5),
                      hintStyle: const TextStyle(
                          color: HomeStyle.muted,
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
                                    strokeWidth: 1.5, color: HomeStyle.muted),
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
                if (_controller.text.trim().isNotEmpty && _showHistory)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nhập ít nhất 3 ký tự để tìm địa chỉ',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted,
                          )),
                    ),
                  ),
                if (_selecting)
                  const LinearProgressIndicator(
                      minHeight: 2, color: HomeStyle.orange),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _showHistory
                ? DefaultTabController(
                    length: 2,
                    child: Column(children: [
                      if (!keyboardVisible) ...[
                        const SizedBox(height: 16),
                        _mapCard(),
                        _quickSavedRow(),
                      ] else
                        const SizedBox(height: 12),
                      Container(
                        height: 48 +
                            (MediaQuery.textScalerOf(context).scale(1) - 1)
                                    .clamp(0.0, double.infinity) *
                                16,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: HomeStyle.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: HomeStyle.divider),
                        ),
                        child: TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor: HomeStyle.muted,
                          labelStyle: const TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w700),
                          unselectedLabelStyle: const TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w600),
                          indicator: BoxDecoration(
                            color: HomeStyle.orange,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          tabs: const [
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
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('Đang tìm địa chỉ…',
                                style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: HomeStyle.muted,
                                )),
                          ),
                        )
                      else if (_suggestions.isEmpty && _searchError)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 28, color: HomeStyle.muted),
                              const SizedBox(height: 8),
                              const Text(
                                  'Lỗi kết nối, không tải được gợi ý địa chỉ',
                                  style: TextStyle(
                                      fontSize: AppFontSize.body,
                                      color: HomeStyle.muted)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _onChanged(_controller.text),
                                child: const Text('Thử lại'),
                              ),
                            ]),
                          ),
                        )
                      else if (_suggestions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('Không tìm thấy địa chỉ',
                                style: TextStyle(
                                    fontSize: AppFontSize.body,
                                    color: HomeStyle.muted)),
                          ),
                        )
                      else
                        _card(children: [
                          for (int i = 0; i < _suggestions.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1,
                                  indent: 60,
                                  color: HomeStyle.divider),
                            _SuggestionItem(
                              suggestion: _suggestions[i],
                              onTap: () => _selectFromSearch(_suggestions[i]),
                            ),
                          ],
                        ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _searchRegionLabel() {
    final cityName = ref.watch(activeCityProvider).cityName.trim();
    if (cityName.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 16, color: HomeStyle.orange),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Gợi ý trong khu vực $cityName',
              style: const TextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: HomeStyle.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_history.isEmpty) {
      return const _AddressEmptyState(
        icon: Icons.history_rounded,
        title: 'Chưa có lịch sử tìm kiếm',
        subtitle: 'Địa điểm bạn đã chọn sẽ xuất hiện tại đây.',
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
              const Divider(height: 1, indent: 60, color: HomeStyle.divider),
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
            const Divider(height: 1, indent: 60, color: HomeStyle.divider),
            InkWell(
              onTap: () => setState(() => _showAllHistory = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Xem thêm ${_history.length - kInitial} địa chỉ',
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        color: HomeStyle.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _clearAllHistory,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Xóa tất cả lịch sử'),
            style: TextButton.styleFrom(foregroundColor: HomeStyle.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (_savedAddresses.isEmpty) {
      return const _AddressEmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'Chưa có địa chỉ đã lưu',
        subtitle: 'Lưu địa chỉ trong Tài khoản để chọn nhanh hơn.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _card(children: [
          for (int i = 0; i < _savedAddresses.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: HomeStyle.divider),
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
      home ??= (a.label == 'Nhà' || a.label == 'Nhà riêng') ? a : null;
      office ??= (a.label == 'Cơ quan' || a.label == 'Công ty') ? a : null;
    }
    final quick = [if (home != null) home, if (office != null) office];
    if (quick.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Địa điểm quen thuộc',
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.ink,
                )),
          ),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 240;
            final columns = stacked || quick.length == 1 ? 1 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final address in quick)
                  SizedBox(
                    width: width,
                    child: _QuickSavedTile(
                      addr: address,
                      onTap: () => _selectFromSaved(address),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _mapCard() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openMap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              decoration: BoxDecoration(
                color: HomeStyle.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: HomeStyle.divider),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeStyle.peach,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.map_rounded,
                      size: 22, color: HomeStyle.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chọn vị trí trên bản đồ',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.bodyLarge,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.ink)),
                      SizedBox(height: 3),
                      Text('Kéo ghim để xác định vị trí chính xác',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: HomeStyle.muted)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: HomeStyle.peach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: HomeStyle.orange),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _card({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _FlatCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Material(
                color: Colors.transparent, child: Column(children: children)),
          ),
        ),
      );
}

class _AddressEmptyState extends StatelessWidget {
  const _AddressEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HomeStyle.peach,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, size: 30, color: HomeStyle.orange),
            ),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFontSize.bodyLarge,
                fontWeight: FontWeight.w700,
                color: HomeStyle.ink,
              )),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFontSize.body,
                height: 1.4,
                color: HomeStyle.muted,
              )),
        ],
      );
}

// ── Quick saved address tile (Nhà/Công ty) ──────────────────────────────────────

class _QuickSavedTile extends StatelessWidget {
  final AddressModel addr;
  final VoidCallback onTap;
  const _QuickSavedTile({required this.addr, required this.onTap});

  bool get _isHome => addr.label == 'Nhà' || addr.label == 'Nhà riêng';
  Color get _color => _isHome ? HomeStyle.orange : AppColors.info;
  IconData get _icon => _isHome ? Icons.home_rounded : Icons.business_rounded;

  @override
  Widget build(BuildContext context) => Material(
        color: HomeStyle.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: HomeStyle.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _FlatIcon(icon: _icon, color: _color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(addr.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.ink)),
                    const SizedBox(height: 3),
                    Text(addr.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted)),
                  ],
                ),
              ),
            ]),
          ),
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
    if (label == 'nhà' || label == 'nhà riêng') return HomeStyle.orange;
    if (label == 'cơ quan' || label == 'công ty') return AppColors.info;
    return const Color(0xFF8B5CF6);
  }

  IconData get _icon {
    final label = addr.label.toLowerCase();
    if (label == 'nhà' || label == 'nhà riêng') return Icons.home_rounded;
    if (label == 'cơ quan' || label == 'công ty') return Icons.business_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            _FlatIcon(icon: _icon, color: _iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr.label.isNotEmpty ? addr.label : addr.displayTitle,
                      style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: HomeStyle.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      addr.placeName?.isNotEmpty == true
                          ? '${addr.placeName} · ${addr.address}'
                          : addr.address,
                      style: const TextStyle(
                          fontSize: AppFontSize.body, color: HomeStyle.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: HomeStyle.muted),
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
            const _FlatIcon(
                icon: Icons.history_rounded, color: HomeStyle.muted),
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
                                  color: HomeStyle.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(item.address,
                              style: const TextStyle(
                                  fontSize: AppFontSize.body,
                                  color: HomeStyle.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ])
                  : Text(item.address,
                      style: const TextStyle(
                          fontSize: AppFontSize.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: HomeStyle.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_west_rounded,
                size: 14, color: HomeStyle.muted),
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
            const _FlatIcon(
                icon: Icons.location_on_rounded, color: HomeStyle.orange),
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
                        color: HomeStyle.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(suggestion.secondaryText,
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            color: HomeStyle.muted),
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

// ── Flat building blocks ──────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  const _FlatCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeStyle.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: HomeStyle.divider),
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
