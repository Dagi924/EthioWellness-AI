import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/appointment_service.dart';
import 'nutritionist_video_call_screen.dart';

class UserAppointmentsScreen extends StatefulWidget {
  const UserAppointmentsScreen({super.key});

  @override
  State<UserAppointmentsScreen> createState() =>
      _UserAppointmentsScreenState();
}

class _UserAppointmentsScreenState
    extends State<UserAppointmentsScreen> {
  bool _loading = true;
  String? _error;

  List<dynamic> _appointments = [];

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
    _loadAppointments();
  }

  // ============================================================
  // LOAD USER APPOINTMENTS
  // ============================================================

  Future<void> _loadAppointments() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get(
        '/supervision/my-appointments',
      );

      if (!mounted) return;

      if (response is Map) {
        final appointments =
            response['appointments'];

        if (appointments is List) {
          _appointments =
              List<dynamic>.from(appointments);
        } else {
          _appointments = [];
        }
      } else if (response is List) {
        _appointments =
            List<dynamic>.from(response);
      } else {
        _appointments = [];
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
  // JOIN VIDEO CONSULTATION
  // ============================================================

  Future<void> _joinVideoConsultation(
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

    final scheduledAt =
        _parseDate(
      appointment['scheduledAt'],
    );

    if (scheduledAt == null) {
      _showSnackBar(
        'Appointment time is invalid.',
        isError: true,
      );
      return;
    }

    final status =
        appointment['status']
            ?.toString()
            .toLowerCase();

    if (status == 'cancelled' ||
        status == 'canceled') {
      _showSnackBar(
        'This appointment has been cancelled.',
        isError: true,
      );
      return;
    }

    try {
      _showLoadingDialog();
      
final session =
    await AppointmentService
        .getPatientVideoSession(
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

      final nutritionist =
          appointment['nutritionist'];

      String nutritionistName =
          'Nutritionist';

      String? nutritionistEmail;

      if (nutritionist is Map) {
        nutritionistName =
            nutritionist['name']
                    ?.toString() ??
                nutritionist['userName']
                    ?.toString() ??
                'Nutritionist';

        nutritionistEmail =
            nutritionist['email']
                ?.toString();
      }

      nutritionistName =
          appointment['nutritionistName']
                  ?.toString() ??
              nutritionistName;

      nutritionistEmail =
          appointment['nutritionistEmail']
                  ?.toString() ??
              nutritionistEmail;

      final endsAt =
          _parseDate(
        appointment['endsAt'] ??
            appointment['endAt'] ??
            appointment['endTime'],
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NutritionistVideoCallScreen(
            roomName: roomName,
            participantName:
                nutritionistName,
            participantEmail:
                nutritionistEmail,
            appointmentId:
                appointmentId,
            scheduledAt:
                scheduledAt,
            endsAt: endsAt,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showSnackBar(
        'Unable to join consultation: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ============================================================
  // OPEN SCHEDULING SCREEN
  // ============================================================

  void _openScheduleScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ScheduleAppointmentScreen(),
      ),
    ).then((_) {
      _loadAppointments();
    });
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
        DateTime.tryParse(
      value.toString(),
    );

    return parsed?.toLocal();
  }

  String _cleanError(dynamic error) {
    String message =
        error.toString();

    if (message.startsWith(
      'Exception:',
    )) {
      message =
          message.substring(10).trim();
    }

    return message;
  }

  String _formatDate(
    dynamic value,
  ) {
    final date =
        _parseDate(value);

    if (date == null) {
      return '-';
    }

    final hour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }

  bool _isPast(
    dynamic value,
  ) {
    final date =
        _parseDate(value);

    if (date == null) {
      return false;
    }

    return !date.isAfter(
      DateTime.now(),
    );
  }

  bool _isCancelled(
    dynamic status,
  ) {
    final value =
        status
            ?.toString()
            .toLowerCase();

    return value == 'cancelled' ||
        value == 'canceled';
  }

  Color _statusColor(
    dynamic status,
  ) {
    switch (
        status
            ?.toString()
            .toLowerCase()) {
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
              isError
                  ? Colors.red
                  : darkBrown,
        ),
      );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child:
              CircularProgressIndicator(),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar: AppBar(
        backgroundColor:
            darkBrown,
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: const Text(
          'My Appointments',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading
                    ? null
                    : _loadAppointments,
            icon: const Icon(
              Icons.refresh_rounded,
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
              : RefreshIndicator(
                  onRefresh:
                      _loadAppointments,
                  child:
                      _buildBody(),
                ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openScheduleScreen,
        backgroundColor:
            darkBrown,
        foregroundColor:
            Colors.white,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Schedule Appointment',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_appointments.isEmpty) {
      return ListView(
        padding:
            const EdgeInsets.all(20),
        children: [
          const SizedBox(
            height: 100,
          ),
          _buildEmptyState(),
        ],
      );
    }

    final upcoming =
        _appointments.where(
      (item) {
        if (item is! Map) {
          return false;
        }

        final appointment =
            Map<String, dynamic>.from(
          item,
        );

        return !_isPast(
              appointment[
                  'scheduledAt'],
            ) &&
            !_isCancelled(
              appointment[
                  'status'],
            );
      },
    ).toList();

    final previous =
        _appointments.where(
      (item) {
        if (item is! Map) {
          return false;
        }

        final appointment =
            Map<String, dynamic>.from(
          item,
        );

        return _isPast(
              appointment[
                  'scheduledAt'],
            ) ||
            _isCancelled(
              appointment[
                  'status'],
            );
      },
    ).toList();

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        100,
      ),
      children: [
        _buildInfoBanner(),

        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 22),

          const Text(
            'Upcoming Appointments',
            style: TextStyle(
              color: textDark,
              fontSize: 19,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          ...upcoming.map(
            (item) =>
                _buildAppointmentCard(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
          ),
        ],

        if (previous.isNotEmpty) ...[
          const SizedBox(height: 22),

          const Text(
            'Previous Appointments',
            style: TextStyle(
              color: textDark,
              fontSize: 19,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          ...previous.map(
            (item) =>
                _buildAppointmentCard(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // INFO BANNER
  // ============================================================

  Widget _buildInfoBanner() {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            darkBrown.withOpacity(.07),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              darkBrown.withOpacity(.12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.video_call_rounded,
            color: darkBrown,
            size: 24,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrition Consultation',
                  style: TextStyle(
                    color: textDark,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Schedule a consultation with an approved nutritionist. '
                  'The video meeting becomes available at the scheduled time.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11.5,
                    height: 1.4,
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
  // APPOINTMENT CARD
  // ============================================================

  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment,
  ) {
    final status =
        appointment['status'];

    final statusText =
        status
                ?.toString()
                .toUpperCase() ??
            'UNKNOWN';

    final statusColor =
        _statusColor(status);

    final scheduledAt =
        appointment[
            'scheduledAt'];

    final past =
        _isPast(scheduledAt);

    final cancelled =
        _isCancelled(status);

    final appointmentId =
        appointment['id']
                ?.toString() ??
            '-';

    String nutritionistName =
        appointment[
                    'nutritionistName']
                ?.toString() ??
            'Nutritionist';

    String nutritionistEmail =
        appointment[
                    'nutritionistEmail']
                ?.toString() ??
            '';

    final nutritionist =
        appointment[
            'nutritionist'];

    if (nutritionist is Map) {
      nutritionistName =
          nutritionist['name']
                  ?.toString() ??
              nutritionist[
                      'userName']
                  ?.toString() ??
              nutritionistName;

      nutritionistEmail =
          nutritionist['email']
                  ?.toString() ??
              nutritionistEmail;
    }

    final notes =
        appointment['notes']
                ?.toString() ??
            '';

    final canJoin =
        !past && !cancelled;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 13,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.035),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------

          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: darkBrown
                      .withOpacity(.08),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: darkBrown,
                  size: 23,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      nutritionistName,
                      style:
                          const TextStyle(
                        color: textDark,
                        fontSize: 15.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (nutritionistEmail
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 3,
                        ),
                        child: Text(
                          nutritionistEmail,
                          style:
                              const TextStyle(
                            color:
                                textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
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
                    color:
                        statusColor,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          // ------------------------------------------------------
          // DATE/TIME
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .calendar_month_rounded,
                  color: brown,
                  size: 20,
                ),
                const SizedBox(
                  width: 9,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Appointment time',
                        style: TextStyle(
                          color:
                              textMuted,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        _formatDate(
                          scheduledAt,
                        ),
                        style:
                            const TextStyle(
                          color:
                              textDark,
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
            const SizedBox(
              height: 12,
            ),
            const Text(
              'Notes',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              notes,
              style:
                  const TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],

          // ------------------------------------------------------
          // VIDEO BUTTON
          // ------------------------------------------------------

          if (canJoin) ...[
            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed: () {
                  _joinVideoConsultation(
                    appointment,
                  );
                },
                icon: const Icon(
                  Icons.video_call_rounded,
                  size: 19,
                ),
                label: const Text(
                  'JOIN VIDEO CONSULTATION',
                ),
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      darkBrown,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 13,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  textStyle:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 10,
          ),

          Text(
            'Appointment ID: $appointmentId',
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: darkBrown
                .withOpacity(.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons
                .calendar_month_rounded,
            color: darkBrown,
            size: 44,
          ),
        ),

        const SizedBox(
          height: 17,
        ),

        const Text(
          'No appointments yet',
          style: TextStyle(
            color: textDark,
            fontSize: 19,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        const Text(
          'Schedule a consultation with a nutritionist to get started.',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        ElevatedButton.icon(
          onPressed:
              _openScheduleScreen,
          icon: const Icon(
            Icons.add_rounded,
          ),
          label: const Text(
            'Schedule Appointment',
          ),
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                darkBrown,
            foregroundColor:
                Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 20,
              vertical: 13,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.red,
              size: 50,
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Unable to load appointments',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _error ??
                  'Unknown error.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(
              height: 17,
            ),

            ElevatedButton.icon(
              onPressed:
                  _loadAppointments,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style:
                  ElevatedButton
                      .styleFrom(
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

// ==================================================================
// SCHEDULE APPOINTMENT SCREEN
// ==================================================================

class ScheduleAppointmentScreen
    extends StatefulWidget {
  const ScheduleAppointmentScreen({
    super.key,
  });

  @override
  State<ScheduleAppointmentScreen>
      createState() =>
          _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState
    extends State<
        ScheduleAppointmentScreen> {
  bool _loadingNutritionists =
      true;

  bool _loadingSlots = false;

  bool _booking = false;

  String? _error;

  List<dynamic>
      _nutritionists = [];

  Map<String, dynamic>?
      _selectedNutritionist;

  DateTime _selectedDate =
      DateTime.now();

  String? _selectedTime;

  List<String> _availableSlots = [];

  final TextEditingController
      _notesController =
      TextEditingController();

  static const Color darkBrown =
      Color(0xFF4A2C1A);

  static const Color brown =
      Color(0xFF6B4226);

  static const Color background =
      Color(0xFFF8F5F1);

  static const Color textDark =
      Color(0xFF2D211B);

  static const Color textMuted =
      Color(0xFF7A6D65);

  static const Color borderColor =
      Color(0xFFE5DDD6);

  @override
  void initState() {
    super.initState();

    _loadNutritionists();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD NUTRITIONISTS
  // ============================================================

  Future<void>
      _loadNutritionists() async {
    try {
      final response =
          await ApiClient.get(
        '/supervision/nutritionists',
      );

      if (!mounted) return;

      if (response is Map) {
        final data =
            response['nutritionists'];

        if (data is List) {
          _nutritionists =
              List<dynamic>.from(
            data,
          );
        }
      } else if (response is List) {
        _nutritionists =
            List<dynamic>.from(
          response,
        );
      }

      setState(() {
        _loadingNutritionists =
            false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingNutritionists =
            false;
        _error =
            _cleanError(e);
      });
    }
  }

  // ============================================================
  // LOAD AVAILABLE TIME SLOTS
  // ============================================================

  Future<void>
      _loadAvailableSlots() async {
    final nutritionist =
        _selectedNutritionist;

    if (nutritionist == null) {
      return;
    }

    final nutritionistId =
        nutritionist['id']
            ?.toString();

    if (nutritionistId == null ||
        nutritionistId.isEmpty) {
      return;
    }

    setState(() {
      _loadingSlots = true;
      _selectedTime = null;
      _availableSlots = [];
    });

    try {
      final date =
          '${_selectedDate.year}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final response =
          await ApiClient.get(
        '/supervision/nutritionists/$nutritionistId/availability?date=$date',
      );

      if (!mounted) return;

      if (response is Map) {
        final slots =
            response['availableSlots'];

        if (slots is List) {
          _availableSlots =
              slots
                  .map(
                    (slot) =>
                        slot.toString(),
                  )
                  .toList();
        }
      } else if (response is List) {
        _availableSlots =
            response
                .map(
                  (slot) =>
                      slot.toString(),
                )
                .toList();
      }

      setState(() {
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingSlots = false;
      });

      _showSnackBar(
        'Unable to load available times: ${_cleanError(e)}',
        isError: true,
      );
    }
  }

  // ============================================================
  // SELECT DATE
  // ============================================================

  Future<void> _selectDate() async {
    final today =
        DateTime.now();

    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          _selectedDate.isBefore(
        DateTime(
          today.year,
          today.month,
          today.day,
        ),
      )
              ? today
              : _selectedDate,
      firstDate:
          DateTime(
        today.year,
        today.month,
        today.day,
      ),
      lastDate:
          DateTime(
        today.year + 1,
        today.month,
        today.day,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
    });

    await _loadAvailableSlots();
  }

  // ============================================================
  // BOOK APPOINTMENT
  // ============================================================

  Future<void>
      _bookAppointment() async {
    final nutritionist =
        _selectedNutritionist;

    if (nutritionist == null) {
      _showSnackBar(
        'Please select a nutritionist.',
        isError: true,
      );
      return;
    }

    if (_selectedTime == null ||
        _selectedTime!.isEmpty) {
      _showSnackBar(
        'Please select an available time.',
        isError: true,
      );
      return;
    }

    final nutritionistId =
        nutritionist['id']
            ?.toString();

    if (nutritionistId == null ||
        nutritionistId.isEmpty) {
      _showSnackBar(
        'Nutritionist ID is missing.',
        isError: true,
      );
      return;
    }

    final parts =
        _selectedTime!
            .split(':');

    if (parts.length != 2) {
      _showSnackBar(
        'Invalid appointment time.',
        isError: true,
      );
      return;
    }

    final hour =
        int.tryParse(parts[0]);

    final minute =
        int.tryParse(parts[1]);

    if (hour == null ||
        minute == null) {
      _showSnackBar(
        'Invalid appointment time.',
        isError: true,
      );
      return;
    }

    final scheduledAt =
        DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );

    if (!scheduledAt.isAfter(
      DateTime.now(),
    )) {
      _showSnackBar(
        'Please select a future time.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _booking = true;
      });

      await ApiClient.post(
        '/supervision/appointments',
        {
          'nutritionistId':
              nutritionistId,
          'scheduledAt':
              scheduledAt
                  .toUtc()
                  .toIso8601String(),
          'notes':
              _notesController.text
                  .trim(),
        },
      );

      if (!mounted) return;

      _showSnackBar(
        'Appointment scheduled successfully.',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 600,
        ),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to schedule appointment: ${_cleanError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _booking = false;
        });
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _cleanError(
    dynamic error,
  ) {
    String message =
        error.toString();

    if (message.startsWith(
      'Exception:',
    )) {
      message =
          message.substring(10).trim();
    }

    return message;
  }

  String _formatSelectedDate() {
    return '${_selectedDate.day}/'
        '${_selectedDate.month}/'
        '${_selectedDate.year}';
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
              isError
                  ? Colors.red
                  : darkBrown,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar: AppBar(
        backgroundColor:
            darkBrown,
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: const Text(
          'Schedule Appointment',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: _loadingNutritionists
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : _buildForm(),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a Nutritionist',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          if (_nutritionists.isEmpty)
            _buildNoNutritionists()
          else
            ..._nutritionists.map(
              (item) =>
                  _buildNutritionistCard(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              ),
            ),

          if (_selectedNutritionist !=
              null) ...[
            const SizedBox(
              height: 22,
            ),

            const Text(
              'Select Date',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            InkWell(
              onTap: _selectDate,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              child: Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(
                  15,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_month_rounded,
                      color: darkBrown,
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Expanded(
                      child: Text(
                        _formatSelectedDate(),
                        style:
                            const TextStyle(
                          color:
                              textDark,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons
                          .arrow_drop_down_rounded,
                      color:
                          textMuted,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Available Times',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Each consultation is 30 minutes.',
              style: TextStyle(
                color: textMuted,
                fontSize: 11.5,
              ),
            ),

            const SizedBox(
              height: 11,
            ),

            _buildTimeSlots(),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Notes (Optional)',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  _notesController,
              maxLines: 4,
              decoration:
                  InputDecoration(
                hintText:
                    'Tell the nutritionist what you would like to discuss...',
                filled: true,
                fillColor:
                    Colors.white,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  borderSide:
                      const BorderSide(
                    color:
                        borderColor,
                  ),
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  borderSide:
                      const BorderSide(
                    color:
                        borderColor,
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  borderSide:
                      const BorderSide(
                    color:
                        darkBrown,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _booking
                        ? null
                        : _bookAppointment,
                icon: _booking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .check_circle_outline_rounded,
                      ),
                label: Text(
                  _booking
                      ? 'SCHEDULING...'
                      : 'CONFIRM APPOINTMENT',
                ),
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      darkBrown,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 15,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
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
          ],
        ],
      ),
    );
  }

  // ============================================================
  // NUTRITIONIST CARD
  // ============================================================

  Widget _buildNutritionistCard(
    Map<String, dynamic> nutritionist,
  ) {
    final id =
        nutritionist['id']
            ?.toString();

    final selected =
        _selectedNutritionist?['id']
                ?.toString() ==
            id;

    final name =
        nutritionist['name']
                ?.toString() ??
            nutritionist[
                    'userName']
                ?.toString() ??
            'Nutritionist';

    final email =
        nutritionist['email']
                ?.toString() ??
            '';

    final bio =
        nutritionist['bio']
                ?.toString() ??
            '';

    final credentials =
        nutritionist[
                    'credentials']
                ?.toString() ??
            '';

    final rate =
        nutritionist[
            'hourlyRateEtb'];

    final specializations =
        nutritionist[
            'specializations'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNutritionist =
              nutritionist;
          _selectedTime = null;
          _availableSlots = [];
        });

        _loadAvailableSlots();
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 11,
        ),
        padding:
            const EdgeInsets.all(
          15,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border: Border.all(
            color: selected
                ? darkBrown
                : borderColor,
            width:
                selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      darkBrown
                          .withOpacity(
                    .08,
                  ),
                  child:
                      const Icon(
                    Icons
                        .person_rounded,
                    color:
                        darkBrown,
                  ),
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name,
                        style:
                            const TextStyle(
                          color:
                              textDark,
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      if (credentials
                          .isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 3,
                          ),
                          child: Text(
                            credentials,
                            style:
                                const TextStyle(
                              color:
                                  textMuted,
                              fontSize:
                                  10.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Icon(
                  selected
                      ? Icons
                          .check_circle_rounded
                      : Icons
                          .radio_button_unchecked,
                  color:
                      selected
                          ? darkBrown
                          : textMuted,
                ),
              ],
            ),

            if (bio.isNotEmpty) ...[
              const SizedBox(
                height: 11,
              ),
              Text(
                bio,
                style:
                    const TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],

            if (specializations
                is List &&
                specializations
                    .isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    specializations
                        .map(
                          (item) =>
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  8,
                              vertical:
                                  5,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  background,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child: Text(
                              item.toString(),
                              style:
                                  const TextStyle(
                                color:
                                    brown,
                                fontSize:
                                    9,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],

            if (rate != null) ...[
              const SizedBox(
                height: 10,
              ),
              Text(
                'Rate: $rate ETB/hour',
                style:
                    const TextStyle(
                  color: textDark,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIME SLOTS
  // ============================================================

  Widget _buildTimeSlots() {
    if (_loadingSlots) {
      return const Padding(
        padding:
            EdgeInsets.all(20),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_availableSlots.isEmpty) {
      return Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(
          20,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons
                  .event_busy_rounded,
              color: textMuted,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'No available time slots',
              style: TextStyle(
                color: textDark,
                fontWeight:
                    FontWeight.w800,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try selecting another date.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children:
          _availableSlots.map(
        (slot) {
          final selected =
              _selectedTime ==
                  slot;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTime =
                    slot;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              decoration:
                  BoxDecoration(
                color: selected
                    ? darkBrown
                    : Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  11,
                ),
                border: Border.all(
                  color: selected
                      ? darkBrown
                      : borderColor,
                ),
              ),
              child: Text(
                slot,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : textDark,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // EMPTY / ERROR
  // ============================================================

  Widget _buildNoNutritionists() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const Text(
        'No approved nutritionists are currently available.',
        textAlign:
            TextAlign.center,
        style: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'Unable to load nutritionists',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _error ??
                  'Unknown error.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton.icon(
              onPressed:
                  _loadNutritionists,
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