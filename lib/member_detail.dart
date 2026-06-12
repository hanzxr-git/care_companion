// cc_member_detail.dart — Images 6,7,8,9
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/checkin_model.dart';
import 'models/medicine_model.dart';
import 'models/location_model.dart';
import 'services/firestore_service.dart';

class MemberDetailScreen extends StatefulWidget {
  final UserModel member;
  final CircleModel circle;
  const MemberDetailScreen({super.key, required this.member, required this.circle});

  @override
  State<MemberDetailScreen> createState() => _S();
}

class _S extends State<MemberDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final m = widget.member;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: e ? 22 : 18, color: C.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(m.displayName, style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: C.textDark)),
        bottom: TabBar(
          controller: _tc,
          labelColor: C.primary,
          unselectedLabelColor: C.textLight,
          indicatorColor: C.primary,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontFamily: 'Nunito', fontSize: context.fs(C.fCap), fontWeight: FontWeight.w800, letterSpacing: 0.5),
          unselectedLabelStyle: TextStyle(fontFamily: 'Nunito', fontSize: context.fs(C.fCap), fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.location_on_outlined, size: 20), text: 'LOCATION'),
            Tab(icon: Icon(Icons.local_fire_department_outlined, size: 20), text: 'STREAK'),
            Tab(icon: Icon(Icons.medication_outlined, size: 20), text: 'MEDS'),
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _LocTab(m: m, e: e),
          _StrTab(m: m, circle: widget.circle, e: e),
          _MedTab(m: m, e: e),
          _EvTab(m: m, circle: widget.circle, e: e),
        ],
      ),
    );
  }
}

