import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/payment_success_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EthioNutriApp());
}

class EthioNutriApp extends StatelessWidget {
  const EthioNutriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'EthioNutri AI',
  debugShowCheckedModeBanner: false,

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

    // ==========================================================
    // CHAPA RETURN URL
    // Example:
    // http://localhost:3000/payment-success?tx_ref=ethionutri-tx-123
    // ==========================================================

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

    // ==========================================================
    // NORMAL APP START
    // ==========================================================

    return MaterialPageRoute(
      builder: (_) => const AppBootstrap(),
      settings: settings,
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
    final token = await ApiClient.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final role = await AuthService.getUserRole();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AuthService.getDashboardForRole(role)),
          );
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
    );
  }
}