// cc_checkin.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/checkin_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

class CheckinTab extends StatefulWidget {
  final CircleModel circle;
  const CheckinTab({super.key, required this.circle});

  @override
  State<CheckinTab> createState() => _S();
}

class _S extends State<CheckinTab> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _sc;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sc = Tween(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
    _ac.addStatusListener((s) {
      if (s == AnimationStatus.completed) _ac.reverse();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

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

  void _checkin(String targetUid) async {
    final db = context.read<FirestoreService>();
    _ac.forward();
    try {
      await db.submitCheckin(uid: targetUid, circleId: widget.circle.circleId);
      if (mounted) {
        C.showSuccess(context, 'Checked In', 'You have notified your family circle.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to check in. Please try again.'),
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

          return StreamBuilder<List<CheckinModel>>(
            stream: db.streamRecentCheckins(targetUid, widget.circle.circleId),
            builder: (context, checkinSnap) {
              final checkins = checkinSnap.data ?? [];
              final todayCheckin = checkins.isEmpty ? null : (checkins.first.isToday ? checkins.first : null);
              final hasCheckedIn = todayCheckin != null;
              final streakDays = _calculateActiveStreak(checkins);

              // Calculate current week Mon-Sun check-in list
              final now = DateTime.now();
              final currentWeekday = now.weekday; // 1=Mon, 7=Sun
              final monday = now.subtract(Duration(days: currentWeekday - 1));

              final weekStatus = List.generate(7, (idx) {
                final day = monday.add(Duration(days: idx));
                return checkins.any((c) =>
                    c.timestamp.year == day.year &&
                    c.timestamp.month == day.month &&
                    c.timestamp.day == day.day);
              });

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  children: [
                    Text('Daily Check-in', style: TextStyle(fontSize: context.fs(C.fTitle), fontWeight: FontWeight.w900, color: C.textDark)),
                    const SizedBox(height: 4),
                    Text(
                      isElder ? 'Keep your family circle updated.' : 'Monitoring $targetName\'s safety.',
                      style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                    ),
                    const SizedBox(height: 24),

                    // Streak circle
                    CC(
                      pad: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: Center(
                        child: SizedBox(
                          width: e ? 180 : 150,
                          height: e ? 180 : 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: (streakDays % 14) / 14.0,
                                  strokeWidth: 10,
                                  backgroundColor: C.divider,
                                  color: C.primary,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded, color: C.fire, size: e ? 34 : 28),
                                  Text(
                                    '$streakDays',
                                    style: TextStyle(fontSize: context.fs(e ? 52 : 44), fontWeight: FontWeight.w900, color: C.textDark, height: 1.0),
                                  ),
                                  Text(
                                    'DAY STREAK',
                                    style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w700, letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 7-day dot checklist
                    CC(
                      pad: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((en) {
                          final ok = weekStatus[en.key];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                en.value,
                                style: TextStyle(fontSize: context.fs(C.fSub), fontWeight: FontWeight.w700, color: C.textLight),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: e ? 16 : 13,
                                height: e ? 16 : 13,
                                decoration: BoxDecoration(
                                  color: ok ? C.primary : Colors.transparent,
                                  border: Border.all(color: ok ? C.primary : C.textLight, width: 2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Big I AM OKAY / CHECKED IN button
                    ScaleTransition(
                      scale: _sc,
                      child: hasCheckedIn
                          ? CC(
                              bg: C.greenSoft,
                              pad: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: C.green, size: e ? 60 : 50),
                                  const SizedBox(height: 14),
                                  Text(
                                    'CHECKED IN!',
                                    style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: C.green, letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isElder ? 'Your family has been notified' : '$targetName has checked in today',
                                    style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: isElder ? () => _checkin(targetUid) : null,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: e ? 40 : 34),
                                decoration: BoxDecoration(
                                  color: isElder ? C.primary : C.textLight,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.favorite_outline_rounded, color: Colors.white, size: e ? 60 : 50),
                                    const SizedBox(height: 14),
                                    Text(
                                      isElder ? 'I AM OKAY' : 'NOT CHECKED IN',
                                      style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isElder ? 'TAP TO NOTIFY FAMILY' : 'WAITING FOR CHECK-IN',
                                      style: TextStyle(fontSize: context.fs(C.fCap), color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Banner info
                    CC(
                      bg: C.bg,
                      pad: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: C.textLight, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Missed check-ins for 7 consecutive days will automatically trigger an alert to family monitors.',
                              style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}