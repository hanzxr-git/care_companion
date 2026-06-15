// cc_checkin.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
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

  void _checkin(String targetUid, {String? mood}) async {
    final db = context.read<FirestoreService>();
    _ac.forward();
    try {
      await db.submitCheckin(uid: targetUid, circleId: widget.circle.circleId, mood: mood);
      if (mounted) {
        C.showSuccess(
          context, 
          mood != null ? 'Mood Logged' : 'Checked In', 
          mood != null ? 'Logged today\'s mood as ${mood.toLowerCase()}.' : 'You have notified your family circle.'
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to check in. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Color _getStreakColor(int days) {
    if (days >= 200) return Colors.purple;
    if (days >= 100) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAchievementRow(
    BuildContext context, {
    required String title,
    required String range,
    required Color color,
    required bool isActive,
    required bool isUnlocked,
  }) {
    final e = context.elder;
    return Row(
      children: [
        Container(
          width: e ? 48 : 40,
          height: e ? 48 : 40,
          decoration: BoxDecoration(
            color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: isUnlocked ? color : Colors.grey.shade300,
            size: e ? 28 : 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: context.fs(C.fBody),
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? C.textDark : C.textLight,
                ),
              ),
              Text(
                range,
                style: TextStyle(
                  fontSize: context.fs(C.fSub),
                  color: isUnlocked ? C.textMid : C.textLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'ACTIVE',
              style: TextStyle(
                fontSize: context.fs(C.fTiny),
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          )
        else if (isUnlocked)
          const Icon(
            Icons.check_circle_rounded,
            color: C.green,
            size: 20,
          )
        else
          const Icon(
            Icons.lock_outline_rounded,
            color: C.textLight,
            size: 20,
          ),
      ],
    );
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
      body: StreamBuilder<List<CheckinModel>>(
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
                      'Keep your family circle updated.',
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
                                  color: todayCheckin != null
                                      ? _getStreakColor(streakDays)
                                      : Colors.grey.shade300,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    color: todayCheckin != null
                                        ? _getStreakColor(streakDays)
                                        : Colors.grey.shade400,
                                    size: e ? 34 : 28,
                                  ),
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
                    const SizedBox(height: 24),

                    // Big I AM OKAY / CHECKED IN button
                    ScaleTransition(
                      scale: _sc,
                      child: hasCheckedIn
                          ? Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: e ? 40 : 34),
                              decoration: BoxDecoration(
                                color: C.green,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white, width: 4.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: C.green.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white,
                                    size: e ? 60 : 50,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'CHECK-IN COMPLETE',
                                    style: TextStyle(
                                      fontSize: context.fs(C.fH2),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'CHECKED IN SUCCESSFULLY',
                                    style: TextStyle(
                                      fontSize: context.fs(C.fCap),
                                      color: Colors.white.withValues(alpha: 0.8),
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _checkin(targetUid),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: e ? 40 : 34),
                                decoration: BoxDecoration(
                                  color: C.primary,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white, width: 4.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: C.primary.withValues(alpha: 0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.favorite_outline_rounded,
                                      color: Colors.white,
                                      size: e ? 60 : 50,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'I AM OKAY',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fH2),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'TAP TO CHECK IN TODAY',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fCap),
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // ── Streak Achievements Section
                    const CapLabel('STREAK ACHIEVEMENTS'),
                    const SizedBox(height: 10),
                    CC(
                      pad: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAchievementRow(
                            context,
                            title: 'Bronze Fire',
                            range: '1 - 99 Days',
                            color: Colors.red,
                            isActive: streakDays >= 1 && streakDays <= 99,
                            isUnlocked: streakDays >= 1,
                          ),
                          const Divider(height: 24, color: C.divider),
                          _buildAchievementRow(
                            context,
                            title: 'Silver Spark',
                            range: '100 - 199 Days',
                            color: Colors.orange,
                            isActive: streakDays >= 100 && streakDays <= 199,
                            isUnlocked: streakDays >= 100,
                          ),
                          const Divider(height: 24, color: C.divider),
                          _buildAchievementRow(
                            context,
                            title: 'Purple Blaze',
                            range: '200 - 299 Days',
                            color: Colors.purple,
                            isActive: streakDays >= 200 && streakDays <= 299,
                            isUnlocked: streakDays >= 200,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Banner info
                    CC(
                      bg: C.bg,
                      boxShadow: const [],
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
      ),
    );
  }
}