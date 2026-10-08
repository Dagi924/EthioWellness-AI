
import 'package:flutter/material.dart';

import '../services/food_log_service.dart';
import '../services/exercise_service.dart';
import '../services/fasting_service.dart';
import '../services/sleep_service.dart';
import '../services/mood_service.dart';
import '../models/fasting_schedule_model.dart';

import 'food_scanner_screen.dart';
import 'food_search_screen.dart';
import 'chapa_payment_screen.dart';
import 'nutritionist_screen.dart';
import 'ai_chat_screen.dart';

class MealLoggerScreen extends StatefulWidget {
  const MealLoggerScreen({super.key});

  @override
  State<MealLoggerScreen> createState() => _MealLoggerScreenState();
}

class _MealLoggerScreenState extends State<MealLoggerScreen> {
  Map<String, dynamic>? _todayData;
  FastingScheduleModel? _fastingStatus;

  List<Map<String, dynamic>> _todayExercises = [];

  Map<String, dynamic>? _todaySleep;
  List<Map<String, dynamic>> _todayMood = [];

  bool _isLoading = true;

  final TextEditingController _searchController =
      TextEditingController();

  String _foodSearch = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD REAL DASHBOARD DATA
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final logsRes = await FoodLogService.getTodayLogs();

      List<Map<String, dynamic>> exerciseData = [];

