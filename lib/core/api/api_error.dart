/// Trích message lỗi từ response của Dio (dạng `{"message": "..."}`),
/// trả về [fallback] nếu không có hoặc response không đúng dạng mong đợi.
String apiErrorMessage(Object error, String fallback) {
  try {
    return (error as dynamic).response?.data['message'] ?? fallback;
  } catch (_) {
    return fallback;
  }
}
