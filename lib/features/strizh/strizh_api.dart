import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Клиент бэкенда Strizh (api.strizhvpn.com).
///
/// Поток «вошёл — подключился»:
///  - free: hwid -> POST /free/connect -> sub_id
///  - premium: email -> /auth/request-code -> код -> /auth/verify -> JWT ->
///             GET /subscriptions/config -> sub_id
/// Дальше приложение подставляет подписку [subUrl]`(sub_id)` как активный профиль;
/// движок Hiddify сам коннектит, рисует трафик и авто-обновляет. JWT после этого не нужен.
class StrizhApi {
  static const String base = 'https://api.strizhvpn.com';

  static String subUrl(String subId) => '$base/sub/$subId';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  /// Стабильный идентификатор устройства для free-учёта (генерим один раз, храним локально).
  Future<String> hwid() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('strizh_hwid');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('strizh_hwid', id);
    }
    return id;
  }

  /// Free: по hwid получаем sub_id бесплатной подписки (30 мин/день).
  Future<String> freeConnect() async {
    final hw = await hwid();
    final r = await _dio.post(
      '/free/connect',
      data: {'hwid': hw, 'os': 'android', 'model': 'strizh'},
    );
    final data = r.data;
    if (r.statusCode == 200 && data is Map && data['sub_id'] != null) {
      return data['sub_id'] as String;
    }
    if (r.statusCode == 403) {
      throw StrizhException('Дневной бесплатный лимит исчерпан. Перейди на Premium.');
    }
    throw StrizhException(_msg(r, 'Не удалось получить бесплатный доступ'));
  }

  /// Premium шаг 1: отправить код на email.
  Future<void> requestCode(String email) async {
    final r = await _dio.post('/auth/request-code', data: {'email': email});
    if (r.statusCode == 200) return;
    throw StrizhException(_msg(r, 'Не удалось отправить код'));
  }

  /// Premium шаг 2: подтвердить код -> JWT.
  Future<String> verify(String email, String code) async {
    final r = await _dio.post('/auth/verify', data: {'email': email, 'code': code});
    final data = r.data;
    if (r.statusCode == 200 && data is Map && data['access_token'] != null) {
      return data['access_token'] as String;
    }
    throw StrizhException(_msg(r, 'Неверный или просроченный код'));
  }

  /// Premium шаг 3: по JWT получить sub_id активной подписки (null = подписки нет).
  Future<String?> premiumSubId(String jwt) async {
    final r = await _dio.get(
      '/subscriptions/config',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
    final data = r.data;
    if (r.statusCode == 200 && data is Map && data['sub_id'] != null) {
      return data['sub_id'] as String;
    }
    if (r.statusCode == 404) return null; // активной подписки нет — надо купить
    throw StrizhException(_msg(r, 'Не удалось получить конфигурацию'));
  }

  String _msg(Response r, String fallback) {
    try {
      final d = r.data;
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return fallback;
  }
}

class StrizhException implements Exception {
  StrizhException(this.message);
  final String message;
  @override
  String toString() => message;
}
