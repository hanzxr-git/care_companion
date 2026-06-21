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
import 'screens/circle_management_screen.dart';
import 'screens/auth/join_circle_screen.dart';
import 'widgets/circle_wellness_graph.dart';

class MonitorTab extends StatelessWidget {
  final CircleModel circle;
  final List<CircleModel> allCircles;
  final Function(String) onSwitchCircle;

  const MonitorTab({
    super.key,
    required this.circle,
    required this.allCircles,
    required this.onSwitchCircle,
  });

  Future<void> _createCircle(BuildContext context, String uid) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Circle', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Circle Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final name = controller.text.trim();
      if (name.isNotEmpty) {
        final db = context.read<FirestoreService>();
        try {
          final newCircle = await db.createCircle(uid, name);
          if (context.mounted) {
            onSwitchCircle(newCircle.circleId);
            C.showSuccess(context, 'Circle Created', 'Welcome to "${newCircle.name}"!');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to create circle.'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    }
  }

  void _showCircleSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        final auth = bottomSheetCtx.read<AuthService>();
        final db = bottomSheetCtx.read<FirestoreService>();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Switch Circle',
                style: TextStyle(fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Active circles
                    ...allCircles.map((c) => ListTile(
                          leading: Icon(
                            Icons.people_alt_rounded,
                            color: c.circleId == circle.circleId ? C.primary : C.textLight,
                          ),
                          title: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: c.circleId == circle.circleId ? FontWeight.bold : FontWeight.normal,
                              color: c.circleId == circle.circleId ? C.primary : C.textDark,
                            ),
                          ),
                          trailing: c.circleId == circle.circleId ? const Icon(Icons.check_rounded, color: C.primary) : null,
                          onTap: () {
                            Navigator.pop(bottomSheetCtx);
                            if (c.circleId != circle.circleId) {
                              onSwitchCircle(c.circleId);
                            }
                          },
                        )),
                  ],
                ),
              ),

              // Pending circles
              StreamBuilder<List<CircleModel>>(
                stream: db.streamMyPendingCircles(auth.uid!),
                builder: (context, pendingSnap) {
                  final pendingCircles = pendingSnap.data ?? [];
                  if (pendingCircles.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: C.divider, height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Text(
                          'PENDING REQUESTS',
                          style: TextStyle(
                            fontSize: C.fCap,
                            fontWeight: FontWeight.w800,
                            color: C.orange,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...pendingCircles.map((c) => ListTile(
                            leading: const Icon(Icons.hourglass_top_rounded, color: C.orange),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: C.textMid,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: C.orangeSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: C.orange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            onTap: null, // Can't switch to a pending circle
                          )),
                    ],
                  );
                },
              ),

              const Divider(color: C.divider, height: 24),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded, color: C.primary),
                title: const Text(
                  'Create New Circle',
                  style: TextStyle(fontWeight: FontWeight.bold, color: C.primary),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetCtx);
                  _createCircle(context, auth.uid!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key_rounded, color: C.primary),
                title: const Text(
                  'Join Another Circle',
                  style: TextStyle(fontWeight: FontWeight.bold, color: C.primary),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinCircleScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _leaveCircle(BuildContext context) async {
    final auth = context.read<AuthService>();
    final db = context.read<FirestoreService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Circle', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to leave this circle?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: C.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await db.leaveCircle(circle.circleId, auth.uid!);
        if (context.mounted) {
          C.showSuccess(context, 'Left Circle', 'You have left "${circle.name}"');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to leave circle.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final auth = context.watch<AuthService>();
    final db = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<CircleModel?>(
        stream: db.streamCircle(circle.circleId),
        builder: (context, circleSnap) {
          final activeCircle = circleSnap.data ?? circle;

          return StreamBuilder<List<UserModel>>(
            stream: db.streamCircleMemberProfiles(activeCircle.memberUids),
            builder: (context, snapshot) {
              final members = snapshot.data ?? [];
              final visibleMembers = members.where((m) => m.uid != auth.uid!).toList();

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
                    title: GestureDetector(
                      onTap: () => _showCircleSwitcher(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeCircle.name,
                              style: TextStyle(
                                fontSize: context.fs(C.fTitle - 4),
                                fontWeight: FontWeight.w900,
                                color: C.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, color: C.primary, size: context.fs(24)),
                        ],
                      ),
                    ),
                    actions: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _leaveCircle(context),
                            child: Container(
                              width: e ? 46 : 40,
                              height: e ? 46 : 40,
                              decoration: const BoxDecoration(color: C.surface, shape: BoxShape.circle),
                              child: Icon(Icons.exit_to_app_rounded, color: C.textMid, size: e ? 22 : 18),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => InviteSheet(circle: activeCircle),
                            ),
                            child: Container(
                              width: e ? 46 : 40,
                              height: e ? 46 : 40,
                              decoration: BoxDecoration(
                                color: C.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: C.primary.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.person_add_rounded, color: Colors.white, size: e ? 22 : 18),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                    // Pending Join Requests
                    if (activeCircle.ownerId == auth.uid! && activeCircle.pendingRequestUids.isNotEmpty) ...[
                      StreamBuilder<List<UserModel>>(
                        stream: db.streamCircleMemberProfiles(activeCircle.pendingRequestUids),
                        builder: (context, pendingSnap) {
                          final pendingUsers = pendingSnap.data ?? [];
                          if (pendingUsers.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_add_alt_1_outlined, color: C.red, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PENDING JOIN REQUESTS',
                                    style: TextStyle(
                                      fontSize: context.fs(C.fCap),
                                      fontWeight: FontWeight.w800,
                                      color: C.red,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...pendingUsers.map((u) {
                                final request = activeCircle.pendingRequests.firstWhere((r) => r.uid == u.uid);
                                final roleLabel = 'MEMBER';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: C.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: C.textDark.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      u.buildAvatar(radius: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.username,
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: C.fBody, color: C.textDark),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              roleLabel,
                                              style: const TextStyle(fontSize: C.fTiny, fontWeight: FontWeight.w800, color: C.textMid, letterSpacing: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => db.acceptJoinRequest(activeCircle.circleId, u.uid, request.role),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () => db.declineJoinRequest(activeCircle.circleId, u.uid),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                          child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ],

                    StreamBuilder<List<CheckinModel>>(
                      stream: db.streamAllMonthlyCheckins(activeCircle.circleId),
                      builder: (context, checkinSnap) {
                        final checkins = checkinSnap.data ?? [];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: CircleWellnessGraph(checkins: checkins, members: members),
                        );
                      },
                    ),

                    // Circle Members Label / Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const CapLabel('CIRCLE MEMBERS'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: C.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.divider, width: 1.5),
                          ),
                          child: Text(
                            '${visibleMembers.length} ACTIVE',
                            style: const TextStyle(
                              fontSize: C.fCap - 1,
                              fontWeight: FontWeight.w900,
                              color: C.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                                  'Your Circle is Empty',
                                  style: TextStyle(fontSize: context.fs(C.fH2), fontWeight: FontWeight.w900, color: C.textDark),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Invite family members to join using the invite button at the top.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: context.fs(C.fSub), color: C.textMid, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ...visibleMembers.map((m) => _MemberCard(
                            member: m,
                            circle: activeCircle,
                            elder: e,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m, circle: activeCircle)),
                            ),
                          )),
                    ],

                    const SizedBox(height: 16),

                    // Circle Management Button
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CircleManagementScreen(circle: activeCircle)),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: C.textDark.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.tune_rounded, color: C.textMid, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'CIRCLE MANAGEMENT',
                              style: TextStyle(
                                fontSize: context.fs(C.fSub),
                                fontWeight: FontWeight.w800,
                                color: C.textMid,
                                letterSpacing: 1,
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

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return '😄';
      case 'good':
        return '🙂';
      case 'okay':
        return '😐';
      case 'low':
        return '😔';
      case 'sad':
        return '😢';
      default:
        return '🙂';
    }
  }

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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Main Card
                          GestureDetector(
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: C.surface,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: C.textDark.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                                        ),
                                        child: member.buildAvatar(radius: elder ? 28 : 24),
                                      ),
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
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

                                  // Center details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                member.username,
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fH3),
                                                  fontWeight: FontWeight.w900,
                                                  color: C.textDark,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Streak & Mood Emoji Row
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: C.primarySoft.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.local_fire_department_rounded, color: C.primary, size: 14),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '$streakDays',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (todayCheckin?.mood != null) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                _getMoodEmoji(todayCheckin!.mood!),
                                                style: const TextStyle(fontSize: 24),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_rounded, size: 13, color: C.textLight),
                                            const SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                agoText.isNotEmpty ? '$locLabel • $agoText'.toUpperCase() : locLabel.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fTiny),
                                                  color: C.textLight,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _badge(
                                              checkedInToday ? 'CHECKED-IN' : 'MISSED',
                                              checkedInToday ? C.green : C.orange,
                                              checkedInToday ? C.greenSoft : C.orangeSoft,
                                              context,
                                            ),
                                            const SizedBox(width: 8),
                                            _badge(
                                              '$medsDone/$totalMeds MEDS',
                                              C.primary,
                                              C.primarySoft,
                                              context,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // SOS Banner overlay
                          if (member.sosActive)
                            Positioned(
                              top: -6,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: C.red,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: C.red.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'SOS ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
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
        );
      },
    );
  }

  Widget _badge(String label, Color color, Color bgColor, BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: ctx.fs(C.fCap - 1), fontWeight: FontWeight.w900, color: color)),
      );
}