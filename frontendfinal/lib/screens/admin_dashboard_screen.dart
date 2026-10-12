
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/app_localization.dart';
import '../widgets/language_toggle_button.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  List<dynamic> _nutritionists = [];

  String _tr(String key) =>
      AppLocalization.instance.tr(key);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final analyticsRes =
          await ApiClient.get('/admin/analytics');
      final usersRes =
          await ApiClient.get('/admin/users');
      final nutriRes =
          await ApiClient.get('/admin/nutritionists');

      if (!mounted) return;

      setState(() {
        _overview = analyticsRes['systemOverview'];
        _users = usersRes['users'] ?? [];
        _nutritionists = nutriRes['nutritionists'] ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_tr('admin_error')}: $e'),
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

  Future<void> _toggleNutritionistApproval(
    String id,
    bool currentStatus,
  ) async {
    try {
      await ApiClient.patch(
        '/admin/nutritionists/$id/approval',
        {'isApproved': !currentStatus},
      );
      await _loadAllAdminData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tr('admin_approval_failed')}: $e',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      await ApiClient.delete('/admin/users/$id');

      if (!mounted) return;

      setState(() {
        _users.removeWhere((u) => u['id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF542E13),
          content: Text(_tr('admin_user_deleted')),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tr('admin_delete_failed')}: $e',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showAddNutritionistDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final credCtrl = TextEditingController(
      text: 'MSc Clinical Nutrition, Certified Dietitian',
    );
    final rateCtrl = TextEditingController(text: '800');

    showDialog(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: AppLocalization.instance,
        builder: (context, child) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: Color(0xFF8D4F28),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tr('admin_add_dietitian'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF542E13),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'admin_full_name'),
                _dialogField(emailCtrl, 'admin_email'),
                _dialogField(
                  passCtrl,
                  'admin_password',
                  obscure: true,
                ),
                _dialogField(credCtrl, 'admin_credentials'),
                _dialogField(
                  rateCtrl,
                  'admin_hourly_rate',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF78716C),
              ),
              child: Text(_tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF542E13),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty ||
                    passCtrl.text.isEmpty) {
                  return;
                }

                Navigator.pop(ctx);

                try {
                  await ApiClient.post(
                    '/admin/nutritionists',
                    {
                      'name': nameCtrl.text.trim(),
                      'email':
                          emailCtrl.text.trim().toLowerCase(),
                      'password': passCtrl.text,
                      'credentials': credCtrl.text.trim(),
                      'hourlyRateEtb':
                          double.tryParse(rateCtrl.text) ?? 800,
                    },
                  );

                  await _loadAllAdminData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor:
                            const Color(0xFF542E13),
                        content: Text(
                          _tr('admin_dietitian_created'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_tr('admin_error')}: $e',
                        ),
                        backgroundColor:
                            const Color(0xFFDC2626),
                      ),
                    );
                  }
                } finally {
                  nameCtrl.dispose();
                  emailCtrl.dispose();
                  passCtrl.dispose();
                  credCtrl.dispose();
                  rateCtrl.dispose();
                }
              },
              child: Text(_tr('admin_create_account')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String labelKey, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: _tr(labelKey),
        labelStyle: const TextStyle(
          color: Color(0xFF78716C),
          fontSize: 13,
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF542E13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalization.instance,
      builder: (context, child) => Scaffold(
        backgroundColor: const Color(0xFFF7F2EA),
        appBar: AppBar(
          title: Text(
            _tr('admin_portal_title'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          backgroundColor: const Color(0xFF542E13),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            const LanguageToggleButton(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _tr('refresh'),
              onPressed: _loadAllAdminData,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: _tr('logout'),
              onPressed: () async {
                await AuthService.logout();

                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: const Color(0xFF43240E),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFEADBCE),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Colors.white.withOpacity(0.7),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    icon: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                    ),
                    text: _tr('admin_system_stats'),
                  ),
                  Tab(
                    icon: const Icon(
                      Icons.people_outline_rounded,
                      size: 18,
                    ),
                    text: _tr('admin_users'),
                  ),
                  Tab(
                    icon: const Icon(
                      Icons.medical_services_outlined,
                      size: 18,
                    ),
                    text: _tr('admin_dietitians'),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF542E13),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(),
                  _buildUsersTab(),
                  _buildNutritionistsTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          tooltip: _tr('admin_add_dietitian'),
          onPressed: _showAddNutritionistDialog,
          backgroundColor: const Color(0xFF542E13),
          foregroundColor: Colors.white,
          elevation: 3,
          child: const Icon(Icons.person_add_rounded),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final ov = _overview ?? {};

    return RefreshIndicator(
      color: const Color(0xFF542E13),
      onRefresh: _loadAllAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'admin_registered_users',
                  '${ov['totalRegisteredUsers'] ?? 0}',
                  Icons.people_rounded,
                  const Color(0xFF542E13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'admin_active_premium',
                  '${ov['activePremiumUsers'] ?? 0}',
                  Icons.workspace_premium_rounded,
                  const Color(0xFF8D4F28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'admin_approved_dietitians',
                  '${ov['activeDietitians'] ?? 0}',
                  Icons.medical_services_rounded,
                  const Color(0xFF542E13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'admin_food_logs',
                  '${ov['totalFoodLogs'] ?? 0}',
                  Icons.restaurant_rounded,
                  const Color(0xFF965126),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'admin_consultations',
                  '${ov['totalAppointments'] ?? 0}',
                  Icons.event_note_rounded,
                  const Color(0xFF78350F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'admin_total_revenue',
                  '${ov['totalRevenueEtb'] ?? 0} ETB',
                  Icons.payments_rounded,
                  const Color(0xFF542E13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _users[index];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEADBCE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF8D4F28),
                size: 20,
              ),
            ),
            title: Text(
              user['name'] ?? _tr('admin_user'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: Color(0xFF1C1917),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${user['email']}\n'
                '${_tr('admin_role')}: '
                '${(user['role'] ?? 'USER').toString().toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF78716C),
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
              ),
              tooltip: _tr('admin_delete_user'),
              onPressed: () => _deleteUser(user['id']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionistsTab() {
    if (_nutritionists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  size: 32,
                  color: Color(0xFF8D4F28),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _tr('admin_no_dietitians'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF78716C),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _nutritionists.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final nutritionist = _nutritionists[index];
        final isApproved =
            nutritionist['isApproved'] == true;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isApproved
                  ? const Color(0xFFEADBCE)
                  : const Color(0xFFFED7AA),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5EBE1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        color: Color(0xFF8D4F28),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            nutritionist['name'] ??
                                _tr('admin_dietitian'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nutritionist['credentials'] ??
                                _tr('admin_clinical_dietitian'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78716C),
                            ),
                          ),
                          if (nutritionist['email'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              nutritionist['email'],
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFA8A29E),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBE1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEADBCE),
                        ),
                      ),
                      child: Text(
                        '${nutritionist['hourlyRateEtb'] ?? 800} '
                        '${_tr('admin_etb_per_hour')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF542E13),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 20,
                  color: Color(0xFFEFE8DF),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _tr(
                          isApproved
                              ? 'admin_verified_active'
                              : 'admin_approval_pending',
                        ),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isApproved
                              ? const Color(0xFF166534)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    Text(
                      _tr(
                        isApproved
                            ? 'admin_can_accept_patients'
                            : 'admin_restricted_booking',
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _tr('admin_approved'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44403C),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: isApproved,
                      activeColor: const Color(0xFF542E13),
                      activeTrackColor: const Color(0xFFEADBCE),
                      onChanged: (_) =>
                          _toggleNutritionistApproval(
                        nutritionist['nutritionistId'].toString(),
                        isApproved,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricCard(
    String titleKey,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF5EBE1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1917),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _tr(titleKey),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78716C),
            ),
          ),
        ],
      ),
    );
  }
}