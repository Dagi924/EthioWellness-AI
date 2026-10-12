
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';

import 'main_shell_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String _t(String key) => AppLocalization.instance.tr(key);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.login(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      if (response['accessToken'] != null && mounted) {
        final role = response['user']?['role'] ?? 'user';
        final targetDashboard = AuthService.getDashboardForRole(role);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => targetDashboard,
          ),
          (route) => false,
        );
      } else {
        throw Exception(
          response['error'] ?? _t('authentication_failed'),
        );
      }
    } on SocketException {
      if (!mounted) return;

      setState(() {
        _errorMessage = _t('server_connection_error');
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) {
        return _buildLoginPage();
      },
    );
  }

  Widget _buildLoginPage() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F2EA),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8D4F28),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _t('app_name'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF542E13),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const LanguageToggleButton(),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 440,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF542E13)
                                    .withOpacity(0.08),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 28,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF542E13),
                                      Color(0xFF8D4F28),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(36),
                                    bottomRight: Radius.circular(36),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _t('hello_friend'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _t('login_welcome_message'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.9),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 28,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _t('sign_in'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF542E13),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _t('sign_in_subtitle'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF78716C),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      if (_errorMessage != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(
                                            bottom: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFFECACA),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                color: Color(0xFFDC2626),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: const TextStyle(
                                                    color: Color(0xFFDC2626),
                                                    fontSize: 12.5,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          color: Color(0xFF1C1917),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return _t('enter_email');
                                          }

                                          if (!RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                          ).hasMatch(value.trim())) {
                                            return _t('valid_email');
                                          }

                                          return null;
                                        },
                                        decoration: _inputDecoration(
                                          hint: _t('email_address'),
                                          icon: Icons.email_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) =>
                                            _handleLogin(),
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          color: Color(0xFF1C1917),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.isEmpty) {
                                            return _t('enter_password');
                                          }

                                          if (value.length < 6) {
                                            return _t('password_min_length');
                                          }

                                          return null;
                                        },
                                        decoration: _inputDecoration(
                                          hint: _t('password'),
                                          icon: Icons.lock_outline,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: const Color(0xFFA8A29E),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      Align(
                                        alignment: Alignment.center,
                                        child: TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _t('password_reset_message'),
                                                ),
                                                backgroundColor:
                                                    const Color(0xFF542E13),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            _t('forgot_password'),
                                            style: const TextStyle(
                                              color: Color(0xFF1C1917),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF542E13),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              const Color(0xFFA8826B),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.2,
                                                ),
                                              )
                                            : Text(
                                                _t('sign_in').toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 18),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _t('no_account'),
                                              style: const TextStyle(
                                                color: Color(0xFF78716C),
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignupScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              _t('sign_up'),
                                              style: const TextStyle(
                                                color: Color(0xFF542E13),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFA8A29E),
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F3EC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFFA8A29E),
        size: 19,
      ),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFEADBCE),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFEADBCE),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF542E13),
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1,
        ),
      ),
    );
  }
}
