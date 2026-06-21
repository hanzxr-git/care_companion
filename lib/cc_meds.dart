// cc_meds.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/medicine_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/alarm_service.dart';
import 'services/storage_service.dart';

class MedsTab extends StatefulWidget {
  final CircleModel circle;
  const MedsTab({super.key, required this.circle});

  @override
  State<MedsTab> createState() => _S();
}

class _S extends State<MedsTab> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  List<String> _generateIntervalTimes(TimeOfDay startTime, int value, String unit) {
    final times = <String>[];
    int intervalMinutes = 0;
    if (unit == 'hours') {
      intervalMinutes = value * 60;
    } else {
      intervalMinutes = value;
    }
    
    if (intervalMinutes <= 0) {
      return [
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
      ];
    }

    int currentMinutes = startTime.hour * 60 + startTime.minute;
    final startMinutes = currentMinutes;

    for (int i = 0; i < 1440; i += intervalMinutes) {
      final h = (currentMinutes ~/ 60) % 24;
      final m = currentMinutes % 60;
      times.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      currentMinutes += intervalMinutes;
      if (currentMinutes % 1440 == startMinutes) {
        break;
      }
    }
    times.sort();
    return times;
  }

  Map<String, dynamic> _detectInterval(List<String> times) {
    if (times.length <= 1) {
      return {'isInterval': false, 'value': 4, 'unit': 'hours'};
    }
    try {
      final sorted = List<String>.from(times)..sort();
      final parts1 = sorted[0].split(':');
      final parts2 = sorted[1].split(':');
      final m1 = int.parse(parts1[0]) * 60 + int.parse(parts1[1]);
      final m2 = int.parse(parts2[0]) * 60 + int.parse(parts2[1]);
      final diff = m2 - m1;
      if (diff > 0) {
        if (diff % 60 == 0) {
          return {'isInterval': true, 'value': diff ~/ 60, 'unit': 'hours'};
        } else {
          return {'isInterval': true, 'value': diff, 'unit': 'minutes'};
        }
      }
    } catch (_) {}
    return {'isInterval': true, 'value': 4, 'unit': 'hours'};
  }

  String _formatTimeStr(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length < 2) return time24;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final hourStr = hour12.toString().padLeft(2, '0');
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$hourStr:$minuteStr $period';
    } catch (_) {
      return time24;
    }
  }

  void _showMedicationDialog(_DisplayMed item, String targetUid) {
    final db = context.read<FirestoreService>();
    final med = item.med;
    final time = item.time;
    final taken = item.taken;
    final log = item.log;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: C.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            taken ? 'Medication Taken' : 'Take Medication',
            style: const TextStyle(fontWeight: FontWeight.w900, color: C.textDark),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  taken && log != null 
                    ? '${med.name} at ${_formatTimeStr("${log.takenAt.hour.toString().padLeft(2, '0')}:${log.takenAt.minute.toString().padLeft(2, '0')}")}'
                    : '${med.name} at ${_formatTimeStr(time)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (taken) ...[
                  if (log?.proofUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        log!.proofUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(color: C.primary)),
                        );
                      },
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 200,
                        child: Center(child: Icon(Icons.broken_image, size: 48, color: C.textLight)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ],
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      // Delete proof image
                      if (log?.proofUrl != null) {
                        await StorageService.deleteMedicineProof(log!.proofUrl!);
                      }
                      
                      // Unlog
                      await db.unlogMedicineTaken(medId: med.medId, uid: targetUid, scheduledTime: time);
                      if (mounted) {
                        C.showSuccess(context, 'Medication Untaken', '${med.name} marked as not taken.');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Undo (Mark as Not Taken)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ] else ...[
                const Text(
                  'Please provide a photo proof to mark this medication as taken.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.textMid),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.camera);
                    if (photo == null) return;
                    
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator(color: C.primary)),
                      );
                    }
                    
                    final proofUrl = await StorageService.uploadMedicineProof(targetUid, med.medId, File(photo.path));
                    
                    if (mounted) {
                      Navigator.pop(context); // close loading
                    }
                    
                    if (proofUrl == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload proof.')));
                      }
                      return;
                    }

                    await db.logMedicineTaken(medId: med.medId, uid: targetUid, scheduledTime: time, proofUrl: proofUrl);
                    if (med.deleteAfterTaken) {
                      await db.deactivateMedicine(med.medId);
                      await AlarmService.cancelAlarm(med);
                      if (mounted) {
                        C.showSuccess(context, 'Medication Taken & Deleted', '${med.name} marked as taken and schedule deleted.');
                      }
                    } else {
                      if (mounted) {
                        C.showSuccess(context, 'Medication Taken', '${med.name} marked as taken.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Take Photo Proof', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: C.textMid)),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _saveMedicine({
    required String targetUid,
    required String creatorUid,
    required List<int> daysOfWeek,
    required String ringtone,
    required bool vibrate,
    required bool deleteAfterTaken,
    required List<String> times,
  }) async {
    final name = _nameCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();

    if (name.isEmpty || dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all fields'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final db = context.read<FirestoreService>();

    try {
      final med = await db.addMedicine(
        uid: targetUid,
        createdBy: creatorUid,
        name: name,
        dosage: dosage,
        times: times,
        daysOfWeek: daysOfWeek,
        ringtone: ringtone,
        vibrate: vibrate,
        deleteAfterTaken: deleteAfterTaken,
      );
      await AlarmService.scheduleAlarm(med);
      _nameCtrl.clear();
      _dosageCtrl.clear();
      if (mounted) {
        Navigator.pop(context);
        C.showSuccess(context, 'Medicine Added', '$name schedule created.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to add medicine. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final auth = context.watch<AuthService>();
    final user = auth.userModel;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final targetUid = auth.uid!;

    final db = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<MedicineModel>>(
        stream: db.streamMedicines(targetUid),
        builder: (context, medsSnap) {
          final medicines = medsSnap.data ?? [];

              return StreamBuilder<List<MedLogModel>>(
                stream: db.streamTodayMedLogs(targetUid),
                builder: (context, logsSnap) {
                  final logs = logsSnap.data ?? [];

                  // Flatten meds to times
                  final displayMeds = <_DisplayMed>[];
                  for (final med in medicines) {
                    if (!med.isScheduledToday) continue;
                    for (final time in med.times) {
                      final logsForTime = logs.where((l) => l.medId == med.medId && l.scheduledTime == time);
                      final taken = logsForTime.isNotEmpty;
                      final log = taken ? logsForTime.first : null;
                      displayMeds.add(_DisplayMed(med: med, time: time, taken: taken, log: log));
                    }
                  }

                  final takenCount = displayMeds.where((m) => m.taken).length;
                  final pct = displayMeds.isEmpty ? 0.0 : takenCount / displayMeds.length;

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    backgroundColor: Colors.white,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    forceElevated: true,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 12,
                    toolbarHeight: 80,
                    titleSpacing: 20,
                    title: Text(
                      'Medicine',
                      style: TextStyle(
                        fontSize: context.fs(36),
                        fontWeight: FontWeight.w900,
                        color: C.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: GestureDetector(
                          onTap: () => _showAdd(context, targetUid, auth.uid!),
                          child: Container(
                            width: e ? 56 : 48,
                            height: e ? 56 : 48,
                            decoration: BoxDecoration(
                              color: C.primary,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: C.primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(Icons.add_rounded, color: Colors.white, size: e ? 30 : 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                              // Daily Adherence card
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: C.textDark.withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -30,
                                  right: -30,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: C.primary.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Daily Adherence',
                                                  style: TextStyle(
                                                    fontSize: context.fs(20),
                                                    fontWeight: FontWeight.w900,
                                                    color: C.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$takenCount OF ${displayMeds.length} MEDS TAKEN',
                                                  style: TextStyle(
                                                    fontSize: context.fs(11),
                                                    color: C.primary,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${(pct * 100).round()}%',
                                            style: TextStyle(
                                              fontSize: context.fs(36),
                                              fontWeight: FontWeight.w900,
                                              color: C.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor: C.primary.withValues(alpha: 0.1),
                                          color: C.primary,
                                          minHeight: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "TODAY'S LIST",
                          style: TextStyle(
                            fontSize: context.fs(11),
                            fontWeight: FontWeight.w900,
                            color: C.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Med list
                        if (displayMeds.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: C.textDark.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'No medications scheduled for today.',
                                style: TextStyle(fontSize: context.fs(C.fBody), color: C.textMid),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: displayMeds.map((item) {
                              final formattedTime = _formatTimeStr(item.time);
                              return GestureDetector(
                                onTap: () => _showEditDeleteSheet(context, item.med, targetUid),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: C.textDark.withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: e ? 56 : 48,
                                          height: e ? 56 : 48,
                                          decoration: BoxDecoration(
                                            color: item.taken ? C.greenSoft : C.primarySoft,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Transform.rotate(
                                              angle: -0.785398, // -45 degrees (pi / 4)
                                              child: Icon(
                                                Icons.medication_outlined,
                                                color: item.taken ? C.green : C.primary,
                                                size: e ? 28 : 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.med.name,
                                                style: TextStyle(
                                                  fontSize: context.fs(18),
                                                  fontWeight: FontWeight.w900,
                                                  color: C.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.med.dosage.toUpperCase()} • $formattedTime',
                                                style: TextStyle(
                                                  fontSize: context.fs(11),
                                                  fontWeight: FontWeight.w800,
                                                  color: C.primary.withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _showMedicationDialog(item, targetUid),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: EdgeInsets.symmetric(horizontal: e ? 24 : 18, vertical: e ? 12 : 9),
                                            decoration: BoxDecoration(
                                              color: item.taken ? C.green : C.primary,
                                              borderRadius: BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (item.taken ? C.green : C.primary).withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              item.taken ? 'TAKEN' : 'TAKE',
                                              style: TextStyle(
                                                fontSize: context.fs(11),
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                            ]),
                          ),
                        ),
                      ],
                    );
                },
              );
        },
      ),
    );
  }

  void _showAdd(BuildContext context, String targetUid, String creatorUid) {
    _nameCtrl.clear();
    _dosageCtrl.clear();
    _selectedTime = const TimeOfDay(hour: 8, minute: 0);
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7];
    String selectedRingtone = 'Medication';
    bool vibrate = true;
    bool deleteAfterTaken = false;

    // Interval states
    bool isInterval = false;
    final intervalValCtrl = TextEditingController(text: '4');
    String intervalUnit = 'hours';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: const BoxDecoration(color: C.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Add medicine', style: TextStyle(fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Medicine name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage (e.g. 500mg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Specific Time vs Interval Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Specific Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: !isInterval,
                      selectedColor: C.primary.withValues(alpha: 0.2),
                      checkmarkColor: C.primary,
                      onSelected: (val) {
                        if (val) setModalState(() => isInterval = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Interval', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: isInterval,
                      selectedColor: C.primary.withValues(alpha: 0.2),
                      checkmarkColor: C.primary,
                      onSelected: (val) {
                        if (val) setModalState(() => isInterval = true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!isInterval) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Time', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w700, color: C.textDark)),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (time != null) {
                          setModalState(() => _selectedTime = time);
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w700, color: C.textDark)),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (time != null) {
                          setModalState(() => _selectedTime = time);
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Notify every ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      height: 48,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                        ),
                        controller: intervalValCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: intervalUnit,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hours', child: Text('Hours')),
                          DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => intervalUnit = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'NOTIFICATION SETTINGS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.primary, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),

              // Notification settings card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Repeat row
                    GestureDetector(
                      onTap: () => _selectRepeatDays(context, selectedDays, setModalState),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Repeat',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getRepeatText(selectedDays),
                                  style: const TextStyle(fontSize: 14, color: C.textMid, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: C.textLight, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Delete After Switch row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Delete after taken',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark),
                          ),
                          Switch(
                            value: deleteAfterTaken,
                            activeThumbColor: Colors.white,
                            activeTrackColor: C.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: C.textLight.withValues(alpha: 0.4),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) {
                              setModalState(() => deleteAfterTaken = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final times = <String>[];
                    if (isInterval) {
                      final valStr = intervalValCtrl.text.trim();
                      final val = int.tryParse(valStr) ?? 4;
                      times.addAll(_generateIntervalTimes(_selectedTime, val, intervalUnit));
                    } else {
                      final formattedTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
                      times.add(formattedTime);
                    }
                    _saveMedicine(
                      targetUid: targetUid,
                      creatorUid: creatorUid,
                      daysOfWeek: selectedDays,
                      ringtone: selectedRingtone,
                      vibrate: vibrate,
                      deleteAfterTaken: deleteAfterTaken,
                      times: times,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDeleteSheet(BuildContext context, MedicineModel med, String targetUid) {
    final nameCtrl = TextEditingController(text: med.name);
    final dosageCtrl = TextEditingController(text: med.dosage);
    
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    try {
      if (med.times.isNotEmpty) {
        final parts = med.times.first.split(':');
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    List<int> selectedDays = List<int>.from(med.daysOfWeek);
    String selectedRingtone = med.ringtone;
    bool vibrate = med.vibrate;
    bool deleteAfterTaken = med.deleteAfterTaken;

    // Detect interval from med.times
    final intervalData = _detectInterval(med.times);
    bool isInterval = intervalData['isInterval'];
    final intervalValCtrl = TextEditingController(text: intervalData['value'].toString());
    String intervalUnit = intervalData['unit'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit medicine', style: TextStyle(fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                    onPressed: () => _deleteMedicine(context, med),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Medicine name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage (e.g. 500mg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Specific Time vs Interval Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Specific Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: !isInterval,
                      selectedColor: C.primary.withValues(alpha: 0.2),
                      checkmarkColor: C.primary,
                      onSelected: (val) {
                        if (val) setModalState(() => isInterval = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Interval', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: isInterval,
                      selectedColor: C.primary.withValues(alpha: 0.2),
                      checkmarkColor: C.primary,
                      onSelected: (val) {
                        if (val) setModalState(() => isInterval = true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!isInterval) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Time', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w700, color: C.textDark)),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedTime);
                        if (time != null) {
                          setModalState(() => selectedTime = time);
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w700, color: C.textDark)),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: selectedTime);
                        if (time != null) {
                          setModalState(() => selectedTime = time);
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Notify every ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      height: 48,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                        ),
                        controller: intervalValCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: intervalUnit,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hours', child: Text('Hours')),
                          DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => intervalUnit = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'NOTIFICATION SETTINGS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.primary, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),

              // Notification settings card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Repeat row
                    GestureDetector(
                      onTap: () => _selectRepeatDays(context, selectedDays, setModalState),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Repeat',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getRepeatText(selectedDays),
                                  style: const TextStyle(fontSize: 14, color: C.textMid, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: C.textLight, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Delete After Switch row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Delete after taken',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark),
                          ),
                          Switch(
                            value: deleteAfterTaken,
                            activeThumbColor: Colors.white,
                            activeTrackColor: C.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: C.textLight.withValues(alpha: 0.4),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) {
                              setModalState(() => deleteAfterTaken = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final times = <String>[];
                    if (isInterval) {
                      final valStr = intervalValCtrl.text.trim();
                      final val = int.tryParse(valStr) ?? 4;
                      times.addAll(_generateIntervalTimes(selectedTime, val, intervalUnit));
                    } else {
                      final formattedTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                      times.add(formattedTime);
                    }
                    _updateMedicine(
                      medId: med.medId,
                      name: nameCtrl.text.trim(),
                      dosage: dosageCtrl.text.trim(),
                      times: times,
                      daysOfWeek: selectedDays,
                      ringtone: selectedRingtone,
                      vibrate: vibrate,
                      deleteAfterTaken: deleteAfterTaken,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateMedicine({
    required String medId,
    required String name,
    required String dosage,
    required List<String> times,
    required List<int> daysOfWeek,
    required String ringtone,
    required bool vibrate,
    required bool deleteAfterTaken,
  }) async {
    if (name.isEmpty || dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all fields'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final db = context.read<FirestoreService>();

    try {
      await db.updateMedicine(
        medId: medId,
        name: name,
        dosage: dosage,
        times: times,
        daysOfWeek: daysOfWeek,
        ringtone: ringtone,
        vibrate: vibrate,
        deleteAfterTaken: deleteAfterTaken,
      );
      final updatedMed = MedicineModel(
        medId: medId,
        uid: '',
        createdBy: '',
        name: name,
        dosage: dosage,
        times: times,
        daysOfWeek: daysOfWeek,
        createdAt: DateTime.now(),
        ringtone: ringtone,
        vibrate: vibrate,
        deleteAfterTaken: deleteAfterTaken,
        active: true,
      );
      await AlarmService.scheduleAlarm(updatedMed);
      if (mounted) {
        Navigator.pop(context);
        C.showSuccess(context, 'Medicine Updated', '$name has been updated.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update medicine.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _deleteMedicine(BuildContext context, MedicineModel med) async {
    final db = context.read<FirestoreService>();
    try {
      await db.deactivateMedicine(med.medId);
      await AlarmService.cancelAlarm(med);
      if (context.mounted) {
        Navigator.pop(context);
        C.showSuccess(context, 'Medicine Deleted', '${med.name} removed.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete medicine.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }



  void _selectRepeatDays(BuildContext context, List<int> selectedDays, StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSelectState) => Container(
          decoration: const BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Repeat Days',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.textDark),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, color: C.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...[
                {'val': 1, 'name': 'Monday'},
                {'val': 2, 'name': 'Tuesday'},
                {'val': 3, 'name': 'Wednesday'},
                {'val': 4, 'name': 'Thursday'},
                {'val': 5, 'name': 'Friday'},
                {'val': 6, 'name': 'Saturday'},
                {'val': 7, 'name': 'Sunday'},
              ].map((day) {
                final dVal = day['val'] as int;
                final dName = day['name'] as String;
                final isSelected = selectedDays.contains(dVal);
                return CheckboxListTile(
                  title: Text(dName, style: const TextStyle(fontWeight: FontWeight.bold, color: C.textDark)),
                  value: isSelected,
                  activeColor: C.primary,
                  onChanged: (val) {
                    setSelectState(() {
                      if (val == true) {
                        selectedDays.add(dVal);
                        selectedDays.sort();
                      } else {
                        selectedDays.remove(dVal);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _getRepeatText(List<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.isEmpty) return 'Once';
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.map((d) => dayNames[d]).join(', ');
  }
}

class _DisplayMed {
  final MedicineModel med;
  final String time;
  final bool taken;
  final MedLogModel? log;
  _DisplayMed({required this.med, required this.time, required this.taken, this.log});
}