import 'package:flutter/widgets.dart';

/// Локализация кастомных экранов Strizh (онбординг/подключение/настройки).
/// Базовые экраны Hiddify локализуются своей системой (slang); здесь — только наши строки.
/// Пока поддержаны RU и EN: русский — если язык приложения русский, иначе английский.
class StrizhL10n {
  const StrizhL10n(this.ru);

  /// true — показывать по-русски.
  final bool ru;

  factory StrizhL10n.of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return StrizhL10n(code == 'ru');
  }

  String get tagline => ru ? 'Интернет без границ' : 'All you need for an open internet';

  // Онбординг
  String get startFree => ru ? 'Начать бесплатно' : 'Start for free';
  String get loginOrRegister => ru ? 'Войти или зарегистрироваться' : 'Log in or sign up';
  String get accountOnSite => ru ? 'Аккаунт и тарифы — на сайте' : 'Account and plans — on the website';
  String get email => 'Email';
  String get emailHint => 'you@example.com';
  String get getCode => ru ? 'Получить код' : 'Get code';
  String get back => ru ? 'Назад' : 'Back';
  String codeSentTo(String to) => ru ? 'Код отправлен на $to' : 'Code sent to $to';
  String get loginAndConnect => ru ? 'Войти и подключиться' : 'Log in and connect';
  String get changeEmail => ru ? 'Изменить email' : 'Change email';

  // Ошибки
  String get errEmail => ru ? 'Введи корректный email' : 'Enter a valid email';
  String get errCode => ru ? 'Введи код из письма' : 'Enter the code from the email';
  String get errNetwork => ru ? 'Ошибка сети. Попробуй ещё раз.' : 'Network error. Try again.';
  String get errApplySub => ru ? 'Не удалось применить подписку. Попробуй ещё раз.' : 'Could not apply the subscription. Try again.';
  String get errNoSub => ru
      ? 'Нет активной подписки. Оформи Premium на strizhvpn.com'
      : 'No active subscription. Get Premium at strizhvpn.com';

  // Экран подключения
  String get connected => ru ? 'Подключено' : 'Connected';
  String get connecting => ru ? 'Подключение…' : 'Connecting…';
  String get connect => ru ? 'Подключить' : 'Connect';
  String get todayLeft => ru ? 'Сегодня осталось' : 'Left today';
  String get freeSpeed => ru ? 'Бесплатно · 2 Мбит/с' : 'Free · 2 Mbps';
  String get goPremium => ru ? 'Перейти на Premium' : 'Go Premium';

  // Модалка Premium
  String get premium => 'Premium';
  String get premiumTitle => ru ? 'Полная скорость, без лимитов' : 'Full speed, no limits';
  String get premiumWorld => ru ? 'Локации по всему миру' : 'Locations worldwide';
  String get choosePlan => ru ? 'Выбрать тариф' : 'Choose a plan';
  String get opensSite => ru ? 'Откроется сайт Strizh' : 'Opens the Strizh website';

  // Настройки
  String get account => ru ? 'Аккаунт' : 'Account';
  String get signIn => ru ? 'Войти' : 'Sign in';
}
