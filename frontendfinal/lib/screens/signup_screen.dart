import 'dart:io';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';
import 'plan_selection_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  AppLocalization get _loc => AppLocalization.instance;

  String _tr(
    String key, {
    Map<String, String> params = const {},
  }) {
    return _loc.tr(key, params: params);
  }

  // Step 1: Account credentials
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Step 2: Physical metrics
  final _ageCtrl = TextEditingController(text: '26');
  final _heightCtrl = TextEditingController(text: '172');
  final _weightCtrl = TextEditingController(text: '68');
  final _targetWeightCtrl = TextEditingController(text: '65');
  String _gender = 'male';

  // Step 3: Fasting practice and language
  String _fastingPractice = 'orthodox';
  String _language = 'en';

  // Step 4: Dietary goals and health conditions
  String _goal = 'maintain_weight';
  String _budgetLevel = 'medium';
  final List<String> _selectedHealthConditions = [];

  // Step 5: Daily macro targets
  final _calorieCtrl = TextEditingController(text: '2000');
  final _proteinCtrl = TextEditingController(text: '65');
  final _carbsCtrl = TextEditingController(text: '230');
  final _fatsCtrl = TextEditingController(text: '50');
  final _waterCtrl = TextEditingController(text: '2.5');

  @override
  void initState() {
    super.initState();
    _loc.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loc.removeListener(_onLanguageChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatsCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  void _recalculateMacroTargets() {
    final weight = double.tryParse(_weightCtrl.text) ?? 68.0;

    int cal = 2000;
    int protein = 60;
    int carbs = 220;
    int fats = 50;

    if (_goal == 'lose_weight') {
      cal = 1750;
      protein = (weight * 1.4).toInt();
      carbs = 180;
      fats = 45;
    } else if (_goal == 'gain_muscle') {
      cal = 2350;
      protein = (weight * 1.8).toInt();
      carbs = 270;
      fats = 60;
    } else if (_goal == 'iron_boost') {
      cal = 2100;
      protein = (weight * 1.3).toInt();
      carbs = 240;
      fats = 50;
    }

    setState(() {
      _calorieCtrl.text = cal.toString();
      _proteinCtrl.text = protein.toString();
      _carbsCtrl.text = carbs.toString();
      _fatsCtrl.text = fats.toString();
    });
  }

  bool _validateCurrentStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = _tr('signup_error_full_name'));
        return false;
      }

      if (_emailCtrl.text.trim().isEmpty ||
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(_emailCtrl.text.trim())) {
        setState(() => _errorMessage = _tr('signup_error_email'));
        return false;
      }

      if (_passwordCtrl.text.length < 6) {
        setState(() => _errorMessage = _tr('signup_error_password_length'));
        return false;
      }
    } else if (_currentStep == 1) {
      final age = int.tryParse(_ageCtrl.text);
      final height = double.tryParse(_heightCtrl.text);
      final weight = double.tryParse(_weightCtrl.text);

      if (age == null || age < 10) {
        setState(() => _errorMessage = _tr('signup_error_age'));
        return false;
      }

      if (height == null || weight == null || height <= 0 || weight <= 0) {
        setState(() => _errorMessage = _tr('signup_error_height_weight'));
        return false;
      }

      _recalculateMacroTargets();
    }

    return true;
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.signup(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
        fastingPractice: _fastingPractice,
        healthConditions: _selectedHealthConditions,
        language: _language,
        theme: 'light',
        notificationsEnabled: true,
        age: int.tryParse(_ageCtrl.text) ?? 26,
        gender: _gender,
        weightKg: double.tryParse(_weightCtrl.text) ?? 68.0,
        targetWeightKg: double.tryParse(_targetWeightCtrl.text) ?? 65.0,
        heightCm: double.tryParse(_heightCtrl.text) ?? 172.0,
        goal: _goal,
        budgetLevel: _budgetLevel,
        dailyCalorieTarget: int.tryParse(_calorieCtrl.text) ?? 2000,
        dailyProteinTarget: int.tryParse(_proteinCtrl.text) ?? 65,
        dailyCarbsTarget: int.tryParse(_carbsCtrl.text) ?? 230,
        dailyFatsTarget: int.tryParse(_fatsCtrl.text) ?? 50,
        dailyWaterTarget: double.tryParse(_waterCtrl.text) ?? 2.5,
      );

      if (res['accessToken'] != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PlanSelectionScreen(
              userName: _nameCtrl.text.trim(),
              userPhone: _phoneCtrl.text.trim(),
            ),
          ),
          (route) => false,
        );
      } else {
        throw Exception(
          res['error'] ?? _tr('signup_error_registration_failed'),
        );
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _errorMessage = _tr('signup_error_network');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  vertical: 14,
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
                              _tr('app_name'),
                              maxLines: 1,
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
                      vertical: 10,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF542E13).withOpacity(0.08),
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
                              vertical: 24,
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
                                bottomLeft: Radius.circular(32),
                                bottomRight: Radius.circular(32),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _tr('signup_create_account'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _tr(
                                    'signup_step_progress',
                                    params: {
                                      'step': '${_currentStep + 1}',
                                      'total': '5',
                                    },
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 24,
                            ),
                            child: _buildFormWizard(),
                          ),
                        ],
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

  Widget _buildFormWizard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr('signup_create_account'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF542E13),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tr('signup_register_email'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF78716C),
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: List.generate(5, (index) {
            final isDone = index < _currentStep;
            final isCurrent = index == _currentStep;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDone || isCurrent
                      ? const Color(0xFF542E13)
                      : const Color(0xFFE5DFD7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),

        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
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
                    ),
                  ),
                ),
              ],
            ),
          ),

        _buildStepContent(),
        const SizedBox(height: 22),

        Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF542E13)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _tr('back'),
                    style: const TextStyle(
                      color: Color(0xFF542E13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_validateCurrentStep()) {
                          if (_currentStep < 4) {
                            setState(() => _currentStep++);
                          } else {
                            _submitRegistration();
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF542E13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentStep == 4
                            ? _tr('signup_submit')
                            : _tr('next_step'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _tr('signup_already_account'),
                style: const TextStyle(
                  color: Color(0xFF78716C),
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
              child: Text(
                _tr('sign_in'),
                style: const TextStyle(
                  color: Color(0xFF542E13),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _step1Account();
      case 1:
        return _step2PhysicalMetrics();
      case 2:
        return _step3FastingAndCulture();
      case 3:
        return _step4HealthAndGoals();
      case 4:
        return _step5MacroTargets();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _step1Account() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          controller: _nameCtrl,
          label: _tr('signup_full_name'),
          icon: Icons.person_outline,
          hint: _tr('signup_name_hint'),
        ),
        const SizedBox(height: 12),
        _textField(
          controller: _emailCtrl,
          label: _tr('signup_email'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          hint: 'name@example.com',
        ),
        const SizedBox(height: 12),
        _textField(
          controller: _phoneCtrl,
          label: _tr('signup_phone'),
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          hint: '+251911223344',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF1C1917),
          ),
          decoration: InputDecoration(
            labelText: _tr('signup_password'),
            hintText: _tr('signup_password_hint'),
            hintStyle: const TextStyle(
              color: Color(0xFFA8A29E),
              fontSize: 13.5,
            ),
            labelStyle: const TextStyle(
              color: Color(0xFF78716C),
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFFA8A29E),
              size: 19,
            ),
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? _tr('show_password')
                  : _tr('hide_password'),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFFA8A29E),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            filled: true,
            fillColor: const Color(0xFFF8F3EC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEADBCE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEADBCE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF542E13),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _step2PhysicalMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _ageCtrl,
                label: _tr('age'),
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: _dropdownDecoration(_tr('gender')),
                items: [
                  DropdownMenuItem(
                    value: 'male',
                    child: Text(_tr('gender_male')),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Text(_tr('gender_female')),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(_tr('gender_other')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _gender = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField(
          controller: _heightCtrl,
          label: _tr('height_cm'),
          icon: Icons.height,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _weightCtrl,
                label: _tr('weight_kg'),
                icon: Icons.monitor_weight_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _textField(
                controller: _targetWeightCtrl,
                label: _tr('signup_target_weight'),
                icon: Icons.flag_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _step3FastingAndCulture() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_tr('fasting_tradition')),
        const SizedBox(height: 8),
        _radioOption(
          'orthodox',
          _tr('signup_orthodox_title'),
          _tr('signup_orthodox_description'),
          Icons.church_outlined,
        ),
        _radioOption(
          'ramadan',
          _tr('signup_ramadan_title'),
          _tr('signup_ramadan_description'),
          Icons.nightlight_round,
        ),
        _radioOption(
          'intermittent',
          _tr('signup_intermittent_title'),
          _tr('signup_intermittent_description'),
          Icons.timer_outlined,
        ),
        _radioOption(
          'none',
          _tr('signup_no_fasting_title'),
          _tr('signup_no_fasting_description'),
          Icons.restaurant,
        ),
        const SizedBox(height: 12),
        _sectionTitle(_tr('signup_preferred_language')),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _language,
          decoration: _dropdownDecoration(_tr('signup_preferred_language')),
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text(_tr('language_english')),
            ),
            DropdownMenuItem(
              value: 'am',
              child: Text(_tr('language_amharic')),
            ),
            DropdownMenuItem(
              value: 'om',
              child: Text(_tr('language_oromo')),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _language = v);
          },
        ),
      ],
    );
  }

  Widget _step4HealthAndGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_tr('signup_primary_goal')),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _goal,
          decoration: _dropdownDecoration(_tr('signup_primary_goal')),
          items: [
            DropdownMenuItem(
              value: 'maintain_weight',
              child: Text(_tr('maintain_weight_wellness')),
            ),
            DropdownMenuItem(
              value: 'lose_weight',
              child: Text(_tr('weight_loss_caloric_deficit')),
            ),
            DropdownMenuItem(
              value: 'gain_muscle',
              child: Text(_tr('muscle_gain_high_protein')),
            ),
            DropdownMenuItem(
              value: 'iron_boost',
              child: Text(_tr('combat_anemia_high_red_teff')),
            ),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _goal = v);
              _recalculateMacroTargets();
            }
          },
        ),
        const SizedBox(height: 14),
        _sectionTitle(_tr('signup_health_conditions_optional')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _conditionChip('anemia', _tr('health_anemia')),
            _conditionChip('diabetes', _tr('health_diabetes')),
            _conditionChip('hypertension', _tr('health_hypertension')),
            _conditionChip(
              'lactose_intolerance',
              _tr('health_lactose_intolerance'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle(_tr('signup_weekly_budget')),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _budgetLevel,
          decoration: _dropdownDecoration(_tr('signup_weekly_budget')),
          items: [
            DropdownMenuItem(
              value: 'low',
              child: Text(_tr('signup_budget_low')),
            ),
            DropdownMenuItem(
              value: 'medium',
              child: Text(_tr('signup_budget_medium')),
            ),
            DropdownMenuItem(
              value: 'high',
              child: Text(_tr('signup_budget_high')),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _budgetLevel = v);
          },
        ),
      ],
    );
  }

  Widget _step5MacroTargets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EBE1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEADBCE)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt,
                color: Color(0xFF8D4F28),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        'signup_calories_per_day',
                        params: {'calories': _calorieCtrl.text},
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF542E13),
                      ),
                    ),
                    Text(
                      _tr(
                        'signup_daily_target_for',
                        params: {'goal': _tr(_goalTranslationKey())},
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8D4F28),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _proteinCtrl,
                label: _tr('signup_protein_g'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _textField(
                controller: _carbsCtrl,
                label: _tr('signup_carbs_g'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _textField(
                controller: _fatsCtrl,
                label: _tr('signup_fats_g'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField(
          controller: _waterCtrl,
          label: _tr('signup_daily_water_liters'),
          icon: Icons.water_drop_outlined,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
      ],
    );
  }

  String _goalTranslationKey() {
    switch (_goal) {
      case 'lose_weight':
        return 'goal_lose_weight';
      case 'gain_muscle':
        return 'goal_gain_muscle';
      case 'iron_boost':
        return 'goal_iron_boost';
      default:
        return 'goal_maintain_weight';
    }
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF78716C),
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F3EC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEADBCE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEADBCE)),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Color(0xFF542E13),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1C1917),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF78716C),
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFA8A29E),
          fontSize: 13,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: const Color(0xFFA8A29E),
                size: 19,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F3EC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEADBCE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEADBCE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF542E13),
            width: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _radioOption(
    String val,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _fastingPractice == val;

    return GestureDetector(
      onTap: () => setState(() => _fastingPractice = val),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5EBE1)
              : const Color(0xFFF8F3EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF542E13)
                : const Color(0xFFEADBCE),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF542E13)
                  : const Color(0xFF78716C),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected
                          ? const Color(0xFF542E13)
                          : const Color(0xFF1C1917),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionChip(String id, String label) {
    final isSelected = _selectedHealthConditions.contains(id);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected
              ? const Color(0xFF542E13)
              : const Color(0xFF1C1917),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFF5EBE1),
      checkmarkColor: const Color(0xFF542E13),
      backgroundColor: const Color(0xFFF8F3EC),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF542E13)
            : const Color(0xFFEADBCE),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedHealthConditions.add(id);
          } else {
            _selectedHealthConditions.remove(id);
          }
        });
      },
    );
  }
}
