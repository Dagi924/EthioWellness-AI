
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalization extends ChangeNotifier {
  AppLocalization._();

  static final AppLocalization instance = AppLocalization._();

  Locale _locale = const Locale('en');

  Map<String, dynamic> _translations = {};
  Map<String, dynamic> _fallbackTranslations = {};

  bool _isInitialized = false;
  bool _isLoading = false;

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isAmharic => _locale.languageCode == 'am';

  bool get isEnglish => _locale.languageCode == 'en';

  bool get isInitialized => _isInitialized;

  bool get isLoading => _isLoading;

  /// Initialize the localization system using English by default.
  Future<void> initialize({
    Locale locale = const Locale('en'),
  }) async {
    await load(locale);
  }

  /// Load the requested language and English fallback translations.
  Future<void> load(Locale locale) async {
    final languageCode =
        locale.languageCode == 'am' ? 'am' : 'en';

    _isLoading = true;
    notifyListeners();

    try {
      final englishJson = await rootBundle.loadString(
        'assets/translations/en.json',
      );

      final englishData =
          json.decode(englishJson) as Map<String, dynamic>;

      Map<String, dynamic> selectedTranslations;

      if (languageCode == 'en') {
        selectedTranslations = englishData;
      } else {
        final selectedJson = await rootBundle.loadString(
          'assets/translations/am.json',
        );

        selectedTranslations =
            json.decode(selectedJson) as Map<String, dynamic>;
      }

      _fallbackTranslations = englishData;
      _translations = selectedTranslations;
      _locale = Locale(languageCode);
      _isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('Localization loading failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      // Keep the current translations if loading a new language fails.
      if (!_isInitialized) {
        _translations = {};
        _fallbackTranslations = {};
      }

      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Translate a key, optionally replacing placeholders.
  ///
  /// Example:
  /// tr('welcome_user', params: {'name': 'Dagi'})
  /// Translation: "Welcome, {name}"
  String tr(
    String key, {
    Map<String, String> params = const {},
  }) {
    String value =
        _translations[key]?.toString() ??
        _fallbackTranslations[key]?.toString() ??
        key;

    params.forEach((placeholder, replacement) {
      value = value.replaceAll(
        '{$placeholder}',
        replacement,
      );
    });

    return value;
  }

  /// Switch between English and Amharic.
  Future<void> toggleLanguage() async {
    final nextLocale = isEnglish
        ? const Locale('am')
        : const Locale('en');

    await load(nextLocale);
  }

  /// Explicitly select a language.
  Future<void> setLanguage(String languageCode) async {
    final nextLocale = languageCode == 'am'
        ? const Locale('am')
        : const Locale('en');

    if (_locale.languageCode == nextLocale.languageCode &&
        _isInitialized) {
      return;
    }

    await load(nextLocale);
  }
}