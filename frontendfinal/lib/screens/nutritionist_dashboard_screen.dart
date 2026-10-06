import 'package:flutter/material.dart';

import 'nutritionist_patient_chat_screen.dart';
import 'nutritionist_video_call_screen.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/appointment_service.dart';
import 'login_screen.dart';

class NutritionistDashboardScreen extends StatefulWidget {
  const NutritionistDashboardScreen({super.key});

  @override
  State<NutritionistDashboardScreen> createState() =>
      _NutritionistDashboardScreenState();
}

class _NutritionistDashboardScreenState
    extends State<NutritionistDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  bool _sendingMessage = false;

  String? _error;

  Map<String, dynamic> _dashboardData = {};

  List<dynamic> _patients = [];
  List<dynamic> _appointments = [];

  Map<String, dynamic> _dietitian = {};

  int _highRiskCount = 0;

  static const Color darkBrown = Color(0xFF4A2C1A);
  static const Color brown = Color(0xFF6B4226);
  static const Color lightBrown = Color(0xFF8B5E3C);
  static const Color background = Color(0xFFF8F5F1);
  static const Color textDark = Color(0xFF2D211B);
  static const Color textMuted = Color(0xFF7A6D65);
  static const Color borderColor = Color(0xFFE5DDD6);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get(
        '/supervision/dietitian/dashboard',
      );

      if (!mounted) return;

      if (response is Map) {
        _dashboardData = Map<String, dynamic>.from(response);

        final patients =
            response['patients'];

        final appointments =
            response['upcomingAppointments'];

        final dietitian =
            response['dietitian'];

        _patients = patients is List
            ? List<dynamic>.from(patients)
            : [];

        _appointments = appointments is List
            ? List<dynamic>.from(appointments)
            : [];

        _dietitian = dietitian is Map
            ? Map<String, dynamic>.from(dietitian)
            : {};

        _highRiskCount =
            _toInt(response['highRiskCount']);
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  // ============================================================
  // OPEN VIDEO CONSULTATION
  // ============================================================

  Future<void> _openVideoConsultation(
    Map<String, dynamic> appointment,
  ) async {
    final appointmentId =
        appointment['id']?.toString();

    if (appointmentId == null ||
        appointmentId.isEmpty) {
      _showSnackBar(
        'Appointment ID is missing.',
        isError: true,
      );
      return;
    }

    final scheduledAt = _parseDate(
      appointment['scheduledAt'],
    );

    if (scheduledAt == null) {
      _showSnackBar(
        'Appointment time is invalid.',
        isError: true,
      );
      return;
    }

    final endsAt = _parseDate(
      appointment['endsAt'] ??
          appointment['endAt'] ??
          appointment['endTime'],
    );

    try {
      _showLoadingDialog();

      final session =
          await AppointmentService.getVideoSession(
        appointmentId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      final roomName =
          session['roomName']?.toString();

      if (roomName == null ||
          roomName.isEmpty) {
        _showSnackBar(
          'Video room could not be created.',
          isError: true,
        );
        return;
      }

      final participantName =
          appointment['userName']?.toString() ??
              session['patient']?['name']
                  ?.toString() ??
              'Patient';

      final participantEmail =
          appointment['userEmail']?.toString() ??
              session['patient']?['email']
                  ?.toString();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NutritionistVideoCallScreen(
            roomName: roomName,
            participantName: participantName,
            participantEmail: participantEmail,
            appointmentId: appointmentId,
            scheduledAt: scheduledAt,
            endsAt: endsAt,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showSnackBar(
        'Unable to open consultation: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ============================================================
  // PATIENT CHAT
  // ============================================================

  Future<void> _openPatientChat(
    Map<String, dynamic> patient,
  ) async {
    final patientId =
        patient['id']?.toString() ??
            patient['userId']?.toString();

    if (patientId == null ||
        patientId.isEmpty) {
      _showSnackBar(
        'Patient ID is missing.',
        isError: true,
      );
      return;
    }

    final patientName =
        patient['name']?.toString() ??
            patient['userName']?.toString() ??
            'Patient';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NutritionistPatientChatScreen(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage(
    Map<String, dynamic> patient,
  ) async {
    final patientId =
        patient['id']?.toString() ??
            patient['userId']?.toString();

    if (patientId == null ||
        patientId.isEmpty) {
      _showSnackBar(
        'Patient ID is missing.',
        isError: true,
      );
      return;
    }

    final controller =
        TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Send Message',
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration:
                const InputDecoration(
              hintText:
                  'Type your message...',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text =
                    controller.text.trim();

                if (text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    text,
                  );
                }
              },
              child: const Text(
                'Send',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (message == null ||
        message.trim().isEmpty) {
      return;
    }

    try {
      setState(() {
        _sendingMessage = true;
      });

      await ApiClient.post(
        '/supervision/messages',
        {
          'receiverId': patientId,
          'message': message.trim(),
        },
      );

      if (!mounted) return;

      _showSnackBar(
        'Message sent successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to send message: ${_cleanError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await AuthService.logout();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    final parsed =
        DateTime.tryParse(value.toString());

    return parsed?.toLocal();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _cleanError(dynamic error) {
    String message = error.toString();

    if (message.startsWith('Exception:')) {
      message =
          message.substring(10).trim();
    }

    return message;
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return '-';
    }

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }

  String _formatAppointmentStatus(
    dynamic status,
  ) {
    if (status == null) return 'UNKNOWN';

    final value =
        status.toString().trim();

    if (value.isEmpty) {
      return 'UNKNOWN';
    }

    return value.toUpperCase();
  }

  Color _statusColor(dynamic status) {
    final value =
        status?.toString().toLowerCase();

    switch (value) {
      case 'confirmed':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'cancelled':
      case 'canceled':
        return Colors.red;

      case 'pending':
        return Colors.orange;

      default:
        return textMuted;
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red : darkBrown,
        ),
      );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nutritionist Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildHeader(),

                    _buildTabs(),

                    Expanded(
                      child:
                          TabBarView(
                        controller:
                            _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildPatientsTab(),
                          _buildAppointmentsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final name =
        _dietitian['name']?.toString() ??
            _dietitian['userName']?.toString() ??
            'Nutritionist';

    final email =
        _dietitian['email']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        color: darkBrown,
        borderRadius: BorderRadius.only(
          bottomLeft:
              Radius.circular(24),
          bottomRight:
              Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(
              color: Colors.white
                  .withOpacity(.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              email,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(.75),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: darkBrown,
        unselectedLabelColor:
            textMuted,
        indicatorColor: darkBrown,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            text: 'Overview',
            icon: Icon(
              Icons.dashboard_rounded,
              size: 18,
            ),
          ),
          Tab(
            text: 'Patients',
            icon: Icon(
              Icons.people_alt_rounded,
              size: 18,
            ),
          ),
          Tab(
            text: 'Appointments',
            icon: Icon(
              Icons.calendar_month_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW TAB
  // ============================================================

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Patients',
                  value:
                      _patients.length.toString(),
                  icon:
                      Icons.people_alt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Appointments',
                  value:
                      _appointments.length.toString(),
                  icon:
                      Icons.calendar_month_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'High Risk',
                  value:
                      _highRiskCount.toString(),
                  icon:
                      Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Upcoming',
                  value:
                      _upcomingCount().toString(),
                  icon:
                      Icons.video_call_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'Upcoming Consultations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),

          const SizedBox(height: 12),

          if (_appointments.isEmpty)
            _buildEmptyCard(
              icon:
                  Icons.video_call_outlined,
              title:
                  'No upcoming consultations',
              subtitle:
                  'Clinical video consultations and dietary review sessions will appear here.',
            )
          else
            ..._appointments
                .take(3)
                .map(
                  (appointment) =>
                      _buildAppointmentCard(
                    Map<String, dynamic>.from(
                      appointment as Map,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  int _upcomingCount() {
    final now = DateTime.now();

    return _appointments.where((item) {
      if (item is! Map) return false;

      final date =
          _parseDate(item['scheduledAt']);

      return date != null &&
          date.isAfter(now);
    }).length;
  }

  // ============================================================
  // PATIENTS TAB
  // ============================================================

  Widget _buildPatientsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: _patients.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                _buildEmptyCard(
                  icon:
                      Icons.people_outline_rounded,
                  title:
                      'No patients found',
                  subtitle:
                      'Assigned patients will appear here.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              itemBuilder: (
                context,
                index,
              ) {
                final patient =
                    Map<String, dynamic>.from(
                  _patients[index] as Map,
                );

                return _buildPatientCard(
                  patient,
                );
              },
            ),
    );
  }

  // ============================================================
  // PATIENT CARD
  // ============================================================

  Widget _buildPatientCard(
    Map<String, dynamic> patient,
  ) {
    final name =
        patient['name']?.toString() ??
            patient['userName']?.toString() ??
            'Patient';

    final email =
        patient['email']?.toString() ??
            patient['userEmail']?.toString() ??
            '';

    final patientId =
        patient['id']?.toString() ??
            patient['userId']?.toString() ??
            '-';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    lightBrown.withOpacity(.12),
                child: const Icon(
                  Icons.person_rounded,
                  color: darkBrown,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 3,
                        ),
                        child: Text(
                          email,
                          style:
                              const TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Patient ID: $patientId',
            style: const TextStyle(
              color: textMuted,
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openPatientChat(
                      patient,
                    );
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 17,
                  ),
                  label: const Text(
                    'Open Chat',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        darkBrown,
                    side: const BorderSide(
                      color: darkBrown,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _sendingMessage
                          ? null
                          : () {
                              _sendMessage(
                                patient,
                              );
                            },
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 17,
                  ),
                  label: const Text(
                    'Direct Msg',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        darkBrown,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPOINTMENTS TAB
  // ============================================================

  Widget _buildAppointmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: _appointments.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                _buildEmptyCard(
                  icon:
                      Icons.calendar_today_outlined,
                  title:
                      'No appointments',
                  subtitle:
                      'Scheduled consultation sessions will appear here.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
                  _appointments.length,
              itemBuilder: (
                context,
                index,
              ) {
                final appointment =
                    Map<String, dynamic>.from(
                  _appointments[index]
                      as Map,
                );

                return _buildAppointmentCard(
                  appointment,
                );
              },
            ),
    );
  }

  // ============================================================
  // APPOINTMENT CARD
  // ============================================================

  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment,
  ) {
    final status =
        appointment['status'];

    final statusText =
        _formatAppointmentStatus(
      status,
    );

    final statusColor =
        _statusColor(status);

    final patientName =
        appointment['userName']
                ?.toString() ??
            'Patient';

    final patientEmail =
        appointment['userEmail']
                ?.toString() ??
            '';

    final scheduledAt =
        appointment['scheduledAt'];

    final notes =
        appointment['notes']?.toString() ??
            '';

    final appointmentId =
        appointment['id']?.toString() ??
            '-';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color:
                Colors.black.withOpacity(.035),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // TOP ROW
          // ------------------------------------------------------

          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      darkBrown.withOpacity(.08),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: darkBrown,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style:
                          const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (patientEmail.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 3,
                        ),
                        child: Text(
                          patientEmail,
                          style:
                              const TextStyle(
                            color: textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor
                      .withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // SCHEDULED TIME
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: brown,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled consultation',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(
                          scheduledAt,
                        ),
                        style:
                            const TextStyle(
                          color: textDark,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // NOTES
          // ------------------------------------------------------

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),

            const Text(
              'Notes',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              notes,
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],

          // ------------------------------------------------------
          // VIDEO BUTTON
          // ------------------------------------------------------

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _openVideoConsultation(
                  appointment,
                );
              },
              icon: const Icon(
                Icons.video_call_rounded,
                size: 19,
              ),
              label: const Text(
                'OPEN VIDEO CONSULTATION',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    darkBrown,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                textStyle:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ------------------------------------------------------
          // SESSION REF
          // ------------------------------------------------------

          Text(
            'Session Ref: $appointmentId',
            style: const TextStyle(
              fontSize: 10.5,
              color: textMuted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  darkBrown.withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: darkBrown,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 2,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color: lightBrown,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.red,
            ),

            const SizedBox(height: 14),

            const Text(
              'Unable to load dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _error ?? 'Unknown error.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    darkBrown,
                foregroundColor:
                    Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}