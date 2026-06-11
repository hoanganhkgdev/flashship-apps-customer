import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_model.dart';

class OrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const OrderListState({
    this.orders      = const [],
    this.isLoading   = true,
    this.isLoadingMore = false,
    this.hasMore     = false,
    this.error,
  });

  OrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) => OrderListState(
    orders:        orders        ?? this.orders,
    isLoading:     isLoading     ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore:       hasMore       ?? this.hasMore,
    error:         error,
  );
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final ApiClient _api;
  final Ref _ref;
  int _page = 1;

  OrderListNotifier(this._api, this._ref) : super(const OrderListState()) {
    fetch();
  }

  Future<void> fetch() async {
    _page = 1;
    // Giữ orders cũ khi loading để tránh flicker
    state = state.copyWith(isLoading: true);
    try {
      final res  = await _api.get('/customer/orders', params: {'page': 1});
      final data = res.data['data'] as List? ?? [];
      final meta = res.data['meta'] as Map? ?? {};
      state = OrderListState(
        orders:    data.map((e) => OrderModel.fromJson(e)).toList(),
        isLoading: false,
        hasMore:   meta['has_more'] == true,
      );
    } catch (e) {
      final statusCode = (e as dynamic).response?.statusCode as int?;
      if (statusCode == 401) {
        await _ref.read(authProvider.notifier).logout();
        return;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      _page++;
      final res  = await _api.get('/customer/orders', params: {'page': _page});
      final data = res.data['data'] as List? ?? [];
      final meta = res.data['meta'] as Map? ?? {};
      state = state.copyWith(
        orders:        [...state.orders, ...data.map((e) => OrderModel.fromJson(e))],
        isLoadingMore: false,
        hasMore:       meta['has_more'] == true,
      );
    } catch (_) {
      _page--;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final orderListProvider =
    StateNotifierProvider<OrderListNotifier, OrderListState>(
        (ref) => OrderListNotifier(ref.read(apiClientProvider), ref));
