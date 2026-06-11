import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../models/notification_item.dart';

const _kStorageKey = 'notifications_v2';

class NotificationState {
  final List<NotificationItem> items;
  final bool isLoadingMore;
  final bool hasMore;

  const NotificationState({
    this.items        = const [],
    this.isLoadingMore = false,
    this.hasMore      = true,
  });

  NotificationState copyWith({
    List<NotificationItem>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) => NotificationState(
        items:         items         ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore:       hasMore       ?? this.hasMore,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiClient _api;
  StreamSubscription? _rtdbSub;
  int _page = 1;

  NotificationNotifier(this._api) : super(const NotificationState()) {
    _loadLocal();
  }

  void subscribeRTDB(int userId) {
    _rtdbSub?.cancel();
    _rtdbSub = FirebaseDatabase.instance
        .ref('customer_notifications/$userId')
        .onValue
        .listen((_) => fetchFromServer());
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    super.dispose();
  }

  // ── Local cache ───────────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kStorageKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(items: list);
      }
    } catch (_) {}
    await fetchFromServer();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kStorageKey,
          jsonEncode(state.items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  // ── Server fetch (page 1 — refresh) ──────────────────────────────────────────

  Future<void> fetchFromServer() async {
    _page = 1;
    try {
      final res     = await _api.get('/customer/notifications', params: {'page': 1});
      final data    = res.data['data'] as List? ?? [];
      final hasMore = res.data['has_more'] as bool? ?? false;
      final items   = data
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(items: items, hasMore: hasMore, isLoadingMore: false);
      await _persist();
    } catch (_) {}
  }

  // ── Load more (trang tiếp) ────────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      _page++;
      final res     = await _api.get('/customer/notifications', params: {'page': _page});
      final data    = res.data['data'] as List? ?? [];
      final hasMore = res.data['has_more'] as bool? ?? false;
      final newItems = data
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final existing = state.items.map((e) => e.id).toSet();
      final merged   = [...state.items, ...newItems.where((e) => !existing.contains(e.id))];
      state = state.copyWith(items: merged, hasMore: hasMore, isLoadingMore: false);
      await _persist();
    } catch (_) {
      _page--;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ── Add (local — from FCM) ────────────────────────────────────────────────────

  void add(NotificationItem item) {
    final exists = state.items.any((n) =>
        n.orderCode == item.orderCode &&
        n.title == item.title &&
        n.createdAt.difference(item.createdAt).inMinutes.abs() < 5);
    if (exists) return;
    state = state.copyWith(items: [item, ...state.items]);
    _persist();
  }

  // ── Mark read ─────────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    state = state.copyWith(
        items: state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList());
    _persist();
    try { await _api.patch('/customer/notifications/$id/read', data: {}); } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList());
    _persist();
    try { await _api.post('/customer/notifications/mark-all-read', data: {}); } catch (_) {}
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    state = state.copyWith(items: state.items.where((n) => n.id != id).toList());
    _persist();
    try { await _api.delete('/customer/notifications/$id'); } catch (_) {}
  }

  int get unreadCount => state.items.where((n) => !n.isRead).length;
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(ref.read(apiClientProvider)),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).items.where((n) => !n.isRead).length;
});
