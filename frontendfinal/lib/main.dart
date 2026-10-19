import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/payment_success_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/app_localization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Amharic as the default application language.
  await AppLocalization.instance.initialize(
    locale: const Locale('am'),
  );

  runApp(const EthioNutriApp());
}

class EthioNutriApp extends StatelessWidget {
  const EthioNutriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, _) {
        final localization = AppLocalization.instance;

        return MaterialApp(
          title: 'EthioNutri AI',
          debugShowCheckedModeBanner: false,

          // App language.
          locale: localization.locale,

          // Supported languages.
          supportedLocales: const [
            Locale('am'),
            Locale('en'),
          ],

          // Flutter's built-in localization support.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF16A34A),
              primary: const Color(0xFF16A34A),
            ),
            useMaterial3: true,
          ),

          initialRoute: '/',

          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name ?? '/');

            // Handle Chapa payment return URLs.
            // Example: /payment-success?tx_ref=transaction-123
            if (uri.path == '/payment-success') {
              final txRef =
                  uri.queryParameters['tx_ref'] ??
                  uri.queryParameters['trx_ref'];

              return MaterialPageRoute(
                builder: (_) => PaymentSuccessScreen(
                  txRef: txRef,
                ),
                settings: settings,
              );
            }

            // Normal application startup.
            return MaterialPageRoute(
              builder: (_) => const AppBootstrap(),
              settings: settings,
            );
          },
        );
      },
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await ApiClient.getToken();

      if (token != null && token.isNotEmpty) {
        try {
          final role = await AuthService.getUserRole();

          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  AuthService.getDashboardForRole(role),
            ),
          );

          return;
        } catch (error) {
          debugPrint('Authentication check failed: $error');
        }
      }
    } catch (error) {
      debugPrint('Token check failed: $error');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF16A34A),
        ),
      ),
    );
  }
}
