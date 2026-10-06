import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'user_appointments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;

  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _gender = 'male';
  String _activityLevel = 'moderate';
  String _goal = 'maintain_weight';
  String _fastingPractice = 'orthodox';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final res = await AuthService.getProfile();
      final profile = res['profile'] ?? {};

      setState(() {
        _profileData = res;
        _ageCtrl.text = (profile['age'] ?? 28).toString();
        _weightCtrl.text =
            (profile['weightKg'] ?? profile['weight_kg'] ?? 70).toString();
        _heightCtrl.text =
            (profile['heightCm'] ?? profile['height_cm'] ?? 175).toString();
        _gender = profile['gender'] ?? 'male';
        _activityLevel =
            profile['activityLevel'] ?? profile['activity_level'] ?? 'moderate';
        _goal = profile['goal'] ?? 'maintain_weight';
        _fastingPractice =
            profile['fastingPractice'] ??
            profile['fasting_practice'] ??
            'orthodox';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await AuthService.updateProfile(
        age: int.tryParse(_ageCtrl.text) ?? 28,
        gender: _gender,
        weightKg: double.tryParse(_weightCtrl.text) ?? 70.0,
        heightCm: double.tryParse(_heightCtrl.text) ?? 175.0,
        activityLevel: _activityLevel,
        goal: _goal,
        fastingPractice: _fastingPractice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF542E13),
            content: Text(
              'Profile updated & targets calibrated successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Save error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ============================================================
  // OPEN USER APPOINTMENTS
  // ============================================================
  void _openAppointments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UserAppointmentsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F2EA),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF542E13),
          ),
        ),
      );
    }

    final user = _profileData?['user'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F2EA),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFEADBCE),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8D4F28),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Profile & Fasting Settings',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF542E13),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF965126),
                    size: 22,
                  ),
                  tooltip: 'Logout',
                  onPressed: () async {
                    await AuthService.logout();

                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========================================================
            // USER PROFILE HEADER CARD
            // ========================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF542E13).withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF542E13),
                          Color(0xFF8D4F28),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1917),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user['email'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EBE1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Ethiopian Health Blueprint',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8D4F28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ========================================================
            // APPOINTMENTS & CONSULTATIONS
            // ========================================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF542E13).withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openAppointments,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EBE1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.video_call_outlined,
                            color: Color(0xFF542E13),
                            size: 26,
                          ),
                        ),

                        const SizedBox(width: 14),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointments & Consultations',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF542E13),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Schedule a nutritionist or join a video consultation',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF78716C),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF965126),
                          size: 25,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ========================================================
            // PHYSICAL METRICS
            // ========================================================
            _buildSectionHeader(
              'Physical Metrics',
              Icons.monitor_weight_outlined,
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricField(
                    controller: _ageCtrl,
                    label: 'Age',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricField(
                    controller: _weightCtrl,
                    label: 'Weight (kg)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricField(
                    controller: _heightCtrl,
                    label: 'Height (cm)',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ========================================================
            // FASTING TRADITION
            // ========================================================
            _buildSectionHeader(
              'Fasting Tradition (የጾም ሥርዓት)',
              Icons.church_outlined,
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _fastingPractice,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF542E13),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1C1917),
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'orthodox',
                      child: Text(
                        'Ethiopian Orthodox Fasting (ጾም) • Strict Vegan',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ramadan',
                      child: Text(
                        'Islamic Fasting (Ramadan & Sunnah)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(
                        'No Fasting Practice (Standard Diet)',
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _fastingPractice = v);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ========================================================
            // DIETARY GOAL
            // ========================================================
            _buildSectionHeader(
              'Dietary Goal',
              Icons.flag_outlined,
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEADBCE),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _goal,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF542E13),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1C1917),
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'maintain_weight',
                      child: Text(
                        'Maintain Weight & Wellness',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'lose_weight',
                      child: Text(
                        'Weight Loss (Caloric Deficit)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'gain_muscle',
                      child: Text(
                        'Muscle Gain (High Protein)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'iron_boost',
                      child: Text(
                        'Combat Anemia (High Red Teff)',
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _goal = v);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ========================================================
            // SAVE BUTTON
            // ========================================================
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFA8826B),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Text(
                      'UPDATE PROFILE & CALIBRATE TARGETS',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SECTION HEADER
  // ================================================================
  Widget _buildSectionHeader(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF965126),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF542E13),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // METRIC FIELD
  // ================================================================
  Widget _buildMetricField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1917),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF78716C),
          fontSize: 12.5,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F3EC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFEADBCE),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFEADBCE),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF542E13),
            width: 1.8,
          ),
        ),
      ),
    );
  }
}