class _LocTab extends StatelessWidget {
  final UserModel m;
  final bool e;
  const _LocTab({required this.m, required this.e});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return StreamBuilder<LocationModel?>(
      stream: db.streamLocation(m.uid),
      builder: (context, snapshot) {
        final location = snapshot.data;
        final isSharing = location?.sharing ?? true;
        final locLabel = isSharing ? location?.label ?? 'Puchong, Selangor' : 'Location private';
        final agoText = isSharing ? location?.agoText ?? 'Just now' : 'Hidden';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            CC(
              pad: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Container(
                      height: e ? 230 : 200,
                      color: C.primarySoft,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: e ? 48 : 40, color: C.primary.withOpacity(0.25)),
                            const SizedBox(height: 8),
                            Text(
                              isSharing ? 'MAP VIEW ACTIVE' : 'MAP SHARING DISABLED',
                              style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSharing)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: C.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE NOW',
                                style: TextStyle(fontSize: context.fs(C.fCap), fontWeight: FontWeight.w800, color: C.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CC(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT LOCATION', style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(locLabel, style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: C.textDark)),
                  const SizedBox(height: 4),
                  Text('Updated $agoText', style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StrTab extends StatelessWidget {
  final UserModel m;
  final CircleModel circle;
  final bool e;
  const _StrTab({required this.m, required this.circle, required this.e});

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

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<CheckinModel>>(
      stream: db.streamRecentCheckins(m.uid, circle.circleId),
      builder: (context, snapshot) {
        final checkins = snapshot.data ?? [];
        final todayCheckin = checkins.isEmpty ? null : (checkins.first.isToday ? checkins.first : null);
        final checkedInToday = todayCheckin != null;
        final streakDays = _calculateActiveStreak(checkins);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            CC(
              pad: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: SizedBox(
                  width: e ? 190 : 160,
                  height: e ? 190 : 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (streakDays % 30) / 30.0,
                          strokeWidth: 10,
                          backgroundColor: C.divider,
                          color: checkedInToday
                              ? (streakDays >= 200
                                  ? Colors.purple
                                  : (streakDays >= 100 ? Colors.orange : Colors.red))
                              : Colors.grey.shade300,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: checkedInToday
                                ? (streakDays >= 200
                                    ? Colors.purple
                                    : (streakDays >= 100 ? Colors.orange : Colors.red))
                                : Colors.grey.shade400,
                            size: e ? 38 : 32,
                          ),
                          Text(
                            '$streakDays',
                            style: TextStyle(fontSize: context.fs(e ? 56 : 48), fontWeight: FontWeight.w900, color: C.textDark, height: 1.0),
                          ),
                          Text(
                            'DAYS',
                            style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CC(
              bg: checkedInToday ? C.greenSoft : C.orangeSoft,
              child: Row(
                children: [
                  Icon(checkedInToday ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: checkedInToday ? C.green : C.orange, size: e ? 26 : 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checkedInToday ? 'Successfully Checked-in' : 'Not checked in yet',
                          style: TextStyle(fontSize: context.fs(C.fBody), fontWeight: FontWeight.w900, color: checkedInToday ? C.green : C.orange),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          checkedInToday ? 'Everything looks great today!' : 'Waiting for check-in',
                          style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MedTab extends StatelessWidget {
  final UserModel m;
  final bool e;
  const _MedTab({required this.m, required this.e});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<MedicineModel>>(
      stream: db.streamMedicines(m.uid),
      builder: (context, medsSnap) {
        final medicines = medsSnap.data ?? [];

        return StreamBuilder<List<MedLogModel>>(
          stream: db.streamTodayMedLogs(m.uid),
          builder: (context, logsSnap) {
            final logs = logsSnap.data ?? [];

            final displayMeds = <_DisplayMed>[];
            for (final med in medicines) {
              if (!med.isScheduledToday) continue;
              for (final time in med.times) {
                final taken = logs.any((l) => l.medId == med.medId && l.scheduledTime == time);
                displayMeds.add(_DisplayMed(med: med, time: time, taken: taken));
              }
            }

            final takenCount = displayMeds.where((x) => x.taken).length;
            final pct = displayMeds.isEmpty ? 0.0 : takenCount / displayMeds.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TODAY'S ADHERENCE", style: TextStyle(fontSize: context.fs(C.fCap), fontWeight: FontWeight.w800, color: C.textMid, letterSpacing: 1)),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: pct == 1 ? C.green : C.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                                          style: TextStyle(fontSize: context.fs(C.fBody), fontWeight: FontWeight.w800, color: C.textDark),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.time,
                                          style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: e ? 18 : 14, vertical: e ? 10 : 7),
                                    decoration: BoxDecoration(
                                      color: item.taken ? C.greenSoft : C.primarySoft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item.taken ? 'TAKEN' : 'PENDING',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fCap),
                                        fontWeight: FontWeight.w900,
                                        color: item.taken ? C.green : C.primary,
                                        letterSpacing: 0.5,
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
            );
          },
        );
      },
    );
  }
}

class _EvTab extends StatelessWidget {
  final UserModel m;
  final CircleModel circle;
  final bool e;
  const _EvTab({required this.m, required this.circle, required this.e});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final mons = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

    return StreamBuilder<List<CheckinModel>>(
      stream: db.streamRecentCheckins(m.uid, circle.circleId),
      builder: (context, snapshot) {
        final checkins = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('CHECK-IN HISTORY', style: TextStyle(fontSize: context.fs(C.fCap), fontWeight: FontWeight.w800, color: C.textMid, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (checkins.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: e ? 52 : 42, color: C.textLight),
                      const SizedBox(height: 12),
                      Text('No check-in history found', style: TextStyle(fontSize: context.fs(C.fBody), color: C.textMid)),
                    ],
                  ),
                ),
              )
            else
              ...checkins.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(mons[c.timestamp.month - 1], style: TextStyle(fontSize: context.fs(C.fCap), fontWeight: FontWeight.w800, color: C.primary, letterSpacing: 1)),
                            Text('${c.timestamp.day}', style: TextStyle(fontSize: context.fs(C.fTitle), fontWeight: FontWeight.w900, color: C.textDark, height: 1.0)),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.mood != null ? 'Mood: ${c.mood!.toUpperCase()}' : 'Checked in safely',
                                style: TextStyle(fontSize: context.fs(C.fBody), fontWeight: FontWeight.w800, color: C.textDark),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                c.note ?? 'Shared wellness status with family.',
                                style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _DisplayMed {
  final MedicineModel med;
  final String time;
  final bool taken;
  _DisplayMed({required this.med, required this.time, required this.taken});
}