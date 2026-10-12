import 'package:flutter/material.dart';
import '../services/app_localization.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.instance;

    return AnimatedBuilder(
      animation: localization,
      builder: (context, child) {
        final isAmharic =
            localization.locale.languageCode == 'am';

        return TextButton.icon(
          onPressed: () async {
            await localization.toggleLanguage();
          },
          icon: const Icon(
            Icons.language,
            size: 18,
          ),
          label: Text(
            isAmharic ? 'አማርኛ' : 'English',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF542E13),
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
            ),
            minimumSize: const Size(0, 40),
          ),
        );
      },
    );
  }
}