      try {
        final exerciseRes =
            await ExerciseService.getTodayExercises();

        final rawExercises = exerciseRes['exercises'];

        if (rawExercises is List) {
          exerciseData = rawExercises
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (_) {
        // Exercise is independent.
      }

      FastingScheduleModel? fastingData;

      try {
        fastingData =
            await FastingService.getTodayFasting();
      } catch (_) {
        // Fasting is optional.
      }

      Map<String, dynamic>? sleepData;

      try {
        sleepData =
            await SleepService.getTodaySleep();
      } catch (_) {
        // Sleep is optional.
      }

      List<Map<String, dynamic>> moodData = [];

      try {
        moodData =
            await MoodService.getTodayMood();
      } catch (_) {
        // Mood is optional.
      }

      if (!mounted) return;

      setState(() {
        _todayData = logsRes;
        _todayExercises = exerciseData;
        _fastingStatus = fastingData;
        _todaySleep = sleepData;
        _todayMood = moodData;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load dashboard: $e',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // WATER
  // ============================================================

  Future<void> _showWaterLogger() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveWater() async {
              final amount = double.tryParse(
                controller.text.trim(),
              );

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a valid water amount in ml.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                await FoodLogService.logWater(amount);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Water intake logged successfully.',
                      ),
                      backgroundColor: Color(0xFF0284C7),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  saving = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to log water: $e',
                      ),
                      backgroundColor:
                          const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 10),
                  Text('Log Water'),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: TextField(
                  controller: controller,
                  enabled: !saving,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    suffixText: 'ml',
                    prefixIcon: Icon(
                      Icons.local_drink_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : saveWater,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    saving ? 'Saving...' : 'Log Water',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // SLEEP LOGGER
  // ============================================================

  Future<void> _showSleepLogger() async {
    TimeOfDay? bedtime;
    TimeOfDay? wakeTime;

    int selectedDuration = 8 * 60;
    int quality = 3;

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectBedtime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    bedtime ??
                    const TimeOfDay(
                      hour: 22,
                      minute: 0,
                    ),
              );

              if (picked != null) {
                setDialogState(() {
                  bedtime = picked;
                });
              }
            }

            Future<void> selectWakeTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    wakeTime ??
                    const TimeOfDay(
                      hour: 6,
                      minute: 0,
                    ),
              );

              if (picked != null) {
                setDialogState(() {
                  wakeTime = picked;
                });
              }
            }

            void selectHourRange(int minutes) {
              setDialogState(() {
                selectedDuration = minutes;
              });
            }

            Future<void> saveSleep() async {
              if (bedtime == null ||
                  wakeTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Select both bedtime and wake time.',
                    ),
                  ),
                );
                return;
              }

              final now = DateTime.now();

              DateTime bedtimeDate = DateTime(
                now.year,
                now.month,
                now.day,
                bedtime!.hour,
                bedtime!.minute,
              );

              DateTime wakeTimeDate = DateTime(
                now.year,
                now.month,
                now.day,
                wakeTime!.hour,
                wakeTime!.minute,
              );

              if (!wakeTimeDate.isAfter(bedtimeDate)) {
                wakeTimeDate =
                    wakeTimeDate.add(
                  const Duration(days: 1),
                );
              }

              final calculatedDuration =
                  wakeTimeDate
                      .difference(bedtimeDate)
                      .inMinutes;

              setDialogState(() {
                selectedDuration =
                    calculatedDuration;
                isSaving = true;
              });

              try {
                await SleepService.saveSleep(
                  sleepDate:
                      _dateOnly(now),
                  bedtime: bedtimeDate,
                  wakeTime: wakeTimeDate,
                  durationMinutes:
                      calculatedDuration,
                  quality: quality,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        '😴 Sleep logged successfully.',
                      ),
                      backgroundColor:
                          Color(0xFF6D4C41),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  isSaving = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to log sleep: $e',
                      ),
                      backgroundColor:
                          const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.bedtime_rounded,
                    color: Color(0xFF6D4C41),
                  ),
                  SizedBox(width: 10),
                  Text('Log Sleep'),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'How long did you sleep?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _sleepRangeButton(
                            label: '< 5h',
                            minutes: 270,
                            selected:
                                selectedDuration < 300,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(270),
                          ),
                          _sleepRangeButton(
                            label: '5–6h',
                            minutes: 330,
                            selected:
                                selectedDuration >=
                                    300 &&
                                selectedDuration < 360,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(330),
                          ),
                          _sleepRangeButton(
                            label: '6–7h',
                            minutes: 390,
                            selected:
                                selectedDuration >=
                                    360 &&
                                selectedDuration < 420,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(390),
                          ),
                          _sleepRangeButton(
                            label: '7–8h',
                            minutes: 450,
                            selected:
                                selectedDuration >=
                                    420 &&
                                selectedDuration < 480,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(450),
                          ),
                          _sleepRangeButton(
                            label: '8–9h',
                            minutes: 510,
                            selected:
                                selectedDuration >=
                                    480 &&
                                selectedDuration < 540,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(510),
                          ),
                          _sleepRangeButton(
                            label: '9h+',
                            minutes: 600,
                            selected:
                                selectedDuration >= 540,
                            enabled: !isSaving,
                            onTap: () =>
                                selectHourRange(600),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Sleep times',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  isSaving
                                      ? null
                                      : selectBedtime,
                              icon: const Icon(
                                Icons.nightlight_round,
                              ),
                              label: Text(
                                bedtime == null
                                    ? 'Bedtime'
                                    : bedtime!.format(
                                        context,
                                      ),
                              ),
                              style:
                                  OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  isSaving
                                      ? null
                                      : selectWakeTime,
                              icon: const Icon(
                                Icons.wb_sunny_outlined,
                              ),
                              label: Text(
                                wakeTime == null
                                    ? 'Wake time'
                                    : wakeTime!.format(
                                        context,
                                      ),
                              ),
                              style:
                                  OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Sleep quality',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _sleepQualityButton(
                            emoji: '😴',
                            label: 'Poor',
                            value: 1,
                            selected: quality == 1,
                            enabled: !isSaving,
                            onTap: () {
                              setDialogState(() {
                                quality = 1;
                              });
                            },
                          ),
                          _sleepQualityButton(
                            emoji: '😕',
                            label: 'Low',
                            value: 2,
                            selected: quality == 2,
                            enabled: !isSaving,
                            onTap: () {
                              setDialogState(() {
                                quality = 2;
                              });
                            },
                          ),
                          _sleepQualityButton(
                            emoji: '😐',
                            label: 'Okay',
                            value: 3,
                            selected: quality == 3,
                            enabled: !isSaving,
                            onTap: () {
                              setDialogState(() {
                                quality = 3;
                              });
                            },
                          ),
                          _sleepQualityButton(
                            emoji: '🙂',
                            label: 'Good',
                            value: 4,
                            selected: quality == 4,
                            enabled: !isSaving,
                            onTap: () {
                              setDialogState(() {
                                quality = 4;
                              });
                            },
                          ),
                          _sleepQualityButton(
                            emoji: '🤩',
                            label: 'Great',
                            value: 5,
                            selected: quality == 5,
                            enabled: !isSaving,
                            onTap: () {
                              setDialogState(() {
                                quality = 5;
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (bedtime != null &&
                          wakeTime != null)
                        Container(
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF5F0ED),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timelapse_rounded,
                                color:
                                    Color(0xFF6D4C41),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Calculated sleep: ${_formatDuration(_calculateTimeDifference(bedtime!, wakeTime!))}',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () =>
                          Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isSaving ? null : saveSleep,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.bedtime_rounded,
                        ),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : 'Save Sleep',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF6D4C41),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MOOD LOGGER
  // ============================================================

  Future<void> _showMoodLogger() async {
    int selectedMood = 3;
    String selectedMoodName = 'Okay';

    final noteController = TextEditingController();

    const moods = [
      {
        'score': 1,
        'emoji': '😢',
        'name': 'Very Bad',
      },
      {
        'score': 2,
        'emoji': '😕',
        'name': 'Bad',
      },
      {
        'score': 3,
        'emoji': '😐',
        'name': 'Okay',
      },
      {
        'score': 4,
        'emoji': '🙂',
        'name': 'Good',
      },
      {
        'score': 5,
        'emoji': '😄',
        'name': 'Great',
      },
    ];

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveMood() async {
              setDialogState(() {
                isSaving = true;
              });

              try {
                await MoodService.saveMood(
                  mood: selectedMoodName,
                  moodScore: selectedMood,
                  note: noteController.text.trim(),
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_moodEmoji(selectedMood)} Mood logged successfully.',
                      ),
                      backgroundColor:
                          const Color(0xFF7C3AED),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  isSaving = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to log mood: $e',
                      ),
                      backgroundColor:
                          const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.mood_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                  SizedBox(width: 10),
                  Text('How are you feeling?'),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      alignment:
                          WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: moods.map((item) {
                        final score =
                            item['score'] as int;
                        final emoji =
                            item['emoji'] as String;
                        final name =
                            item['name'] as String;

                        final selected =
                            selectedMood == score;

                        return InkWell(
                          onTap: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedMood =
                                        score;
                                    selectedMoodName =
                                        name;
                                  });
                                },
                          borderRadius:
                              BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration:
                                const Duration(
                              milliseconds: 180,
                            ),
                            width: 70,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(
                                      0xFFF3E8FF,
                                    )
                                  : const Color(
                                      0xFFFAFAF9,
                                    ),
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              border: Border.all(
                                color: selected
                                    ? const Color(
                                        0xFF7C3AED,
                                      )
                                    : const Color(
                                        0xFFE7E5E4,
                                      ),
                                width:
                                    selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  emoji,
                                  style:
                                      const TextStyle(
                                    fontSize: 30,
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  name,
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight:
                                        selected
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .w500,
                                    color: selected
                                        ? const Color(
                                            0xFF6D28D9,
                                          )
                                        : const Color(
                                            0xFF57534E,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      '${_moodEmoji(selectedMood)}  $selectedMoodName',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6D28D9),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: noteController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText:
                            'What is affecting your mood today?',
                        prefixIcon: Padding(
                          padding:
                              EdgeInsets.only(bottom: 40),
                          child: Icon(
                            Icons.edit_note_rounded,
                          ),
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () =>
                          Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isSaving ? null : saveMood,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.favorite_rounded,
                        ),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : 'Save Mood',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  // ============================================================
  // EXERCISE LOGGER
  // ============================================================

  Future<void> _showExerciseLogger() async {
    final workoutController = TextEditingController();
    final durationController = TextEditingController();
    final caloriesController = TextEditingController();

    String intensity = 'Moderate';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveExercise() async {
              final workoutName =
                  workoutController.text.trim();

              final duration = int.tryParse(
                durationController.text.trim(),
              );

              final calories = double.tryParse(
                caloriesController.text.trim(),
              );

              if (workoutName.isEmpty ||
                  duration == null ||
                  duration <= 0 ||
                  calories == null ||
                  calories < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a workout name, valid duration, and calories.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await ExerciseService.logExercise(
                  workoutName: workoutName,
                  durationMinutes: duration,
                  caloriesBurned: calories,
                  intensity: intensity,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exercise logged successfully.',
                      ),
                      backgroundColor:
                          Color(0xFF2E7D32),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  isSaving = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to log exercise: $e',
                      ),
                      backgroundColor:
                          const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                  SizedBox(width: 10),
                  Text('Log Exercise'),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: workoutController,
                        enabled: !isSaving,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Workout',
                          hintText:
                              'e.g. Evening Walk',
                          prefixIcon: Icon(
                            Icons
                                .directions_walk_rounded,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: durationController,
                        enabled: !isSaving,
                        keyboardType:
                            TextInputType.number,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Duration',
                          hintText: 'e.g. 30',
                          suffixText: 'minutes',
                          prefixIcon: Icon(
                            Icons.timer_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: caloriesController,
                        enabled: !isSaving,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction:
                            TextInputAction.done,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Calories Burned',
                          hintText: 'e.g. 120',
                          suffixText: 'kcal',
                          prefixIcon: Icon(
                            Icons
                                .local_fire_department_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: intensity,
                        decoration:
                            const InputDecoration(
                          labelText: 'Intensity',
                          prefixIcon: Icon(
                            Icons.speed_rounded,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Low',
                            child: Text('Low'),
                          ),
                          DropdownMenuItem(
                            value: 'Moderate',
                            child:
                                Text('Moderate'),
                          ),
                          DropdownMenuItem(
                            value: 'High',
                            child: Text('High'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value !=
                                    null) {
                                  setDialogState(() {
                                    intensity =
                                        value;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () =>
                          Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isSaving ? null : saveExercise,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : 'Log Exercise',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    workoutController.dispose();
    durationController.dispose();
    caloriesController.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final rawTotals = _todayData?['totals'];

    final totals = rawTotals is Map
        ? Map<String, dynamic>.from(rawTotals)
        : <String, dynamic>{};

    final rawLogs = _todayData?['logs'];

    final logs = rawLogs is List
        ? rawLogs
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList()
        : <Map<String, dynamic>>[];

    final screenWidth =
        MediaQuery.of(context).size.width;

    final isWide = screenWidth > 860;

    final filteredLogs = _filteredLogs(logs);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EA),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
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
            vertical: 10,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration:
                            const BoxDecoration(
                          color: Color(0xFF542E13),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            'EthioNutri AI',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF542E13),
                            ),
                          ),
                          Text(
                            'Today\'s Nutrition & Wellness',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Color(0xFF78716C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (isWide)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Text(
                      'Food Logging & Wellness',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF8D4F28),
                      ),
                    ),
                  ),

                if (isWide)
                  Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      _circleButton(
                        Icons.chat_bubble_outline_rounded,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AiChatScreen(),
                          ),
                        ),
                        tooltip:
                            'AI Nutrition Chat',
                        badgeColor:
                            const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 7),
                      _circleButton(
                        Icons
                            .workspace_premium_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ChapaPaymentScreen(),
                          ),
                        ),
                        tooltip:
                            'Upgrade to Premium',
                        iconColor:
                            const Color(0xFFB45309),
                        backgroundColor:
                            const Color(0xFFFEF3C7),
                      ),
                      const SizedBox(width: 7),
                      _circleButton(
                        Icons
                            .medical_services_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const NutritionistScreen(),
                          ),
                        ),
                        tooltip:
                            'Dietitian Supervision',
                      ),
                      const SizedBox(width: 7),
                      _circleButton(
                        Icons.camera_alt_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const FoodScannerScreen(),
                          ),
                        ).then(
                          (_) => _loadData(),
                        ),
                        tooltip:
                            'AI Food Scanner',
                      ),
                      const SizedBox(width: 7),
                      _circleButton(
                        Icons.refresh_rounded,
                        _loadData,
                        tooltip:
                            'Refresh Dashboard',
                      ),
                    ],
                  )
                else
                  _circleButton(
                    Icons.refresh_rounded,
                    _loadData,
                    tooltip:
                        'Refresh Dashboard',
                  ),
              ],
            ),
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF542E13),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF542E13),
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    if (!isWide)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Today\'s Wellness',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xFF8D4F28),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.sync,
                                color:
                                    Color(0xFF542E13),
                              ),
                              onPressed:
                                  _loadData,
                            ),
                          ],
                        ),
                      ),

                    _buildSearchFilter(),

                    const SizedBox(height: 16),

                    _buildQuickActionCards(),

                    const SizedBox(height: 20),

                    _buildSleepMoodCard(),

                    const SizedBox(height: 20),

                    _buildTodayExerciseCard(),

                    const SizedBox(height: 20),

                    if (isWide)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            flex: 13,
                            child: Column(
                              children: [
                                if (_fastingStatus !=
                                    null)
                                  _buildFastingBanner(
                                    _fastingStatus!,
                                  ),

                                if (_fastingStatus !=
                                    null)
                                  const SizedBox(
                                    height: 16,
                                  ),

                                _buildFoodLogsCard(
                                  filteredLogs,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 9,
                            child:
                                _buildDailyTotalsCard(
                              totals,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildDailyTotalsCard(
                            totals,
                          ),
                          const SizedBox(height: 16),
                          if (_fastingStatus != null)
                            _buildFastingBanner(
                              _fastingStatus!,
                            ),
                          if (_fastingStatus != null)
                            const SizedBox(height: 16),
                          _buildFoodLogsCard(
                            filteredLogs,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const FoodSearchScreen(),
          ),
        ).then((_) => _loadData()),
        backgroundColor:
            const Color(0xFF542E13),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.search),
        label: const Text(
          'Search FAO Food',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchFilter() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEADBCE),
        ),
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFFA8A29E),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller:
                  _searchController,
              onChanged: (value) {
                setState(() {
                  _foodSearch =
                      value.trim().toLowerCase();
                });
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'Search today\'s logged foods...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController
              .text
              .isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.clear,
                size: 18,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _foodSearch = '';
                });
              },
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredLogs(
    List<Map<String, dynamic>> logs,
  ) {
    if (_foodSearch.isEmpty) {
      return logs;
    }

    return logs.where((log) {
      final foodName =
          (log['foodName'] ?? '')
              .toString()
              .toLowerCase();

      return foodName.contains(
        _foodSearch,
      );
    }).toList();
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActionCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _quickActionCard(
            icon:
                Icons.mic_none_rounded,
            iconBackground:
                const Color(0xFFF5EBE1),
            iconColor:
                const Color(0xFF8D4F28),
            title: 'Voice Log',
            subtitle:
                'AI Speech Transcription',
            onTap: () =>
                Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FoodScannerScreen(),
              ),
            ).then(
              (_) => _loadData(),
            ),
          ),
          _quickActionCard(
            icon:
                Icons.edit_outlined,
            iconBackground:
                const Color(0xFFFDECE3),
            iconColor:
                const Color(0xFF8D4F28),
            title: 'Manual Entry',
            subtitle:
                'Search & Log Food',
            onTap: () =>
                Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FoodSearchScreen(),
              ),
            ).then(
              (_) => _loadData(),
            ),
          ),
          _quickActionCard(
            icon:
                Icons.fitness_center_rounded,
            iconBackground:
                const Color(0xFFE8F5E9),
            iconColor:
                const Color(0xFF2E7D32),
            title: 'Exercise',
            subtitle:
                'Log Today\'s Workout',
            onTap:
                _showExerciseLogger,
          ),
          _quickActionCard(
            icon:
                Icons.bedtime_rounded,
            iconBackground:
                const Color(0xFFF5F0ED),
            iconColor:
                const Color(0xFF6D4C41),
            title: 'Sleep',
            subtitle:
                'Log Sleep Hours',
            onTap:
                _showSleepLogger,
          ),
          _quickActionCard(
            icon:
                Icons.mood_rounded,
            iconBackground:
                const Color(0xFFF3E8FF),
            iconColor:
                const Color(0xFF7C3AED),
            title: 'Mood',
            subtitle:
                'How Are You Feeling?',
            onTap:
                _showMoodLogger,
          ),
        ];

        if (constraints.maxWidth < 650) {
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: cards
                .map(
                  (card) => SizedBox(
                    width:
                        (constraints.maxWidth -
                                14) /
                            2,
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        if (constraints.maxWidth < 1000) {
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: cards
                .map(
                  (card) => SizedBox(
                    width:
                        (constraints.maxWidth -
                                28) /
                            3,
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (int i = 0;
                i < cards.length;
                i++) ...[
              Expanded(
                child: cards[i],
              ),
              if (i != cards.length - 1)
                const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color:
                const Color(0xFFEADBCE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.03),
              blurRadius: 10,
              offset:
                  const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF1C1917),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 12,
                color:
                    Color(0xFF78716C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SLEEP + MOOD CARD
  // ============================================================

  Widget _buildSleepMoodCard() {
    final latestMood =
        _todayMood.isNotEmpty
            ? _todayMood.first
            : null;

    final sleepDuration =
        _todaySleep?['durationMinutes'];

    final sleepQuality =
        _todaySleep?['quality'];

    final sleepMinutes =
        sleepDuration is num
            ? sleepDuration.toInt()
            : 0;

    final moodScore =
        latestMood?['moodScore'];

    final moodName =
        latestMood?['mood']
                ?.toString() ??
            '';

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.03),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFFF5F0ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  color:
                      Color(0xFF6D4C41),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Wellness',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF1C1917),
                      ),
                    ),
                    Text(
                      'Sleep and mood tracking',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          LayoutBuilder(
            builder:
                (context, constraints) {
              final sleepCard =
                  _wellnessSummaryCard(
                icon:
                    Icons.bedtime_rounded,
                emoji: '😴',
                title: 'Sleep',
                value:
                    _todaySleep == null
                        ? 'Not logged'
                        : SleepService
                            .formatDuration(
                            sleepMinutes,
                          ),
                subtitle:
                    _todaySleep == null
                        ? 'Tap to log'
                        : 'Quality ${sleepQuality ?? 3}/5',
                color:
                    const Color(0xFF6D4C41),
                onTap:
                    _showSleepLogger,
              );

              final moodCard =
                  _wellnessSummaryCard(
                icon:
                    Icons.mood_rounded,
                emoji:
                    latestMood == null
                        ? '🙂'
                        : _moodEmoji(
                            moodScore is num
                                ? moodScore
                                    .toInt()
                                : 3,
                          ),
                title: 'Mood',
                value:
                    latestMood == null
                        ? 'Not logged'
                        : moodName,
                subtitle:
                    latestMood == null
                        ? 'Tap to log'
                        : 'Score ${moodScore ?? 3}/5',
                color:
                    const Color(0xFF7C3AED),
                onTap:
                    _showMoodLogger,
              );

              if (constraints.maxWidth <
                  600) {
                return Column(
                  children: [
                    sleepCard,
                    const SizedBox(height: 10),
                    moodCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: sleepCard,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: moodCard,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _wellnessSummaryCard({
    required IconData icon,
    required String emoji,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              const Color(0xFFFAFAF9),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                const Color(0xFFE7E5E4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(
                  0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style:
                      const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: color,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        title,
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF1C1917),
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          Color(0xFF78716C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color:
                  Color(0xFFA8A29E),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXERCISE
  // ============================================================

  Widget _buildTodayExerciseCard() {
    final totalMinutes =
        _todayExercises.fold<int>(
      0,
      (sum, exercise) {
        final value =
            exercise['durationMinutes'];

        return sum +
            (value is num
                ? value.toInt()
                : 0);
      },
    );

    final totalCalories =
        _todayExercises.fold<double>(
      0,
      (sum, exercise) {
        final value =
            exercise['caloriesBurned'];

        return sum +
            (value is num
                ? value.toDouble()
                : 0);
      },
    );

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.03),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .fitness_center_rounded,
                  color:
                      Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Today\'s Exercise',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF1C1917),
                      ),
                    ),
                    Text(
                      'Your activity for today',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
              if (_todayExercises
                  .isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                            0xFFE8F5E9),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Text(
                    '$totalMinutes min',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF2E7D32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_todayExercises.isEmpty)
            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFFAFAF9),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      const Color(
                          0xFFE7E5E4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .directions_run_outlined,
                    color:
                        Color(0xFF78716C),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  const Expanded(
                    child: Text(
                      'No exercise logged today.',
                      style:
                          TextStyle(
                        fontSize: 13,
                        color:
                            Color(
                                0xFF78716C),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        _showExerciseLogger,
                    icon: const Icon(
                      Icons.add,
                      size: 18,
                    ),
                    label:
                        const Text('Log'),
                  ),
                ],
              ),
            )
          else ...[
            ..._todayExercises.map(
              _buildExerciseLogItem,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                Text(
                  '${totalCalories.toStringAsFixed(0)} kcal burned',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed:
                      _showExerciseLogger,
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                  ),
                  label:
                      const Text(
                          'Log More'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseLogItem(
    Map<String, dynamic> exercise,
  ) {
    final name =
        exercise['workoutName']
                ?.toString() ??
            'Exercise';

    final durationValue =
        exercise['durationMinutes'];

    final duration =
        durationValue is num
            ? durationValue.toInt()
            : 0;

    final caloriesValue =
        exercise['caloriesBurned'];

    final calories =
        caloriesValue is num
            ? caloriesValue.toDouble()
            : 0;

    final intensity =
        exercise['intensity']
                ?.toString() ??
            '';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFAFAF9),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE7E5E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .directions_run_rounded,
              color:
                  Color(0xFF2E7D32),
              size: 22,
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
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  intensity.isEmpty
                      ? '$duration min'
                      : '$duration min • $intensity',
                  style:
                      const TextStyle(
                    fontSize: 11.5,
                    color:
                        Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${calories.toStringAsFixed(0)} kcal',
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REAL FOOD LOGS
  // ============================================================

  Widget _buildFoodLogsCard(
    List<Map<String, dynamic>> logs,
  ) {
    final foodLogs = logs.where((log) {
      final logType =
          (log['logType'] ?? '')
              .toString()
              .toLowerCase();

      return logType != 'water';
    }).toList();

    final waterLogs = logs.where((log) {
      final logType =
          (log['logType'] ?? '')
              .toString()
              .toLowerCase();

      return logType == 'water';
    }).toList();

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.03),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                          0xFFF5EBE1),
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: const Icon(
                  Icons
                      .restaurant_menu_rounded,
                  color:
                      Color(0xFF8D4F28),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Today\'s Food Logs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF1C1917),
                      ),
                    ),
                    Text(
                      'Real food entries from your account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const FoodSearchScreen(),
                  ),
                ).then(
                  (_) => _loadData(),
                ),
                icon: const Icon(
                  Icons.add,
                  size: 17,
                ),
                label:
                    const Text('Add Food'),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(
                          0xFF542E13),
                  side:
                      const BorderSide(
                    color:
                        Color(0xFF542E13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (foodLogs.isEmpty)
            _buildEmptyFoodState()
          else
            ...foodLogs.map(
              _buildFoodLogItem,
            ),
          if (waterLogs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                        0xFFF0F9FF),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      const Color(
                          0xFFBAE6FD),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .water_drop_rounded,
                    color:
                        Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_sumWaterLogs(waterLogs)} ml logged as water',
                      style:
                          const TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Color(
                                0xFF075985),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyFoodState() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFAFAF9),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE7E5E4),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_outlined,
            size: 36,
            color:
                Color(0xFFA8A29E),
          ),
          const SizedBox(height: 8),
          const Text(
            'No food logged today.',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF44403C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search for a food or add a meal to see it here.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const FoodSearchScreen(),
              ),
            ).then(
              (_) => _loadData(),
            ),
            icon:
                const Icon(Icons.search),
            label:
                const Text('Search Food'),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogItem(
    Map<String, dynamic> log,
  ) {
    final foodName =
        (log['foodName'] ??
                'Food')
            .toString();

    final portion =
        _number(
      log['portionGrams'],
    );

    final calories =
        _number(log['calories']);

    final protein =
        _number(
      log['proteinGrams'],
    );

    final carbs =
        _number(
      log['carbsGrams'],
    );

    final fats =
        _number(
      log['fatsGrams'],
    );

    final logType =
        (log['logType'] ?? '')
            .toString();

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(13),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFBF8F4),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFEFE8DF),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                          0xFFEADBCE),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color:
                      Color(0xFF8D4F28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      foodName,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 13.5,
                        color:
                            Color(
                                0xFF1C1917),
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      portion > 0
                          ? '${_formatNumber(portion)} g'
                          : logType,
                      style:
                          const TextStyle(
                        fontSize: 11.5,
                        color:
                            Color(
                                0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatNumber(calories)} kcal',
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF8D4F28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _macroBadge(
                '${_formatNumber(protein)}g',
                'P',
                const Color(
                    0xFF8D4F28),
              ),
              _macroBadge(
                '${_formatNumber(carbs)}g',
                'C',
                const Color(
                    0xFF2563EB),
              ),
              _macroBadge(
                '${_formatNumber(fats)}g',
                'F',
                const Color(
                    0xFFD97706),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _sumWaterLogs(
    List<Map<String, dynamic>> logs,
  ) {
    return logs.fold<double>(
      0,
      (sum, log) {
        final value =
            log['waterMl'];

        return sum +
            (value is num
                ? value.toDouble()
                : 0);
      },
    );
  }

  // ============================================================
  // DAILY REAL TOTALS
  // ============================================================

  Widget _buildDailyTotalsCard(
    Map<String, dynamic> totals,
  ) {
    final calories =
        _number(totals['calories']);

    final protein =
        _number(
      totals['proteinGrams'],
    );

    final carbs =
        _number(
      totals['carbsGrams'],
    );

    final fats =
        _number(
      totals['fatsGrams'],
    );

    final water =
        _number(
      totals['waterMl'],
    );

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFEADBCE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.03),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Today\'s Totals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF1C1917),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Actual values from your food logs',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons
                      .water_drop_rounded,
                  color:
                      Color(0xFF0284C7),
                ),
                tooltip:
                    'Log water',
                onPressed:
                    _showWaterLogger,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  _formatNumber(
                      calories),
                  style:
                      const TextStyle(
                    fontSize: 34,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF542E13),
                  ),
                ),
                const Text(
                  'kcal consumed',
                  style:
                      TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment:
                WrapAlignment
                    .spaceAround,
            spacing: 18,
            runSpacing: 18,
            children: [
              _macroProgressItem(
                'Protein',
                '${_formatNumber(protein)}g',
                const Color(
                    0xFF8D4F28),
              ),
              _macroProgressItem(
                'Carbs',
                '${_formatNumber(carbs)}g',
                const Color(
                    0xFF2563EB),
              ),
              _macroProgressItem(
                'Fats',
                '${_formatNumber(fats)}g',
                const Color(
                    0xFFD97706),
              ),
              _macroProgressItem(
                'Water',
                '${_formatNumber(water)}ml',
                const Color(
                    0xFF0284C7),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.all(12),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFFAFAF9),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border: Border.all(
                color:
                    const Color(
                        0xFFE7E5E4),
              ),
            ),
            child: const Text(
              'Nutrition targets are not displayed here because the current API does not provide personalized daily targets.',
              style:
                  TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color:
                    Color(0xFF78716C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroProgressItem(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style:
              const TextStyle(
            fontSize: 11.5,
            color:
                Color(0xFF78716C),
          ),
        ),
      ],
    );
  }

  Widget _macroBadge(
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(0.07),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.bold,
                color: color,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: TextStyle(
                fontSize: 9.5,
                color:
                    color.withOpacity(
                  0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FASTING
  // ============================================================

  Widget _buildFastingBanner(
    FastingScheduleModel fast,
  ) {
    final isFasting =
        fast.displayTitle
            .toLowerCase()
            .contains('fast');

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFEF3C7),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
              const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor:
                    Color(0xFFFDE68A),
                child: Icon(
                  Icons.church_outlined,
                  color:
                      Color(0xFFB45309),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fast.displayTitle,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13.5,
                    color:
                        Color(0xFFB45309),
                  ),
                ),
              ),
              if (isFasting)
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                            0xFF542E13),
                    borderRadius:
                        BorderRadius.circular(
                      6,
                    ),
                  ),
                  child:
                      const Text(
                    'FASTING',
                    style:
                        TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            fast.advice,
            style:
                const TextStyle(
              fontSize: 12,
              height: 1.3,
              color:
                  Color(0xFF78350F),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _dateOnly(DateTime date) {
    final year =
        date.year.toString().padLeft(
              4,
              '0',
            );

    final month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    final day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    return '$year-$month-$day';
  }

  int _calculateTimeDifference(
    TimeOfDay start,
    TimeOfDay end,
  ) {
    int startMinutes =
        start.hour * 60 +
            start.minute;

    int endMinutes =
        end.hour * 60 +
            end.minute;

    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60;
    }

    return endMinutes -
        startMinutes;
  }

  String _formatDuration(
    int minutes,
  ) {
    final hours =
        minutes ~/ 60;

    final remaining =
        minutes % 60;

    if (hours == 0) {
      return '${remaining}m';
    }

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  String _moodEmoji(
    int score,
  ) {
    switch (score) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  Widget _sleepRangeButton({
    required String label,
    required int minutes,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled
          ? onTap
          : null,
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(0xFFEFEBE9)
              : const Color(0xFFFAFAF9),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6D4C41)
                : const Color(0xFFE7E5E4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected
                    ? FontWeight.bold
                    : FontWeight.w500,
            color: selected
                ? const Color(0xFF5D4037)
                : const Color(0xFF57534E),
          ),
        ),
      ),
    );
  }

  Widget _sleepQualityButton({
    required String emoji,
    required String label,
    required int value,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled
          ? onTap
          : null,
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        width: 54,
        padding:
            const EdgeInsets.symmetric(
          vertical: 7,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(0xFFEFEBE9)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6D4C41)
                : const Color(0xFFE7E5E4),
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style:
                  const TextStyle(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  const TextStyle(
                fontSize: 8.5,
                color:
                    Color(0xFF57534E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  // ============================================================
  // HEADER BUTTON
  // ============================================================

  Widget _circleButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    Color? iconColor,
    Color? backgroundColor,
    Color? badgeColor,
  }) {
    Widget button = InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration:
            BoxDecoration(
          color:
              backgroundColor ??
                  Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                backgroundColor != null
                    ? const Color(
                        0xFFFED7AA,
                      )
                    : const Color(
                        0xFFEADBCE,
                      ),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              iconColor ??
                  const Color(
                    0xFF542E13,
                  ),
        ),
      ),
    );

    if (badgeColor != null) {
      button = Stack(
        clipBehavior:
            Clip.none,
        children: [
          button,
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(
                color: badgeColor,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}
