import 'package:flutter/material.dart';
import '../services/fasting_service.dart';

class FastingCalendar extends StatefulWidget {
  const FastingCalendar({super.key});

  @override
  State<FastingCalendar> createState() => _FastingCalendarState();
}

class _FastingCalendarState extends State<FastingCalendar> {
  static const Color brown = Color(0xFF542E13);
  static const Color border = Color(0xFFEADBCE);
  static const Color muted = Color(0xFF78716C);

  late DateTime _today;
  late DateTime _month;
  DateTime? _selectedDate;

  // Used until the user's saved profile preference is loaded.
  String _religion = 'both';
  String? _profilePractice;

  Map<String, dynamic>? _calendar;
  bool _loading = true;
  bool _profileLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Start on today's date and month.
    _today = DateTime.now();
    _month = DateTime(_today.year, _today.month);
    _selectedDate = DateTime(_today.year, _today.month, _today.day);

    _initialize();
  }

  Future<void> _initialize() async {
    await _loadProfilePractice();
    if (!mounted) return;
    await _loadCalendar();
  }

  /// Fetch the user's saved fasting practice from their profile.
  ///
  /// Connect this to the actual profile method in FastingService.
  Future<void> _loadProfilePractice() async {
    try {
      // TODO: Replace this with your real profile API method.
      //
      // Example:
      // final profile = await FastingService.getUserProfile();
      // final practice = profile['fastingPractice'] ??
      //     profile['fasting_practice'] ??
      //     profile['fastingPreference'];
      //
      // _applyProfilePractice(practice);

      // Keep the current default if the profile has not been connected.
    } catch (_) {
      // Allow the calendar to load even if profile retrieval fails.
    } finally {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  void _applyProfilePractice(dynamic practice) {
    if (practice == null) return;

    final value = practice.toString().trim().toLowerCase();
    if (value.isEmpty) return;

    String selected;

    if ([
      'orthodox',
      'ethiopian_orthodox',
      'ethiopian orthodox',
      'christian',
    ].contains(value)) {
      selected = 'orthodox';
    } else if ([
      'islam',
      'islamic',
      'muslim',
      'ramadan',
    ].contains(value)) {
      selected = 'islam';
    } else if ([
      'both',
      'all',
      'orthodox_and_islam',
      'orthodox and islam',
    ].contains(value)) {
      selected = 'both';
    } else {
      // Do not silently map an unknown profile value to another religion.
      _profilePractice = practice.toString();
      return;
    }

    _profilePractice = practice.toString();
    _religion = selected;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadCalendar() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FastingService.getMonthlyCalendar(
        _month.year,
        _month.month,
        religion: _religion,
      );

      if (!mounted) return;

      setState(() {
        _calendar = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);

      // Select today when navigating back to the current month.
      // Otherwise select the first day of the viewed month.
      if (_month.year == _today.year &&
          _month.month == _today.month) {
        _selectedDate = DateTime(
          _today.year,
          _today.month,
          _today.day,
        );
      } else {
        _selectedDate = DateTime(_month.year, _month.month, 1);
      }
    });

    _loadCalendar();
  }

  void _goToToday() {
    setState(() {
      _today = DateTime.now();
      _month = DateTime(_today.year, _today.month);
      _selectedDate = DateTime(
        _today.year,
        _today.month,
        _today.day,
      );
    });

    _loadCalendar();
  }

  List<Map<String, dynamic>> get _days {
    final raw = _calendar?['days'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _dayData(DateTime date) {
    final key = _dateKey(date);

    for (final day in _days) {
      final gregorian = day['gregorian'];
      final dateValue = day['date'] ??
          day['gregorianDate'] ??
          (gregorian is Map ? gregorian['date'] : null);

      if (dateValue?.toString().startsWith(key) ?? false) {
        return day;
      }
    }

    return null;
  }

  bool _flagIsTrue(dynamic value) {
    if (value == true) return true;
    if (value is num) return value == 1;
    if (value is String) {
      return ['true', '1', 'yes'].contains(value.toLowerCase());
    }
    return false;
  }

  bool _isFasting(Map<String, dynamic>? day) {
    if (day == null) return false;

    if (_flagIsTrue(day['isFasting']) ||
        _flagIsTrue(day['is_fasting']) ||
        _flagIsTrue(day['fasting'])) {
      return true;
    }

    final schedules = day['schedules'];

    if (schedules is Map) {
      return schedules.values.any((value) {
        if (value is Map) {
          return _flagIsTrue(value['isFasting']) ||
              _flagIsTrue(value['is_fasting']) ||
              _flagIsTrue(value['fasting']);
        }
        return false;
      });
    }

    return false;
  }

  List<Map<String, dynamic>> _scheduleDetails(
    Map<String, dynamic>? day,
  ) {
    if (day == null) return [];

    final result = <Map<String, dynamic>>[];
    final schedules = day['schedules'];

    if (schedules is Map) {
      for (final entry in schedules.entries) {
        final value = entry.value;

        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          item.putIfAbsent('religion', () => entry.key);
          result.add(item);
        }
      }
    }

    if (result.isEmpty) {
      result.add(day);
    }

    return result;
  }

  String _label(Map<String, dynamic> item) {
    final value = item['name'] ??
        item['title'] ??
        item['fastName'] ??
        item['fast_name'] ??
        item['period'] ??
        item['religion'] ??
        'Fasting day';

    return value.toString();
  }

  String _duration(Map<String, dynamic> item) {
    final direct = item['duration'] ??
        item['durationText'] ??
        item['fastingDuration'];

    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }

    final start = item['startTime'] ??
        item['start_time'] ??
        item['fajr'];

    final end = item['endTime'] ??
        item['end_time'] ??
        item['maghrib'];

    if (start == null || end == null) {
      return 'Duration unavailable';
    }

    final startMinutes = _minutes(start.toString());
    final endMinutes = _minutes(end.toString());

    if (startMinutes == null || endMinutes == null) {
      return 'From $start to $end';
    }

    var difference = endMinutes - startMinutes;
    if (difference < 0) difference += 24 * 60;

    return '${difference ~/ 60}h ${difference % 60}m';
  }

  int? _minutes(String time) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);

    if (hour == null ||
        minute == null ||
        hour > 23 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  String _prettyReligion(String value) {
    switch (value.toLowerCase()) {
      case 'orthodox':
      case 'ethiopian_orthodox':
      case 'ethiopian orthodox':
        return 'Ethiopian Orthodox';
      case 'islam':
      case 'islamic':
      case 'muslim':
        return 'Islamic';
      default:
        return value;
    }
  }

  String get _todayStatus {
    if (_loading) return 'Checking today’s fasting status…';
    if (_error != null) return 'Today’s fasting status is unavailable.';

    final todayData = _dayData(_today);

    if (todayData == null) {
      return 'No fasting schedule is available for today.';
    }

    if (_isFasting(todayData)) {
      final details = _scheduleDetails(todayData);
      final names = details
          .where((item) =>
              _flagIsTrue(item['isFasting']) ||
              _flagIsTrue(item['is_fasting']) ||
              _flagIsTrue(item['fasting']) ||
              details.length == 1)
          .map(_label)
          .toSet()
          .toList();

      return names.isEmpty
          ? 'Today is a fasting day.'
          : 'Today is a fasting day: ${names.join(', ')}';
    }

    return 'No fasting day is listed for today.';
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday;
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;

    final selected = _selectedDate == null
        ? null
        : _dayData(_selectedDate!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EBE1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: brown,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fasting Calendar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    Text(
                      'Ethiopian Orthodox and Islamic fasts',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Go to today',
                onPressed: _loading ? null : _goToToday,
                icon: const Icon(Icons.today_rounded),
              ),
              IconButton(
                tooltip: 'Refresh calendar',
                onPressed: _loading ? null : _loadCalendar,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Today's fasting status.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE0A8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.spa_rounded,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today’s Fasting Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: brown,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _todayStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF78350F),
                        ),
                      ),
                      if (_profilePractice != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Profile practice: $_profilePractice',
                          style: const TextStyle(
                            fontSize: 11,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _religion,
            decoration: const InputDecoration(
              labelText: 'Fasting tradition',
              prefixIcon: Icon(Icons.filter_list_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'both',
                child: Text('Both traditions'),
              ),
              DropdownMenuItem(
                value: 'orthodox',
                child: Text('Ethiopian Orthodox'),
              ),
              DropdownMenuItem(
                value: 'islam',
                child: Text('Islamic'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _religion = value);
              _loadCalendar();
            },
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: _loading ? null : () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthName(_month.month)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: brown,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _loading ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Row(
            children: [
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri'),
              _WeekdayLabel('Sat'),
              _WeekdayLabel('Sun'),
            ],
          ),

          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: brown),
              ),
            )
          else if (_error != null)
            _message(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load the fasting calendar.',
              detail: _error!,
              retry: _loadCalendar,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  ((firstWeekday - 1 + daysInMonth + 6) ~/ 7) * 7,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - (firstWeekday - 1) + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date =
                    DateTime(_month.year, _month.month, dayNumber);
                final data = _dayData(date);
                final fasting = _isFasting(data);
                final isSelected = _selectedDate != null &&
                    _dateKey(date) == _dateKey(_selectedDate!);
                final isToday = _dateKey(date) == _dateKey(_today);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brown
                          : fasting
                              ? const Color(0xFFFFE8C2)
                              : isToday
                                  ? const Color(0xFFF5EBE1)
                                  : const Color(0xFFFAFAF9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? brown
                            : isToday
                                ? const Color(0xFFB45309)
                                : const Color(0xFFE7E5E4),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight:
                                fasting || isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            color: isSelected ? Colors.white : brown,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fasting
                                ? (isSelected
                                    ? Colors.white
                                    : const Color(0xFFD97706))
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 12),

          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _Legend(
                color: Color(0xFFD97706),
                label: 'Fasting day',
              ),
              _Legend(color: brown, label: 'Selected day'),
              _Legend(
                color: Color(0xFFB45309),
                label: 'Today',
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: border),
          const SizedBox(height: 8),

          Text(
            _selectedDate == null
                ? 'Select a day'
                : '${_monthName(_selectedDate!.month)} '
                    '${_selectedDate!.day}, ${_selectedDate!.year}'
                    '${_dateKey(_selectedDate!) == _dateKey(_today) ? ' · Today' : ''}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: brown,
            ),
          ),

          const SizedBox(height: 10),

          if (_selectedDate != null &&
              selected != null &&
              _isFasting(selected)) ...[
            ..._scheduleDetails(selected).map((item) {
              final religion = _prettyReligion(
                (item['religion'] ?? '').toString(),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE0A8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.spa_rounded,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _label(item),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (religion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        religion,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _duration(item),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    if ((item['description'] ?? item['advice']) != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        (item['description'] ?? item['advice']).toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E5E4)),
              ),
              child: Text(
                selected == null
                    ? 'No schedule details were returned for this date.'
                    : 'No fasting day is listed for this date.',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ),

          if (_calendar?['apiStatus'] is Map) ...[
            const SizedBox(height: 10),
            const Text(
              'Schedule source status',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: muted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              (_calendar!['apiStatus'] as Map).entries
                  .map(
                    (e) =>
                        '${_prettyReligion(e.key.toString())}: ${e.value}',
                  )
                  .join('\n'),
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String text,
    required String detail,
    required VoidCallback retry,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: muted),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
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
    return names[month - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF78716C),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF78716C),
          ),
        ),
      ],
    );
  }
}
