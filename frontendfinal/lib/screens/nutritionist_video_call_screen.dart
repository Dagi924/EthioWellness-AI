import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class NutritionistVideoCallScreen extends StatefulWidget {
  final String roomName;
  final String participantName;
  final String? participantEmail;
  final String appointmentId;
  final DateTime scheduledAt;
  final DateTime? endsAt;

  const NutritionistVideoCallScreen({
    super.key,
    required this.roomName,
    required this.participantName,
    this.participantEmail,
    required this.appointmentId,
    required this.scheduledAt,
    this.endsAt,
  });

  @override
  State<NutritionistVideoCallScreen> createState() =>
      _NutritionistVideoCallScreenState();
}

class _NutritionistVideoCallScreenState
    extends State<NutritionistVideoCallScreen> {
  final JitsiMeet _jitsiMeet = JitsiMeet();

  Timer? _timer;

  bool _canJoin = false;
  bool _meetingEnded = false;
  bool _joining = false;

  Duration _remaining = Duration.zero;

  static const Color darkBrown = Color(0xFF4A2411);
  static const Color primaryBrown = Color(0xFF7A3E1D);
  static const Color background = Color(0xFFF9F6F0);
  static const Color lightLinen = Color(0xFFFBF8F3);
  static const Color lightLinenBorder = Color(0xFFE6DACD);
  static const Color textDark = Color(0xFF2C1810);
  static const Color textMuted = Color(0xFF7C6D65);

  @override
  void initState() {
    super.initState();

    _updateAvailability();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateAvailability(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateAvailability() {
    if (!mounted) return;

    final now = DateTime.now();

    final start = widget.scheduledAt.toLocal();

    final end = widget.endsAt?.toLocal() ??
        start.add(const Duration(minutes: 30));

    final canJoin = !now.isBefore(start) && now.isBefore(end);
    final ended = !now.isBefore(end);

    Duration remaining;

    if (now.isBefore(start)) {
      remaining = start.difference(now);
    } else if (now.isBefore(end)) {
      remaining = end.difference(now);
    } else {
      remaining = Duration.zero;
    }

    setState(() {
      _canJoin = canJoin;
      _meetingEnded = ended;

      if (!_joining) {
        _remaining = remaining;
      }
    });
  }

  Future<void> _joinMeeting() async {
    if (!_canJoin || _meetingEnded || _joining) {
      return;
    }

    setState(() {
      _joining = true;
    });

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.jit.si',
      room: widget.roomName,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': 'EthioWellness  Consultation',
      },
      featureFlags: {
        'unsaferoomwarning.enabled': false,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: widget.participantName,
        email: widget.participantEmail,
      ),
    );

    final listener = JitsiMeetEventListener(
      conferenceWillJoin: (url) {
        debugPrint(
          'Jitsi conference will join: $url',
        );
      },
      conferenceJoined: (url) {
        debugPrint(
          'Jitsi conference joined: $url',
        );

        if (mounted) {
          setState(() {
            _joining = false;
          });
        }
      },
      conferenceTerminated: (url, error) {
        debugPrint(
          'Jitsi conference terminated: $url '
          'error=$error',
        );

        if (mounted) {
          setState(() {
            _joining = false;
          });

          _updateAvailability();
        }
      },
      participantJoined: (
        email,
        name,
        role,
        participantId,
      ) {
        debugPrint(
          'Participant joined: $name '
          '($email)',
        );
      },
      participantLeft: (participantId) {
        debugPrint(
          'Participant left: $participantId',
        );
      },
    );

    try {
      await _jitsiMeet.join(
        options,
        listener,
      );

      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _joining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to join consultation: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }

    return '${minutes}m ${seconds}s';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} ${date.day}, '
        '${date.year} • $hour:$minute $period';
  }

  Widget _buildStatusCard() {
    if (_meetingEnded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: lightLinen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lightLinenBorder,
          ),
        ),
        child: const Text(
          'This consultation time has ended.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textMuted,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lightLinen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lightLinenBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            _canJoin
                ? 'Consultation is currently active'
                : 'Join becomes available at the scheduled time',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (!_canJoin)
            Text(
              _formatCountdown(_remaining),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: darkBrown,
              ),
            )
          else
            const Text(
              'You can join now',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    final enabled = _canJoin && !_meetingEnded && !_joining;

    String buttonText;

    if (_meetingEnded) {
      buttonText = 'CONSULTATION ENDED';
    } else if (_joining) {
      buttonText = 'OPENING CONSULTATION...';
    } else if (_canJoin) {
      buttonText = 'JOIN CONSULTATION';
    } else {
      buttonText = 'NOT AVAILABLE YET';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? _joinMeeting : null,
        icon: _joining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : const Icon(
                Icons.video_call_rounded,
              ),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBrown,
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nutrition Consultation',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: lightLinen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: lightLinenBorder,
                      ),
                    ),
                    child: Icon(
                      _meetingEnded
                          ? Icons.check_circle_outline_rounded
                          : _canJoin
                              ? Icons.video_camera_front_rounded
                              : Icons.schedule_rounded,
                      size: 42,
                      color: _meetingEnded
                          ? Colors.green.shade700
                          : primaryBrown,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    _meetingEnded
                        ? 'Consultation Ended'
                        : _canJoin
                            ? 'Consultation Is Ready'
                            : 'Consultation Scheduled',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.participantName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryBrown,
                    ),
                  ),

                  if (widget.participantEmail != null &&
                      widget.participantEmail!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.participantEmail!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  Text(
                    _formatDate(
                      widget.scheduledAt.toLocal(),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textMuted,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _buildStatusCard(),

                  const SizedBox(height: 24),

                  _buildJoinButton(),

                  const SizedBox(height: 16),

                  Text(
                    'Appointment ID: ${widget.appointmentId}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
