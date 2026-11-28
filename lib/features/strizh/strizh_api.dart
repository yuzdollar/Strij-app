import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Клиент бэкенда Strizh.
///
/// Поток «вошёл — подключился»:
///  - free: hwid -> POST /free/connect -> sub_id
///  - premium: email -> /auth/request-code -> код -> /auth/verify -> JWT ->
///             GET /subscriptions/config -> sub_id
/// Дальше приложение подставляет подписку [subUrl]`(sub_id)` как активный профиль;
/// движок Hiddify сам коннектит, рисует трафик и авто-обновляет. JWT после этого не нужен.
///
/// TM-доступность: `api.strizhvpn.com` режется из Туркменистана. Поэтому есть зеркало
/// `sapi.melangewood.com` (nginx на TM-достижимом edge → тот же backend). Запросы идут по
/// [_bases] по очереди: при сетевой ошибке на основном — повтор на зеркале. [subUrl] (ссылку
/// отдаём ядру Hiddify) строим на том хосте, который реально ответил ([_working]).
class StrizhApi {
  static const String _primary = 'https://api.strizhvpn.com';
  static const String _mirror = 'https://sapi.melangewood.com';

  /// Порядок баз: в TM (часовой пояс UTC+5) сначала зеркало, иначе — основной.
  static List<String> get _bases =>
      DateTime.now().timeZoneOffset.inHours == 5 ? [_mirror, _primary] : [_primary, _mirror];

  /// Хост, который последним ответил успешно — его же используем для ссылки-подписки.
  static String _working = _bases.first;

  static String subUrl(String subId) => '$_working/sub/$subId';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  /// Пробует базы по очереди (сначала [_working]); на СЕТЕВОЙ ошибке переходит к следующей.
  /// Ответ сервера (в т.ч. 4xx) считается успехом соединения и возвращается сразу.
  Future<Response> _send(String method, String path, {Object? data, Options? options}) async {
    final order = <String>[_working, ..._bases.where((b) => b != _working)];
    DioException? last;
    for (final b in order) {
      try {
        final r = await _dio.request(
          '$b$path',
          data: data,
          options: (options ?? Options()).copyWith(method: method),
        );
        _working = b;
        return r;
      } on DioException catch (e) {
        const net = {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.unknown,
        };
        if (net.contains(e.type)) {
          last = e;
          continue; // основной не ответил — пробуем зеркало
        }
        rethrow;
      }
    }
    throw last ?? StrizhException('Ошибка сети');
  }

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
    final r = await _send('POST', '/free/connect', data: {'hwid': hw, 'os': 'android', 'model': 'strizh'});
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
    final r = await _send('POST', '/auth/request-code', data: {'email': email});
    if (r.statusCode == 200) return;
    throw StrizhException(_msg(r, 'Не удалось отправить код'));
  }

  /// Premium шаг 2: подтвердить код -> JWT.
  Future<String> verify(String email, String code) async {
    final r = await _send('POST', '/auth/verify', data: {'email': email, 'code': code});
    final data = r.data;
    if (r.statusCode == 200 && data is Map && data['access_token'] != null) {
      return data['access_token'] as String;
    }
    throw StrizhException(_msg(r, 'Неверный или просроченный код'));
  }

  /// Premium шаг 3: по JWT получить sub_id активной подписки (null = подписки нет).
  Future<String?> premiumSubId(String jwt) async {
    final r = await _send('GET', '/subscriptions/config', options: Options(headers: {'Authorization': 'Bearer $jwt'}));
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
