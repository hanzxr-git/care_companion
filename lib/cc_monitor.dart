// cc_monitor.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/checkin_model.dart';
import 'models/medicine_model.dart';
import 'models/location_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'member_detail.dart';
import 'cc_invite.dart';

class MonitorTab extends StatelessWidget {
  final CircleModel circle;
  const MonitorTab({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final auth = context.watch<AuthService>();
    final db = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<UserModel>>(
        stream: db.streamCircleMemberProfiles(circle.memberUids),
        builder: (context, snapshot) {
          final members = snapshot.data ?? [];
          final visibleMembers = members.where((m) => m.uid != auth.uid!).toList();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monitor', style: TextStyle(fontSize: context.fs(C.fTitle), fontWeight: FontWeight.w900, color: C.textDark)),
                        Text(
                          'YOUR FAMILY CIRCLE',
                          style: TextStyle(fontSize: context.fs(C.fCap), color: C.textMid, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => InviteSheet(circle: circle),
                      ),
                      child: Container(
                        width: e ? 46 : 40,
                        height: e ? 46 : 40,
                        decoration: const BoxDecoration(color: C.primarySoft, shape: BoxShape.circle),
                        child: Icon(Icons.person_add_outlined, color: C.primary, size: e ? 22 : 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (visibleMembers.isEmpty)
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      CC(
                        pad: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline_rounded, size: e ? 60 : 48, color: C.textLight),
                            const SizedBox(height: 16),
                            Text(
                              'Your Family Circle is Empty',
                              style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: C.textDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invite your parents or family members to join and start tracking their wellness.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  const CapLabel('FAMILY MEMBERS'),
                  const SizedBox(height: 10),

                  ...visibleMembers.map((m) => _MemberCard(
                        member: m,
                        circle: circle,
                        elder: e,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m, circle: circle)),
                        ),
                      )),
                ],

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InviteSheet(circle: circle),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.textLight, style: BorderStyle.solid, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, color: C.textLight, size: e ? 22 : 18),
                        const SizedBox(width: 10),
                        Text(
                          'ADD A PERSON',
                          style: TextStyle(fontSize: context.fs(C.fSub), fontWeight: FontWeight.w800, color: C.textLight, letterSpacing: 1),
                        ),
                      ],
                    ),
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

class _MemberCard extends StatelessWidget {
  final UserModel member;
  final CircleModel circle;
  final bool elder;
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.circle,
    required this.elder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final color = Color(member.avatarColorValue);

    return StreamBuilder<List<CheckinModel>>(
      stream: db.streamRecentCheckins(member.uid, circle.circleId),
      builder: (context, checkinSnap) {
        final checkins = checkinSnap.data ?? [];
        final todayCheckin = checkins.isEmpty ? null : (checkins.first.isToday ? checkins.first : null);
        final checkedInToday = todayCheckin != null;
        final streakDays = checkins.isEmpty ? 0 : checkins.first.streakDay;

        return StreamBuilder<LocationModel?>(
          stream: db.streamLocation(member.uid),
          builder: (context, locSnap) {
            final location = locSnap.data;
            final locLabel = location?.sharing == true ? location?.label ?? 'Location unavailable' : 'Location private';
            final agoText = location?.sharing == true ? location?.agoText ?? '' : '';

            return StreamBuilder<List<MedicineModel>>(
              stream: db.streamMedicines(member.uid),
              builder: (context, medsSnap) {
                final medicines = medsSnap.data ?? [];

                return StreamBuilder<List<MedLogModel>>(
                  stream: db.streamTodayMedLogs(member.uid),
                  builder: (context, logsSnap) {
                    final logs = logsSnap.data ?? [];

                    final totalMeds = medicines.where((m) => m.isScheduledToday).fold<int>(0, (sum, m) => sum + m.times.length);
                    final medsDone = medicines.where((m) => m.isScheduledToday).fold<int>(0, (sum, m) {
                      final takenTimes = m.times.where((t) => logs.any((l) => l.medId == m.medId && l.scheduledTime == t)).length;
                      return sum + takenTimes;
                    });

                    return GestureDetector(
                      onTap: onTap,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: elder ? 28 : 24,
                                      backgroundColor: color.withOpacity(0.2),
                                      child: Text(
                                        member.avatarInitials,
                                        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: context.fs(elder ? 16 : 14)),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: elder ? 14 : 12,
                                        height: elder ? 14 : 12,
                                        decoration: BoxDecoration(
                                          color: checkedInToday ? C.green : C.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: C.surface, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.displayName,
                                        style: TextStyle(fontSize: context.fs(C.fH3), fontWeight: FontWeight.w900, color: C.textDark),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, size: context.fs(12), color: C.textMid),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              agoText.isNotEmpty ? '$locLabel · $agoText' : locLabel,
                                              style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: C.textLight, size: elder ? 24 : 20),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _badge(checkedInToday ? 'CHECKED IN' : 'NOT CHECKED', checkedInToday ? C.green : C.orange, context),
                                const SizedBox(width: 8),
                                _badge('$medsDone/$totalMeds MEDS', C.textMid, context),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: checkedInToday
                                          ? (streakDays >= 200
                                              ? Colors.purple
                                              : (streakDays >= 100 ? Colors.orange : Colors.red))
                                          : Colors.grey.shade400,
                                      size: elder ? 17 : 15,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$streakDays',
                                      style: TextStyle(
                                        fontSize: context.fs(C.fSub),
                                        fontWeight: FontWeight.w900,
                                        color: checkedInToday
                                            ? (streakDays >= 200
                                                ? Colors.purple
                                                : (streakDays >= 100 ? Colors.orange : Colors.red))
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _badge(String label, Color color, BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: ctx.fs(C.fCap), fontWeight: FontWeight.w800, color: color)),
      );
}