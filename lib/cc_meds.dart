// cc_meds.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/medicine_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

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

  void _toggleMedTaken(MedicineModel med, String targetUid, String time, bool taken) async {
    if (taken) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Medicine already marked as taken today!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final db = context.read<FirestoreService>();
    try {
      await db.logMedicineTaken(medId: med.medId, uid: targetUid, scheduledTime: time);
      if (mounted) {
        C.showSuccess(context, 'Medication Taken', '${med.name} marked as taken.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update log.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _saveMedicine(String targetUid, String creatorUid) async {
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
    final formattedTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    try {
      await db.addMedicine(
        uid: targetUid,
        createdBy: creatorUid,
        name: name,
        dosage: dosage,
        times: [formattedTime],
      );
      _nameCtrl.clear();
      _dosageCtrl.clear();
      if (mounted) {
        Navigator.pop(context);
        C.showSuccess(context, 'Medicine Added', '$name schedule created.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to add medicine. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
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

    final isElder = user.elderMode;
    final targetMember = widget.circle.members.firstWhere(
      (m) => m.role == 'member',
      orElse: () => widget.circle.members.firstWhere(
        (m) => m.uid != auth.uid!,
        orElse: () => widget.circle.members.first,
      ),
    );
    final targetUid = isElder ? auth.uid! : targetMember.uid;

    final db = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<UserModel?>(
        stream: db.streamUser(targetUid),
        builder: (context, userSnap) {
          final targetUser = userSnap.data;
          final targetName = targetUser?.displayName ?? 'Family Member';

          return StreamBuilder<List<MedicineModel>>(
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
                      final taken = logs.any((l) => l.medId == med.medId && l.scheduledTime == time);
                      displayMeds.add(_DisplayMed(med: med, time: time, taken: taken));
                    }
                  }

                  final takenCount = displayMeds.where((m) => m.taken).length;
                  final pct = displayMeds.isEmpty ? 0.0 : takenCount / displayMeds.length;

                  return SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                      children: [
                        // Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Medicine', style: TextStyle(fontSize: context.fs(C.fTitle), fontWeight: FontWeight.w900, color: C.textDark)),
                                Text(
                                  isElder ? 'DAILY WELLNESS TRACKER' : '$targetName\'S WELLNESS TRACKER',
                                  style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                                ),
                              ],
                            ),
                            if (!isElder)
                              GestureDetector(
                                onTap: () => _showAdd(context, targetUid, auth.uid!),
                                child: Container(
                                  width: e ? 50 : 44,
                                  height: e ? 50 : 44,
                                  decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.add_rounded, color: Colors.white, size: e ? 28 : 24),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Daily Adherence card
                        CC(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Daily Adherence',
                                        style: TextStyle(fontSize: context.fs(C.fBody), fontWeight: FontWeight.w900, color: C.textDark),
                                      ),
                                      Text(
                                        '$takenCount OF ${displayMeds.length} MEDS TAKEN',
                                        style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: TextStyle(fontSize: context.fs(C.fTitle), fontWeight: FontWeight.w900, color: pct == 1 ? C.green : C.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: C.divider,
                                  color: pct == 1 ? C.green : C.primary,
                                  minHeight: e ? 10 : 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const CapLabel("TODAY'S LIST"),
                        const SizedBox(height: 10),

                        // Med list
                        if (displayMeds.isEmpty)
                          CC(
                            pad: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No medications scheduled for today.',
                                style: TextStyle(fontSize: context.fs(C.fBody), color: C.textMid),
                              ),
                            ),
                          )
                        else
                          CC(
                            pad: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: displayMeds.asMap().entries.map((en) {
                                final idx = en.key;
                                final item = en.value;

                                return Column(
                                  children: [
                                    if (idx > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: e ? 50 : 44,
                                            height: e ? 50 : 44,
                                            decoration: BoxDecoration(
                                              color: item.taken ? C.greenSoft : C.primarySoft,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.medication_outlined, color: item.taken ? C.green : C.primary, size: context.ic),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.med.name,
                                                  style: TextStyle(fontSize: context.fs(C.fBody), fontWeight: FontWeight.w800, color: C.textDark),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item.med.dosage} · ${item.time}',
                                                  style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: isElder ? () => _toggleMedTaken(item.med, targetUid, item.time, item.taken) : null,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: EdgeInsets.symmetric(horizontal: e ? 22 : 18, vertical: e ? 12 : 9),
                                              decoration: BoxDecoration(
                                                color: item.taken ? C.green : C.primary,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                item.taken ? 'TAKEN' : 'TAKE',
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fCap),
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
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAdd(BuildContext context, String targetUid, String creatorUid) {
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
              const SizedBox(height: 16),

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
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _saveMedicine(targetUid, creatorUid),
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
}

class _DisplayMed {
  final MedicineModel med;
  final String time;
  final bool taken;
  _DisplayMed({required this.med, required this.time, required this.taken});
}