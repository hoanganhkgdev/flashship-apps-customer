import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        token: clearUser ? null : (token ?? this.token),
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final userData = prefs.getString(AppConstants.userKey);
    if (token != null && userData != null) {
      final user = UserModel.fromJson(jsonDecode(userData));
      state = state.copyWith(token: token, user: user, isInitialized: true);
    } else {
      state = state.copyWith(isInitialized: true);
    }
  }

  // Xác minh số điện thoại bằng Firebase Phone Auth (SMS do Firebase gửi).
  String? _verificationId;
  int? _resendToken;

  String _e164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84')) return '+$digits';
    return '+84${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  /// Gửi (hoặc gửi lại) mã SMS qua Firebase. Dùng cho đăng ký và quên mật khẩu.
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final completer = Completer<bool>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164(phone),
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        // Không tự đăng nhập khi Android đọc được SMS — luôn để khách nhập mã
        // rồi lấy ID token ở confirmCode().
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint('[PhoneAuth] ${e.code}: ${e.message}');
          if (!completer.isCompleted) {
            state =
                state.copyWith(isLoading: false, error: _firebaseError(e.code));
            completer.complete(false);
          }
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!completer.isCompleted) {
            state = state.copyWith(isLoading: false);
            completer.complete(true);
          }
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      if (!completer.isCompleted) {
        state = state.copyWith(isLoading: false, error: _parseError(e));
        completer.complete(false);
      }
    }
    return completer.future;
  }

  /// Kiểm tra mã SMS với Firebase, trả ID token để gửi lên backend (null nếu sai mã).
  Future<String?> confirmCode(String code) async {
    final id = _verificationId;
    if (id == null) {
      state = state.copyWith(error: 'Vui lòng gửi lại mã xác minh');
      return null;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
      final token = await cred.user?.getIdToken();
      // Firebase chỉ dùng để xác minh số; phiên đăng nhập thật do backend cấp.
      await FirebaseAuth.instance.signOut();
      state = state.copyWith(isLoading: false);
      return token;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _firebaseError(e.code));
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return null;
    }
  }

  String _firebaseError(String code) => switch (code) {
        'invalid-verification-code' => 'Mã OTP không đúng',
        'session-expired' => 'Mã OTP đã hết hạn, vui lòng gửi lại',
        'too-many-requests' => 'Bạn thử quá nhiều lần, vui lòng thử lại sau',
        'invalid-phone-number' => 'Số điện thoại không hợp lệ',
        'network-request-failed' => 'Lỗi mạng, vui lòng thử lại',
        _ => 'Không gửi được mã xác minh ($code), vui lòng thử lại',
      };

  Future<bool> verifyOtpAndRegister({
    required String phone,
    required String idToken,
    required String name,
    required String password,
    int? cityId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/customer/auth/verify-otp-register', data: {
        'phone': phone,
        'id_token': idToken,
        'name': name,
        'password': password,
        if (cityId != null) 'city_id': cityId,
      });
      await _saveSession(res.data);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    int? cityId,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/customer/auth/register', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        if (cityId != null) 'city_id': cityId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      await _saveSession(res.data);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> resetPassword({
    required String phone,
    required String idToken,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/customer/auth/reset-password', data: {
        'phone': phone,
        'id_token': idToken,
        'password': password,
        'password_confirmation': password,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> login({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/customer/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      await _saveSession(res.data);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<String?> updateProfile({
    required String name,
    String? email,
    DateTime? birthDate,
    int? cityId,
    String? cityName,
  }) async {
    try {
      final res = await _api.patch('/customer/auth/profile', data: {
        'name': name,
        if (email != null) 'email': email.isEmpty ? null : email,
        if (birthDate != null)
          'birth_date': '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
        if (cityId != null) 'city_id': cityId,
      });
      final user = UserModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final res = await _api.post('/customer/auth/avatar', data: formData);
      final user = UserModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<String?> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      await _api.patch('/customer/auth/password', data: {
        'current_password': current,
        'new_password': next,
        'new_password_confirmation': next,
      });
      return null;
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<void> refreshUser() async {
    if (state.token == null) return;
    try {
      final res = await _api.get('/customer/auth/profile');
      final user = UserModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isInitialized: true);
    } catch (e) {
      final statusCode = (e as dynamic).response?.statusCode as int?;
      if (statusCode == 401 || statusCode == 403) {
        // Token expired — clear session, router will redirect to login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.tokenKey);
        await prefs.remove(AppConstants.userKey);
        state = state.copyWith(clearUser: true, isInitialized: true);
      } else {
        // Network error or server error — keep cached credentials, let app proceed
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/customer/auth/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    state = state.copyWith(clearUser: true, isInitialized: true);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final payload = data['data'] as Map<String, dynamic>;
    final token = payload['token'] as String;
    final user = UserModel.fromJson(payload['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    state = state.copyWith(
        token: token, user: user, isLoading: false, isInitialized: true);
    _registerFcmToken(token);
  }

  Future<void> _registerFcmToken(String authToken) async {
    try {
      final fcmToken = await NotificationService.getToken();
      if (fcmToken == null) return;
      await _api
          .post('/customer/auth/fcm-token', data: {'fcm_token': fcmToken});
    } catch (_) {}
  }

  String _parseError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map) {
          final msg = data['message'];
          if (msg != null) return msg.toString();
          final errors = data['errors'];
          if (errors is Map) return errors.values.first.first.toString();
        }
        return 'Server lỗi ${response.statusCode}';
      }
      final type = (e as dynamic).type?.toString() ?? '';
      final message = e.toString();
      if (type.contains('connectionTimeout') ||
          type.contains('receiveTimeout')) {
        return 'Timeout: server không phản hồi';
      }
      if (type.contains('connectionError') ||
          message.contains('SocketException')) {
        return 'Không kết nối được server';
      }
      return 'Lỗi: $message';
    } catch (_) {
      return 'Lỗi: $e';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
