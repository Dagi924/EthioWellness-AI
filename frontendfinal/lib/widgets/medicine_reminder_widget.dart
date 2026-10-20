import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MedicineReminderWidget extends StatefulWidget {
  const MedicineReminderWidget({super.key});

  @override
  State<MedicineReminderWidget> createState() =>
      _MedicineReminderWidgetState();
}

class _MedicineReminderWidgetState extends State<MedicineReminderWidget>
    with WidgetsBindingObserver {
  static const String _storageKey =
      'ethio_wellness_medicine_reminders_v1';

  final TextEditingController _searchController =
      TextEditingController();

  final TextEditingController _instructionsController =
      TextEditingController();

  final TextEditingController _durationController =
      TextEditingController(text: '7');

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _searchResults = [];

  String? _selectedName;
  String? _selectedRxCui;

  DateTime _startDate = DateUtils.dateOnly(DateTime.now());

  int _frequency = 1;
  bool _searching = false;
  bool _saving = false;
  bool _ready = false;

  List<TimeOfDay> _times = [
    const TimeOfDay(hour: 8, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Timezone configuration is used for native notifications.
      if (!kIsWeb) {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(
          tz.getLocation('Africa/Addis_Ababa'),
        );

        const settings = InitializationSettings(
          android: AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          ),
          iOS: DarwinInitializationSettings(),
        );

        await _notifications.initialize(
          settings: settings,
        );

        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      }

      // Load locally saved medicines on web and mobile.
      await _loadAndRefresh();

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Medicine reminder initialization failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      // Keep local medicine management available if notification
      // initialization fails.
      await _loadAndRefresh();

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAndRefresh();
    }
  }

  // ----------------------------------------------------------
  // LOCAL JSON STORAGE
  // ----------------------------------------------------------

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(_medicines),
    );
  }

  Future<void> _loadAndRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      List<Map<String, dynamic>> loaded = [];

      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);

          if (decoded is List) {
            loaded = decoded
                .whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();
          }
        } catch (error) {
          debugPrint(
            'Could not decode medicine JSON: $error',
          );
        }
      }

      final today = DateUtils.dateOnly(DateTime.now());

      // Remove courses whose duration has ended.
      loaded.removeWhere((medicine) {
        final start = DateTime.tryParse(
          medicine['startDate']?.toString() ?? '',
        );

        final duration =
            medicine['durationDays'] is num
                ? (medicine['durationDays'] as num).toInt()
                : 0;

        if (start == null || duration <= 0) {
          return true;
        }

        final endExclusive = DateUtils.dateOnly(start).add(
          Duration(days: duration),
        );

        return !today.isBefore(endExclusive);
      });

      _medicines = loaded;

      await _saveLocal();

      // Native notifications only; never invoke the plugin on web.
      if (!kIsWeb) {
        for (final medicine in _medicines) {
          await _scheduleMedicine(medicine);
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint(
        'Could not load medicine reminders: $error',
      );
    }
  }

  // ----------------------------------------------------------
  // MEDICINE SEARCH
  // RxNorm requires internet. Saved records work offline.
  // ----------------------------------------------------------

  Future<void> _searchMedicines(String query) async {
    if (query.trim().length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _searching = true;
      });
    }

    try {
      final uri = Uri.https(
        'rxnav.nlm.nih.gov',
        '/REST/drugs.json',
        {'name': query.trim()},
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Medicine catalog unavailable');
      }

      final dynamic data = jsonDecode(response.body);

      if (data is! Map) {
        throw Exception('Unexpected medicine catalog response');
      }

      final dynamic drugGroup = data['drugGroup'];

      final dynamic conceptGroups =
          drugGroup is Map ? drugGroup['conceptGroup'] : null;

      final groups =
          conceptGroups is List ? conceptGroups : <dynamic>[];

      final unique = <String, Map<String, dynamic>>{};

      for (final group in groups) {
        if (group is! Map) continue;

        final properties = group['conceptProperties'];

        if (properties is! List) continue;

        for (final item in properties) {
          if (item is! Map) continue;

          final name = item['name']?.toString().trim();
          final cui = item['rxcui']?.toString();

          if (name == null || name.isEmpty) continue;

          unique.putIfAbsent(
            name.toLowerCase(),
            () => {
              'name': name,
              'rxnormCui': cui,
            },
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _searchResults = unique.values.take(15).toList();
      });
    } catch (error) {
      debugPrint('Medicine search failed: $error');

      if (!mounted) return;

      setState(() {
        _searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medicine search needs internet. You can still enter a name manually.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // TIME HELPERS
  // ----------------------------------------------------------

  Future<void> _chooseTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );

    if (selected == null || !mounted) return;

    setState(() {
      _times[index] = selected;

      _times.sort((a, b) {
        final aValue = a.hour * 60 + a.minute;
        final bValue = b.hour * 60 + b.minute;

        return aValue.compareTo(bValue);
      });
    });
  }

  void _setFrequency(int? value) {
    if (value == null) return;

    const defaults = [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 13, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
      TimeOfDay(hour: 22, minute: 0),
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 16, minute: 0),
    ];

    setState(() {
      _frequency = value;

      while (_times.length < value) {
        _times.add(defaults[_times.length]);
      }

      if (_times.length > value) {
        _times = _times.take(value).toList();
      }

      _times.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(
          b.hour * 60 + b.minute,
        ),
      );
    });
  }

  int _notificationId(Map<String, dynamic> medicine) {
    return (medicine['notificationBaseId'] as num).toInt();
  }

  int _doseNotificationId(
    int base,
    int day,
    int dose,
  ) {
    return base + day * 10 + dose;
  }

  // ----------------------------------------------------------
  // CANCEL NOTIFICATIONS
  // ----------------------------------------------------------

  Future<void> _cancelMedicineNotifications(
    Map<String, dynamic> medicine,
  ) async {
    if (kIsWeb) return;

    final base = _notificationId(medicine);

    final duration =
        (medicine['durationDays'] as num).toInt();

    final times = medicine['reminderTimes'] as List;

    for (var day = 0; day < duration; day++) {
      for (var dose = 0; dose < times.length; dose++) {
        await _notifications.cancel(
          id: _doseNotificationId(base, day, dose),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // SCHEDULE NOTIFICATIONS
  // ----------------------------------------------------------

  Future<void> _scheduleMedicine(
    Map<String, dynamic> medicine,
  ) async {
    if (kIsWeb) return;

    if (medicine['status'] != 'active') return;

    final start = DateTime.tryParse(
      medicine['startDate']?.toString() ?? '',
    );

    if (start == null) return;

    final duration =
        (medicine['durationDays'] as num).toInt();

    final times = medicine['reminderTimes'] as List;

    final base = _notificationId(medicine);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ethio_wellness_medicines',
        'Medicine reminders',
        channelDescription:
            'Reminders for medicines recorded in EthioWellness',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final today = DateUtils.dateOnly(DateTime.now());

    for (var day = 0; day < duration; day++) {
      final date = DateUtils.dateOnly(start).add(
        Duration(days: day),
      );

      if (date.isBefore(today)) continue;

      for (var dose = 0; dose < times.length; dose++) {
        final parts = times[dose].toString().split(':');

        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);

        if (hour == null ||
            minute == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          continue;
        }

        final scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        if (!scheduled.isAfter(
          tz.TZDateTime.now(tz.local),
        )) {
          continue;
        }

        final name = medicine['medicineName']?.toString() ??
            'your medicine';

        await _notifications.zonedSchedule(
          id: _doseNotificationId(base, day, dose),
          title: 'Medicine reminder',
          body: 'It is time for your recorded medicine: $name.',
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  // ----------------------------------------------------------
  // ADD MEDICINE
  // ----------------------------------------------------------

  Future<void> _addMedicine() async {
    final name =
        (_selectedName ?? _searchController.text).trim();

    final instructions = _instructionsController.text.trim();

    final duration = int.tryParse(
      _durationController.text.trim(),
    );

    if (name.isEmpty ||
        instructions.isEmpty ||
        duration == null ||
        duration < 1 ||
        duration > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a medicine name, prescribed instructions, and a duration from 1 to 365 days.',
          ),
        ),
      );
      return;
    }

    if (_times.length != _frequency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a reminder time for each daily dose.',
          ),
        ),
      );
      return;
    }

    if (!_ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medicine reminder setup is still loading.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final random = Random.secure();

      final base = 100000 +
          random.nextInt(1000000000 - 100000 - 3650);

      final record = <String, dynamic>{
        'notificationBaseId': base,
        'medicineName': name,
        'rxnormCui': _selectedRxCui,
        'prescribedInstructions': instructions,
        'frequencyPerDay': _frequency,
        'durationDays': duration,
        'startDate': DateUtils.dateOnly(_startDate)
            .toIso8601String()
            .split('T')
            .first,
        'reminderTimes': _times.map((time) {
          return '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
        }).toList(),
        'timeZone': 'Africa/Addis_Ababa',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      };

      _medicines.add(record);

      await _saveLocal();

      if (!kIsWeb) {
        await _scheduleMedicine(record);
      }

      if (!mounted) return;

      setState(() {
        _searchController.clear();
        _instructionsController.clear();
        _durationController.text = '7';
        _selectedName = null;
        _selectedRxCui = null;
        _searchResults = [];
        _frequency = 1;
        _times = [
          const TimeOfDay(hour: 8, minute: 0),
        ];
        _startDate = DateUtils.dateOnly(DateTime.now());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Medicine saved on this device. Scheduled notifications require the mobile app.'
                : 'Medicine saved and reminder scheduling requested.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not save medicine: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this medicine or schedule its reminders.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // DELETE MEDICINE
  // ----------------------------------------------------------

  Future<void> _deleteMedicine(
    Map<String, dynamic> medicine,
  ) async {
    try {
      await _cancelMedicineNotifications(medicine);

      _medicines.removeWhere(
        (item) =>
            item['notificationBaseId'] ==
            medicine['notificationBaseId'],
      );

      await _saveLocal();

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Could not delete medicine reminders: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this medicine.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _instructionsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.medication_outlined,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Medicine Reminders',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (!_ready)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Save medicine schedules on this device. '
              'Medicine search requires internet access.',
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Medicine name',
                hintText: 'Search online or type a name offline',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedName = null;
                  _selectedRxCui = null;
                });

                _searchMedicines(value);
              },
            ),

            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];

                    return ListTile(
                      dense: true,
                      title: Text(item['name'] as String),
                      subtitle: const Text('RxNorm catalog'),
                      onTap: () {
                        setState(() {
                          _selectedName = item['name'] as String;
                          _selectedRxCui =
                              item['rxnormCui'] as String?;
                          _searchController.text = _selectedName!;
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Prescribed instructions',
                hintText:
                    'Enter the instructions from your prescriber',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Duration (days)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Reminders per day',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                6,
                (index) => index + 1,
              ).map((value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    value == 1
                        ? 'Once daily'
                        : '$value times daily',
                  ),
                );
              }).toList(),
              onChanged: _setFrequency,
            ),

            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(
                '${_startDate.year}-'
                '${_startDate.month.toString().padLeft(2, '0')}-'
                '${_startDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final today = DateUtils.dateOnly(DateTime.now());

                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate.isBefore(today)
                      ? today
                      : _startDate,
                  firstDate: today,
                  lastDate: today.add(
                    const Duration(days: 365),
                  ),
                );

                if (date != null && mounted) {
                  setState(() {
                    _startDate = DateUtils.dateOnly(date);
                  });
                }
              },
            ),

            Text(
              'Reminder times',
              style: theme.textTheme.titleMedium,
            ),

            ...List.generate(_times.length, (index) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Reminder ${index + 1}'),
                subtitle: Text(_times[index].format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _chooseTime(index),
              );
            }),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _saving || !_ready ? null : _addMedicine,
                icon: const Icon(Icons.add),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : 'Save medicine & reminders',
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Saved medicines',
              style: theme.textTheme.titleLarge,
            ),

            if (_medicines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No active medicines recorded.',
                  ),
                ),
              ),

            ..._medicines.map((medicine) {
              final rawTimes = medicine['reminderTimes'];
              final times = rawTimes is List
                  ? rawTimes.join(', ')
                  : 'Not specified';

              final name =
                  medicine['medicineName']?.toString() ??
                      'Unnamed medicine';

              final instructions =
                  medicine['prescribedInstructions']?.toString() ??
                      'No instructions recorded';

              final frequency =
                  medicine['frequencyPerDay']?.toString() ?? '?';

              final duration =
                  medicine['durationDays']?.toString() ?? '?';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.medication),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '$instructions\n'
                    '$frequency reminder(s)/day · $duration days\n'
                    'Times: $times',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete medicine',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteMedicine(medicine),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
