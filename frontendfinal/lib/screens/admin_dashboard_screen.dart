import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  List<dynamic> _nutritionists = [];

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
    setState(() => _isLoading = true);
    try {
      final analyticsRes = await ApiClient.get('/admin/analytics');
      final usersRes = await ApiClient.get('/admin/users');
      final nutriRes = await ApiClient.get('/admin/nutritionists');

      if (mounted) {
        setState(() {
          _overview = analyticsRes['systemOverview'];
          _users = usersRes['users'] ?? [];
          _nutritionists = nutriRes['nutritionists'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNutritionistApproval(String id, bool currentStatus) async {
    try {
      await ApiClient.patch('/admin/nutritionists/$id/approval', {
        'isApproved': !currentStatus,
      });
      _loadAllAdminData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update approval: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      await ApiClient.delete('/admin/users/$id');
      setState(() => _users.removeWhere((u) => u['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF542E13),
            content: Text('User removed successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
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
    final credCtrl = TextEditingController(text: 'MSc Clinical Nutrition, Certified Dietitian');
    final rateCtrl = TextEditingController(text: '800');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: Color(0xFF8D4F28), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add Dietitian',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF542E13)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Color(0xFF78716C), fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF542E13))),
                ),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: Color(0xFF78716C), fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF542E13))),
                ),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color(0xFF78716C), fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF542E13))),
                ),
              ),
              TextField(
                controller: credCtrl,
                decoration: const InputDecoration(
                  labelText: 'Credentials',
                  labelStyle: TextStyle(color: Color(0xFF78716C), fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF542E13))),
                ),
              ),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hourly Rate (ETB)',
                  labelStyle: TextStyle(color: Color(0xFF78716C), fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF542E13))),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF78716C)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF542E13),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.post('/admin/nutritionists', {
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim().toLowerCase(),
                  'password': passCtrl.text,
                  'credentials': credCtrl.text.trim(),
                  'hourlyRateEtb': double.tryParse(rateCtrl.text) ?? 800,
                });
                _loadAllAdminData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF542E13),
                      content: Text('Dietitian account created!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA), // Warm Sand Background
      appBar: AppBar(
        title: const Text(
          'EthioNutri Admin Portal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF542E13), // Deep Cognac Brown
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
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
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'System Stats'),
                Tab(icon: Icon(Icons.people_outline_rounded, size: 18), text: 'Users'),
                Tab(icon: Icon(Icons.medical_services_outlined, size: 18), text: 'Dietitians'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF542E13)),
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
        onPressed: _showAddNutritionistDialog,
        backgroundColor: const Color(0xFF542E13),
        foregroundColor: Colors.white,
        elevation: 3,
        child: const Icon(Icons.person_add_rounded),
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
                  'Registered Users',
                  '${ov['totalRegisteredUsers'] ?? 0}',
                  Icons.people_rounded,
                  const Color(0xFF542E13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Active Premium',
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
                  'Approved Dietitians',
                  '${ov['activeDietitians'] ?? 0}',
                  Icons.medical_services_rounded,
                  const Color(0xFF542E13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Food Logs Logged',
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
                  'Consultations',
                  '${ov['totalAppointments'] ?? 0}',
                  Icons.event_note_rounded,
                  const Color(0xFF78350F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Total Revenue',
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final u = _users[idx];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEADBCE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFF8D4F28), size: 20),
            ),
            title: Text(
              u['name'] ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1C1917)),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${u['email']}\nRole: ${(u['role'] ?? 'USER').toString().toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              tooltip: 'Delete user',
              onPressed: () => _deleteUser(u['id']),
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
          padding: const EdgeInsets.all(40.0),
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
                child: const Icon(Icons.medical_services_outlined, size: 32, color: Color(0xFF8D4F28)),
              ),
              const SizedBox(height: 14),
              const Text(
                'No registered clinical dietitians yet.',
                style: TextStyle(color: Color(0xFF78716C), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _nutritionists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final n = _nutritionists[idx];
        final isApp = n['isApproved'] == true;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isApp ? const Color(0xFFEADBCE) : const Color(0xFFFED7AA),
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
                      child: const Icon(Icons.medical_services_outlined, color: Color(0xFF8D4F28), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['name'] ?? 'Dietitian',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n['credentials'] ?? 'Clinical Dietitian',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                          ),
                          if (n['email'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              n['email'],
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFA8A29E)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBE1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEADBCE)),
                      ),
                      child: Text(
                        '${n['hourlyRateEtb'] ?? 800} ETB/hr',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF542E13),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFEFE8DF)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isApp ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isApp ? 'VERIFIED & ACTIVE' : 'APPROVAL PENDING',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isApp ? const Color(0xFF166534) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isApp ? 'Can accept patients' : 'Restricted from booking',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF78716C)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Approved',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF44403C)),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: isApp,
                          activeColor: const Color(0xFF542E13),
                          activeTrackColor: const Color(0xFFEADBCE),
                          onChanged: (_) => _toggleNutritionistApproval(n['nutritionistId'], isApp),
                        ),
                      ],
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

  Widget _metricCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBCE)),
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
            child: Icon(icon, color: accentColor, size: 20),
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
            title,
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