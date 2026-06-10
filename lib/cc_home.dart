// cc_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/checkin_model.dart';
import 'models/medicine_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

class HomeTab extends StatefulWidget {
  final CircleModel circle;
  const HomeTab({super.key, required this.circle});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _moods = [
    ('😄', 'GREAT'),
    ('🙂', 'GOOD'),
    ('😐', 'OKAY'),
    ('😔', 'LOW'),
    ('😢', 'SAD'),
  ];

  int _calculateActiveStreak(List<CheckinModel> checkins) {
    if (checkins.isEmpty) return 0;
    final last = checkins.first;
    final lastDate = DateTime(last.timestamp.year, last.timestamp.month, last.timestamp.day);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (lastDate == todayDate || lastDate == yesterdayDate) {
      return last.streakDay;
    }
    return 0;
  }

  void _selectMood(String moodName, String targetUid) async {
    final db = context.read<FirestoreService>();
    try {
      await db.submitCheckin(uid: targetUid, circleId: widget.circle.circleId, mood: moodName);
      if (mounted) {
        C.showSuccess(context, 'Mood Logged', 'Logged today\'s mood as $moodName.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to log mood. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
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
        content: Text('Failed to update medication log.'),
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
    // Target user: if elder, show self. If caregiver, find first member role in circle.
    final targetMember = widget.circle.members.firstWhere(
      (m) => m.role == 'member',
      orElse: () => widget.circle.members.firstWhere(
        (m) => m.uid != auth.uid!,
        orElse: () => widget.circle.members.first,
      ),
    );
    final targetUid = isElder ? auth.uid! : targetMember.uid;

    final h = DateTime.now().hour;
    final greet = h < 12 ? 'GOOD MORNING' : h < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';

    final db = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<UserModel?>(
        stream: db.streamUser(targetUid),
        builder: (context, userSnap) {
          final targetUser = userSnap.data;
          final targetName = targetUser?.displayName ?? 'Family Member';

          return StreamBuilder<List<CheckinModel>>(
            stream: db.streamRecentCheckins(targetUid, widget.circle.circleId),
            builder: (context, checkinSnap) {
              final checkins = checkinSnap.data ?? [];
              final todayCheckin = checkins.isEmpty ? null : (checkins.first.isToday ? checkins.first : null);
              final streakDays = _calculateActiveStreak(checkins);

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

                      return CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            pinned: true,
                            floating: false,
                            backgroundColor: C.bg,
                            elevation: 0,
                            scrolledUnderElevation: 0,
                            toolbarHeight: 72,
                            titleSpacing: 20,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  greet,
                                  style: TextStyle(
                                    fontSize: context.fs(C.fCap),
                                    color: C.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  user.displayName,
                                  style: TextStyle(
                                    fontSize: context.fs(C.fName),
                                    fontWeight: FontWeight.w900,
                                    color: C.textDark,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              if (!isElder)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    backgroundColor: C.primarySoft,
                                    side: BorderSide.none,
                                    label: Text(
                                      'MONITORING: ${targetName.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fTiny),
                                        fontWeight: FontWeight.w800,
                                        color: C.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Container(
                                  width: e ? 46 : 40,
                                  height: e ? 46 : 40,
                                  decoration: const BoxDecoration(color: C.surface, shape: BoxShape.circle),
                                  child: Icon(Icons.notifications_outlined, color: C.textMid, size: context.ic),
                                ),
                              ),
                            ],
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // ── Daily Streak card
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: C.primarySoft,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: e ? 52 : 46,
                                        height: e ? 52 : 46,
                                        decoration: BoxDecoration(
                                          color: C.surface,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(Icons.local_fire_department_rounded, color: C.fire, size: e ? 30 : 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isElder ? 'Your Daily Streak' : '$targetName\'s Streak',
                                              style: TextStyle(
                                                fontSize: context.fs(C.fH2),
                                                fontWeight: FontWeight.w900,
                                                color: C.textDark,
                                              ),
                                            ),
                                            Text(
                                              '$streakDays DAYS SAFE',
                                              style: TextStyle(
                                                fontSize: context.fs(C.fCap),
                                                color: C.primary,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '$streakDays',
                                        style: TextStyle(
                                          fontSize: context.fs(44),
                                          fontWeight: FontWeight.w900,
                                          color: C.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                CapLabel(isElder ? 'YOUR MOOD TODAY' : '$targetName\'s MOOD TODAY'),
                                const SizedBox(height: 10),

                                // ── Mood picker
                                CC(
                                  pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: _moods.asMap().entries.map((en) {
                                      final moodName = en.value.$2;
                                      final isSelected = todayCheckin?.mood?.toUpperCase() == moodName;

                                      return GestureDetector(
                                        onTap: isElder ? () => _selectMood(moodName, targetUid) : null,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? C.primarySoft : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(en.value.$1, style: TextStyle(fontSize: e ? 30 : 24)),
                                              const SizedBox(height: 5),
                                              Text(
                                                en.value.$2,
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fTiny),
                                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                                  color: isSelected ? C.primary : C.textLight,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // ── Medications header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    CapLabel(isElder ? 'YOUR MEDICATIONS' : '$targetName\'s MEDICATIONS'),
                                    Text(
                                      'DETAILS',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fCap),
                                        fontWeight: FontWeight.w800,
                                        color: C.primary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // ── Med list
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
                                                    width: e ? 48 : 42,
                                                    height: e ? 48 : 42,
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
                                                          style: TextStyle(
                                                            fontSize: context.fs(C.fBody),
                                                            fontWeight: FontWeight.w800,
                                                            color: C.textDark,
                                                          ),
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
                                const SizedBox(height: 22),

                                // ── Emergency SOS
                                GestureDetector(
                                  onTap: () => _sos(context, targetName),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: e ? 20 : 16),
                                    decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(16)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: e ? 28 : 24),
                                        const SizedBox(width: 10),
                                        Text(
                                          'EMERGENCY SOS',
                                          style: TextStyle(
                                            fontSize: context.fs(C.fH3),
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _sos(BuildContext ctx, String name) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Send SOS?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: C.fH2)),
          content: Text('This will immediately alert all family members in your circle about $name\'s emergency status.', style: const TextStyle(fontSize: C.fBody)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontSize: C.fBody))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('SOS Alert triggered!'), behavior: SnackBarBehavior.floating));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Send SOS', style: TextStyle(fontSize: C.fBody)),
            ),
          ],
        ),
      );
}

class _DisplayMed {
  final MedicineModel med;
  final String time;
  final bool taken;
  _DisplayMed({required this.med, required this.time, required this.taken});
}