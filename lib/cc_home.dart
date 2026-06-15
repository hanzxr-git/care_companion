// cc_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'cc_invite.dart';
import 'member_detail.dart';
import 'models/circle_model.dart';
import 'models/user_model.dart';
import 'models/checkin_model.dart';
import 'models/medicine_model.dart';
import 'models/location_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';

class HomeTab extends StatefulWidget {
  final CircleModel circle;
  final Function(int)? onNavigateToTab;
  const HomeTab({super.key, required this.circle, this.onNavigateToTab});

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

  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.uid != null) {
        _refreshLocationSilent(auth.uid!);
      }
    });
  }

  void _refreshLocationSilent(String uid) async {
    try {
      final locService = context.read<LocationService>();
      final doc = await FirebaseFirestore.instance.collection('locations').doc(uid).get();
      final sharing = doc.data()?['sharing'] ?? true;
      await locService.updateCurrentLocation(uid, sharing: sharing);
    } catch (e) {
      debugPrint('[HomeTab] Silent location update failed: $e');
    }
  }

  void _refreshLocation(String targetUid, bool currentSharing) async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);

    final locService = context.read<LocationService>();
    final result = await locService.updateCurrentLocation(targetUid, sharing: currentSharing);

    if (mounted) {
      setState(() => _isUpdatingLocation = false);
      if (result.success) {
        C.showSuccess(context, 'Location Updated', result.label ?? 'Current location refreshed.');
      } else {
        _showLocationDialog(result, targetUid, currentSharing);
      }
    }
  }

  void _showLocationDialog(LocationResult result, String targetUid, bool currentSharing) {
    final errorType = result.errorType;
    IconData icon;
    String actionLabel;
    VoidCallback actionCallback;

    switch (errorType) {
      case LocationErrorType.serviceDisabled:
        icon = Icons.gps_off_rounded;
        actionLabel = 'Turn On GPS';
        actionCallback = () {
          Navigator.pop(context);
          LocationService.openLocationSettings();
        };
      case LocationErrorType.permissionDenied:
        icon = Icons.lock_outline_rounded;
        actionLabel = 'Allow Permission';
        actionCallback = () {
          Navigator.pop(context);
          LocationService.openAppSettings();
        };
      case LocationErrorType.permissionDeniedForever:
        icon = Icons.settings_rounded;
        actionLabel = 'Open App Settings';
        actionCallback = () {
          Navigator.pop(context);
          LocationService.openAppSettings();
        };
      default:
        icon = Icons.refresh_rounded;
        actionLabel = 'Retry';
        actionCallback = () {
          Navigator.pop(context);
          _refreshLocation(targetUid, currentSharing);
        };
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: C.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFDE8E8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: C.red, size: 32),
            ),
            const SizedBox(height: 18),
            const Text(
              'Location Unavailable',
              style: TextStyle(
                fontSize: C.fH3,
                fontWeight: FontWeight.w900,
                color: C.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              result.message,
              style: const TextStyle(
                fontSize: C.fBody,
                color: C.textMid,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: actionCallback,
                icon: Icon(icon, size: 20),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: C.fBody)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: C.textMid, fontWeight: FontWeight.w700, fontSize: C.fBody)),
            ),
          ],
        ),
      ),
    );
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

  void _selectMood(String moodName, String targetUid, String circleId, CheckinModel? todayCheckin, int currentStreak) async {
    try {
      if (todayCheckin != null) {
        // Update existing check-in directly (no composite query needed)
        await FirebaseFirestore.instance
            .collection('checkins')
            .doc(todayCheckin.checkinId)
            .update({
          'mood': moodName,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        // Create a new check-in directly
        final ref = FirebaseFirestore.instance.collection('checkins').doc();
        await ref.set({
          'uid': targetUid,
          'circleId': circleId,
          'mood': moodName,
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'streakDay': currentStreak + 1,
        });
      }
      if (mounted) {
        C.showSuccess(context, 'Mood Logged', 'Logged today\'s mood as ${moodName.toLowerCase()}.');
      }
    } catch (e) {
      debugPrint('[HomeTab] _selectMood error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to log mood: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update medication log.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showAddMedicine(BuildContext context, String targetUid, String creatorUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMedicineSheet(targetUid: targetUid, creatorUid: creatorUid),
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
                                  _capitalizeEachWord(user.displayName),
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
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: PressableCard(
                                  onTap: () {
                                    C.showNotification(
                                      context,
                                      title: "Notifications",
                                      message: "No new notifications",
                                      icon: Icons.notifications_none_rounded,
                                      color: C.primary,
                                      backgroundColor: C.primarySoft,
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  color: C.primarySoft,
                                  borderRadius: BorderRadius.circular(24),
                                  child: SizedBox(
                                    width: e ? 48 : 42,
                                    height: e ? 48 : 42,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.notifications_outlined,
                                          color: C.primary,
                                          size: context.ic,
                                        ),
                                        Positioned(
                                          top: e ? 12 : 10,
                                          right: e ? 12 : 10,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: C.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // ── Daily Streak card
                                PressableCard(
                                  onTap: () => widget.onNavigateToTab?.call(1),
                                  padding: EdgeInsets.zero,
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: C.primary.withValues(alpha: 0.10),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(color: const Color(0xFFCCC5FD), width: 1.5),
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFE6E2FF),
                                          Color(0xFFF4F2FF),
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: e ? 56 : 48,
                                          height: e ? 56 : 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.whatshot_rounded,
                                            color: todayCheckin != null
                                                ? (streakDays >= 200
                                                    ? Colors.purple
                                                    : (streakDays >= 100 ? Colors.orange : Colors.red))
                                                : Colors.grey.shade400,
                                            size: e ? 28 : 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Daily Streak',
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fH3),
                                                  fontWeight: FontWeight.w900,
                                                  color: C.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$streakDays DAYS SAFE',
                                                style: TextStyle(
                                                  fontSize: context.fs(C.fCap),
                                                  color: C.textMid,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$streakDays',
                                          style: TextStyle(
                                            fontSize: context.fs(48),
                                            fontWeight: FontWeight.w900,
                                            color: C.primary,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const CapLabel('YOUR MOOD'),
                                const SizedBox(height: 10),

                                // ── Mood picker capsule
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: _moods.asMap().entries.map((en) {
                                      final emoji = en.value.$1;
                                      final moodName = en.value.$2;
                                      final isSelected = todayCheckin?.mood?.toUpperCase() == moodName;

                                      return PressableCard(
                                        onTap: () => _selectMood(moodName, targetUid, widget.circle.circleId, todayCheckin, streakDays),
                                        scaleOnPress: 0.9,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        color: isSelected ? C.primarySoft : Colors.transparent,
                                        boxShadow: const [],
                                        borderRadius: BorderRadius.circular(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              emoji,
                                              style: TextStyle(
                                                fontSize: context.fs(e ? 32 : 28),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              moodName,
                                              style: TextStyle(
                                                fontSize: context.fs(C.fTiny),
                                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                                color: isSelected ? C.primary : C.textLight,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),

                                // ── Live Location section
                                const SizedBox(height: 22),
                                StreamBuilder<LocationModel?>(
                                  stream: db.streamLocation(targetUid),
                                  builder: (context, locSnap) {
                                    final location = locSnap.data;
                                    final sharing = location?.sharing ?? false;
                                    final hasLocation = location != null;

                                    final label = hasLocation ? location.label : 'Tap refresh to get location';
                                    final agoText = hasLocation ? 'UPDATED ${location.agoText.toUpperCase()}' : 'NO LOCATION DATA';
                                    final showMap = hasLocation;

                                    Widget buildMapPlaceholder() {
                                      if (showMap) {
                                        return Stack(
                                          children: [
                                            // 3-tile wide OSM map strip
                                            Row(
                                              children: [-1, 0, 1].map((dx) {
                                                return Expanded(
                                                  child: Image.network(
                                                    LocationService.getMapTileUrl(location.lat, location.lng, dx: dx),
                                                    headers: const {'User-Agent': 'CareCompanion/2.0'},
                                                    fit: BoxFit.cover,
                                                    height: 160,
                                                    errorBuilder: (_, _, _) => Container(color: C.primarySoft),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            // Location pin marker
                                            Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: C.primary,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: C.primary.withValues(alpha: 0.4),
                                                          blurRadius: 12,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                                                  ),
                                                  Container(
                                                    width: 2,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: C.primary,
                                                      borderRadius: BorderRadius.circular(1),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // OSM attribution
                                            Positioned(
                                              bottom: 4,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  '© OpenStreetMap',
                                                  style: TextStyle(fontSize: 8, color: C.textMid),
                                                ),
                                              ),
                                            ),
                                            // Loading overlay
                                            if (_isUpdatingLocation)
                                              Container(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 28,
                                                    height: 28,
                                                    child: CircularProgressIndicator(color: C.primary, strokeWidth: 2.5),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      }

                                      // Grid locator placeholder when no location yet
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              C.primarySoft,
                                              C.primary.withValues(alpha: 0.15),
                                              C.greenSoft,
                                            ],
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ...List.generate(5, (i) => Positioned(
                                              left: 0, right: 0,
                                              top: (i + 1) * 32.0,
                                              child: Container(height: 0.5, color: C.primary.withValues(alpha: 0.08)),
                                            )),
                                            ...List.generate(4, (i) => Positioned(
                                              top: 0, bottom: 0,
                                              left: (i + 1) * 80.0,
                                              child: Container(width: 0.5, color: C.primary.withValues(alpha: 0.08)),
                                            )),
                                            Icon(Icons.location_searching, color: C.primary.withValues(alpha: 0.3), size: 48),
                                            if (_isUpdatingLocation)
                                              Container(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 28,
                                                    height: 28,
                                                    child: CircularProgressIndicator(color: C.primary, strokeWidth: 2.5),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const CapLabel('LIVE LOCATION'),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'SHARING',
                                                  style: TextStyle(
                                                    fontSize: context.fs(C.fCap),
                                                    fontWeight: FontWeight.w800,
                                                    color: C.primary,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: sharing ? C.primary : C.textLight,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: SizedBox(
                                                    height: 26,
                                                    child: Switch(
                                                      value: sharing,
                                                      activeThumbColor: C.primary,
                                                      activeTrackColor: C.primarySoft,
                                                      inactiveThumbColor: C.textLight,
                                                      inactiveTrackColor: C.divider,
                                                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                                      onChanged: (val) {
                                                        if (hasLocation) {
                                                          db.updateLocation(
                                                            uid: targetUid,
                                                            lat: location.lat,
                                                            lng: location.lng,
                                                            label: location.label,
                                                            sharing: val,
                                                          );
                                                        } else {
                                                          _refreshLocation(targetUid, val);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        PressableCard(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                          onTap: () => _refreshLocation(targetUid, sharing),
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Real OSM map or placeholder
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(14),
                                                child: SizedBox(
                                                  height: 160,
                                                  width: double.infinity,
                                                  child: buildMapPlaceholder(),
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: e ? 46 : 40,
                                                    height: e ? 46 : 40,
                                                    decoration: BoxDecoration(
                                                      color: hasLocation ? C.primarySoft : C.orangeSoft,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      hasLocation ? Icons.location_on_outlined : Icons.location_searching,
                                                      color: hasLocation ? C.primary : C.orange,
                                                      size: context.ic,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          label,
                                                          style: TextStyle(
                                                            fontSize: context.fs(C.fBody),
                                                            fontWeight: FontWeight.w800,
                                                            color: C.textDark,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          agoText,
                                                          style: TextStyle(
                                                            fontSize: context.fs(C.fSub),
                                                            color: C.textMid,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PressableCard(
                                                    onTap: () => _refreshLocation(targetUid, sharing),
                                                    scaleOnPress: 0.9,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    color: C.primarySoft,
                                                    borderRadius: BorderRadius.circular(12),
                                                    boxShadow: const [],
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _isUpdatingLocation ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                                                          color: C.primary,
                                                          size: e ? 18 : 14,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'REFRESH',
                                                          style: TextStyle(
                                                            fontSize: context.fs(C.fTiny),
                                                            fontWeight: FontWeight.w900,
                                                            color: C.primary,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                     );
                                   },
                                 ),
                                 const SizedBox(height: 22),

                                 // ── Family Circle Section
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     const CapLabel('FAMILY CIRCLE'),
                                     GestureDetector(
                                       onTap: () => widget.onNavigateToTab?.call(3),
                                       child: Text(
                                         'MANAGE',
                                         style: TextStyle(
                                           fontSize: context.fs(C.fCap),
                                           fontWeight: FontWeight.w900,
                                           color: C.primary,
                                           decoration: TextDecoration.underline,
                                           letterSpacing: 1.2,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 10),

                                 StreamBuilder<List<UserModel>>(
                                   stream: db.streamCircleMemberProfiles(widget.circle.memberUids),
                                   builder: (context, membersSnap) {
                                     final members = membersSnap.data ?? [];
                                     final otherMembers = members.where((m) => m.uid != auth.uid).toList();

                                     if (otherMembers.isEmpty) {
                                       return PressableCard(
                                         onTap: () {
                                           widget.onNavigateToTab?.call(3);
                                           Future.delayed(const Duration(milliseconds: 500), () {
                                             if (context.mounted) {
                                               showModalBottomSheet(
                                                 context: context,
                                                 isScrollControlled: true,
                                                 backgroundColor: Colors.transparent,
                                                 builder: (_) => InviteSheet(circle: widget.circle),
                                               );
                                             }
                                           });
                                         },
                                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                         child: Column(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             Container(
                                               width: 56,
                                               height: 56,
                                               decoration: const BoxDecoration(
                                                 color: C.primarySoft,
                                                 shape: BoxShape.circle,
                                               ),
                                               child: const Icon(Icons.people_outline_rounded, color: C.primary, size: 28),
                                             ),
                                             const SizedBox(height: 14),
                                             Text(
                                               'No other circle members',
                                               style: TextStyle(
                                                 fontSize: context.fs(C.fBody),
                                                 color: C.textDark,
                                                 fontWeight: FontWeight.w800,
                                               ),
                                               textAlign: TextAlign.center,
                                             ),
                                             const SizedBox(height: 4),
                                             Text(
                                               'Add members to start sharing location, checking in, and monitoring together.',
                                               style: TextStyle(
                                                 fontSize: context.fs(C.fSub),
                                                 color: C.textMid,
                                                 fontWeight: FontWeight.w600,
                                               ),
                                               textAlign: TextAlign.center,
                                             ),
                                             const SizedBox(height: 18),
                                             Material(
                                               color: C.primary,
                                               borderRadius: BorderRadius.circular(24),
                                               child: InkWell(
                                                 onTap: () {
                                                   widget.onNavigateToTab?.call(3);
                                                   Future.delayed(const Duration(milliseconds: 500), () {
                                                     if (context.mounted) {
                                                       showModalBottomSheet(
                                                         context: context,
                                                         isScrollControlled: true,
                                                         backgroundColor: Colors.transparent,
                                                         builder: (_) => InviteSheet(circle: widget.circle),
                                                       );
                                                     }
                                                   });
                                                 },
                                                 borderRadius: BorderRadius.circular(24),
                                                 splashColor: Colors.white24,
                                                 child: Container(
                                                   width: double.infinity,
                                                   padding: const EdgeInsets.symmetric(vertical: 14),
                                                   child: Row(
                                                     mainAxisAlignment: MainAxisAlignment.center,
                                                     children: [
                                                       const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                                       const SizedBox(width: 8),
                                                       Text(
                                                         'Add Member',
                                                         style: TextStyle(
                                                           color: Colors.white,
                                                           fontWeight: FontWeight.w900,
                                                           fontSize: context.fs(C.fBody),
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ),
                                       );
                                     }

                                     return Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(
                                         color: C.primarySoft.withValues(alpha: 0.4),
                                         borderRadius: BorderRadius.circular(24),
                                         border: Border.all(color: const Color(0xFFCCC5FD).withValues(alpha: 0.5), width: 1.5),
                                         boxShadow: [
                                           BoxShadow(
                                             color: Colors.black.withValues(alpha: 0.06),
                                             blurRadius: 16,
                                             spreadRadius: 1,
                                             offset: const Offset(0, 6),
                                           ),
                                         ],
                                       ),
                                       child: Column(
                                         children: otherMembers.asMap().entries.map((en) {
                                           final idx = en.key;
                                           final member = en.value;

                                           return Column(
                                             children: [
                                               if (idx > 0) const SizedBox(height: 12),
                                               PressableCard(
                                                 onTap: () {
                                                   Navigator.push(
                                                     context,
                                                     MaterialPageRoute(
                                                       builder: (_) => MemberDetailScreen(member: member, circle: widget.circle),
                                                     ),
                                                   );
                                                 },
                                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                 child: Row(
                                                   children: [
                                                     // Avatar with border and optional alert dot
                                                     Stack(
                                                       clipBehavior: Clip.none,
                                                       children: [
                                                         Container(
                                                           decoration: BoxDecoration(
                                                             shape: BoxShape.circle,
                                                             border: Border.all(color: C.primary, width: 2),
                                                           ),
                                                           padding: const EdgeInsets.all(2),
                                                           child: CircleAvatar(
                                                             radius: 24,
                                                             backgroundColor: Color(member.avatarColorValue),
                                                             child: Text(
                                                               member.avatarInitials,
                                                               style: const TextStyle(
                                                                 color: Colors.white,
                                                                 fontWeight: FontWeight.w900,
                                                               ),
                                                             ),
                                                           ),
                                                         ),
                                                         if (member.sosActive)
                                                           Positioned(
                                                             top: 0,
                                                             right: 0,
                                                             child: Container(
                                                               width: 14,
                                                               height: 14,
                                                               decoration: const BoxDecoration(
                                                                 color: Color(0xFFFF6B6B),
                                                                 shape: BoxShape.circle,
                                                               ),
                                                             ),
                                                           ),
                                                       ],
                                                     ),
                                                     const SizedBox(width: 14),
                                                     // Details Column
                                                     Expanded(
                                                       child: Column(
                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                         children: [
                                                           // Name row + streak + mood
                                                           StreamBuilder<List<CheckinModel>>(
                                                             stream: db.streamRecentCheckins(member.uid, widget.circle.circleId),
                                                             builder: (context, checkinSnap) {
                                                               final checkins = checkinSnap.data ?? [];
                                                               final todayCheckin = checkins.isEmpty ? null : (checkins.first.isToday ? checkins.first : null);
                                                               final streakDays = _calculateActiveStreak(checkins);
                                                               final moodEmoji = _moods.firstWhere((m) => m.$2 == todayCheckin?.mood?.toUpperCase(), orElse: () => ('', '')).$1;
                                                               final streakActive = streakDays > 0;

                                                               return Row(
                                                                 children: [
                                                                   Expanded(
                                                                     child: Text(
                                                                       _capitalizeEachWord(member.displayName),
                                                                       style: TextStyle(
                                                                         fontSize: context.fs(C.fBody),
                                                                         fontWeight: FontWeight.w800,
                                                                         color: C.textDark,
                                                                       ),
                                                                       maxLines: 1,
                                                                       overflow: TextOverflow.ellipsis,
                                                                     ),
                                                                   ),
                                                                   const SizedBox(width: 8),
                                                                   // Streak Pill
                                                                   Container(
                                                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                     decoration: BoxDecoration(
                                                                       color: C.primarySoft,
                                                                       borderRadius: BorderRadius.circular(12),
                                                                     ),
                                                                     child: Row(
                                                                       mainAxisSize: MainAxisSize.min,
                                                                       children: [
                                                                         Icon(
                                                                           Icons.whatshot_rounded,
                                                                           color: streakActive
                                                                               ? (streakDays >= 200
                                                                                   ? Colors.purple
                                                                                   : (streakDays >= 100 ? Colors.orange : Colors.red))
                                                                               : Colors.grey.shade400,
                                                                           size: 14,
                                                                         ),
                                                                         const SizedBox(width: 4),
                                                                         Text(
                                                                           '$streakDays',
                                                                           style: TextStyle(
                                                                             fontSize: context.fs(C.fTiny),
                                                                             fontWeight: FontWeight.w900,
                                                                             color: C.primary,
                                                                           ),
                                                                         ),
                                                                       ],
                                                                     ),
                                                                   ),
                                                                   if (moodEmoji.isNotEmpty) ...[
                                                                     const SizedBox(width: 8),
                                                                     Text(
                                                                       moodEmoji,
                                                                       style: const TextStyle(fontSize: 24),
                                                                     ),
                                                                   ],
                                                                 ],
                                                               );
                                                             },
                                                           ),
                                                           const SizedBox(height: 4),
                                                           // Location row
                                                           StreamBuilder<LocationModel?>(
                                                             stream: db.streamLocation(member.uid),
                                                             builder: (context, locSnap) {
                                                               final loc = locSnap.data;
                                                               final label = loc != null ? loc.label.toUpperCase() : 'UNKNOWN';
                                                               final ago = loc != null ? loc.agoText.toUpperCase() : 'NEVER';

                                                               return Text(
                                                                 '$label · $ago',
                                                                 style: TextStyle(
                                                                   fontSize: context.fs(C.fSub),
                                                                   color: C.textMid,
                                                                   fontWeight: FontWeight.w600,
                                                                 ),
                                                               );
                                                             },
                                                           ),
                                                           const SizedBox(height: 8),
                                                           // Meds count pill + SOS Active pill
                                                           StreamBuilder<List<MedicineModel>>(
                                                             stream: db.streamMedicines(member.uid),
                                                             builder: (context, medsSnap) {
                                                               final medicines = medsSnap.data ?? [];
                                                               return StreamBuilder<List<MedLogModel>>(
                                                                 stream: db.streamTodayMedLogs(member.uid),
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
                                                                   final totalCount = displayMeds.length;

                                                                   return Wrap(
                                                                     spacing: 8,
                                                                     runSpacing: 4,
                                                                     children: [
                                                                       Container(
                                                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                                         decoration: BoxDecoration(
                                                                           color: C.primarySoft.withValues(alpha: 0.5),
                                                                           borderRadius: BorderRadius.circular(12),
                                                                         ),
                                                                         child: Text(
                                                                           '$takenCount/$totalCount MEDS',
                                                                           style: TextStyle(
                                                                             fontSize: context.fs(C.fTiny),
                                                                             fontWeight: FontWeight.w800,
                                                                             color: C.primary,
                                                                           ),
                                                                         ),
                                                                       ),
                                                                       if (member.sosActive)
                                                                         Container(
                                                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                                           decoration: BoxDecoration(
                                                                             color: const Color(0xFFFFB2B2),
                                                                             borderRadius: BorderRadius.circular(12),
                                                                           ),
                                                                           child: const Text(
                                                                             'SOS ACTIVE',
                                                                             style: TextStyle(
                                                                               fontSize: 10,
                                                                               fontWeight: FontWeight.w900,
                                                                               color: Color(0xFFD32F2F),
                                                                             ),
                                                                           ),
                                                                         ),
                                                                     ],
                                                                   );
                                                                 },
                                                               );
                                                             },
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                     const SizedBox(width: 8),
                                                     Icon(
                                                       Icons.chevron_right_rounded,
                                                       color: C.textLight,
                                                       size: context.ic,
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                             ],
                                           );
                                         }).toList(),
                                       ),
                                     );
                                   },
                                 ),
                                 const SizedBox(height: 22),

                                // ── Medications header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const CapLabel('MEDICATIONS'),
                                    GestureDetector(
                                      onTap: () => widget.onNavigateToTab?.call(2),
                                      child: Text(
                                        'DETAILS',
                                        style: TextStyle(
                                          fontSize: context.fs(C.fCap),
                                          fontWeight: FontWeight.w900,
                                          color: C.primary,
                                          decoration: TextDecoration.underline,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // ── Med list container
                                Container(
                                  padding: EdgeInsets.zero,
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: displayMeds.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                          decoration: BoxDecoration(
                                            color: C.surface,
                                            borderRadius: BorderRadius.circular(24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    color: C.primarySoft,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.medication_outlined, color: C.primary, size: 28),
                                                ),
                                                const SizedBox(height: 14),
                                                Text(
                                                  'No medications scheduled',
                                                  style: TextStyle(
                                                    fontSize: context.fs(C.fBody),
                                                    color: C.textDark,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Add your first medication to get reminders',
                                                  style: TextStyle(
                                                    fontSize: context.fs(C.fSub),
                                                    color: C.textMid,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 18),
                                                Material(
                                                  color: C.primary,
                                                  borderRadius: BorderRadius.circular(24),
                                                  child: InkWell(
                                                    onTap: () {
                                                      widget.onNavigateToTab?.call(2);
                                                      Future.delayed(const Duration(milliseconds: 500), () {
                                                        if (context.mounted) {
                                                          _showAddMedicine(context, targetUid, auth.uid!);
                                                        }
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(24),
                                                    splashColor: Colors.white24,
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Add Medication',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: context.fs(C.fBody),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                      : Column(
                                          children: displayMeds.asMap().entries.map((en) {
                                            final idx = en.key;
                                            final item = en.value;

                                            return Column(
                                              children: [
                                                if (idx > 0) const SizedBox(height: 10),
                                                PressableCard(
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.06),
                                                      blurRadius: 16,
                                                      spreadRadius: 1,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                  ],
                                                  onTap: () => widget.onNavigateToTab?.call(2),
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
                                                        child: Icon(
                                                          Icons.medication_outlined,
                                                          color: item.taken ? C.green : C.primary,
                                                          size: context.ic,
                                                        ),
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
                                                              style: TextStyle(
                                                                fontSize: context.fs(C.fSub),
                                                                color: C.textMid,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      PressableCard(
                                                        onTap: () => _toggleMedTaken(
                                                              item.med,
                                                              targetUid,
                                                              item.time,
                                                              item.taken,
                                                            ),
                                                        scaleOnPress: 0.9,
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: e ? 22 : 18,
                                                          vertical: e ? 12 : 9,
                                                        ),
                                                        color: item.taken ? C.green : C.primary,
                                                        borderRadius: BorderRadius.circular(20),
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
                                 PressableCard(
                                   onTap: () => _sos(context, targetName, user.sosActive),
                                   color: user.sosActive ? C.green : C.red,
                                   borderRadius: BorderRadius.circular(32),
                                   boxShadow: [
                                     BoxShadow(
                                       color: (user.sosActive ? C.green : C.red).withValues(alpha: 0.3),
                                       blurRadius: 16,
                                       spreadRadius: 1,
                                       offset: const Offset(0, 6),
                                     ),
                                   ],
                                   padding: EdgeInsets.symmetric(vertical: e ? 20 : 16),
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       Icon(
                                         user.sosActive ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                         color: Colors.white,
                                         size: e ? 28 : 24,
                                       ),
                                       const SizedBox(width: 10),
                                       Text(
                                         user.sosActive ? 'RESOLVE SOS ALERT' : 'EMERGENCY SOS',
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

  void _sos(BuildContext ctx, String name, bool active) => showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(active ? 'Resolve SOS?' : 'Send SOS?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: C.fH2)),
          content: Text(
            active
                ? 'Are you sure you want to resolve the emergency alert for $name?'
                : 'This will immediately alert all family members in your circle about $name\'s emergency status.',
            style: const TextStyle(fontSize: C.fBody),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(fontSize: C.fBody))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final auth = ctx.read<AuthService>();
                final db = ctx.read<FirestoreService>();
                try {
                  await db.updateUser(auth.uid!, {'sosActive': !active});
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(active ? 'SOS Alert resolved.' : 'SOS Alert triggered!'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (_) {
                  // ignore
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? C.green : C.red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text(active ? 'Resolve' : 'Send SOS', style: const TextStyle(fontSize: C.fBody)),
            ),
          ],
        ),
      );
  String _capitalizeEachWord(String text) {
    if (text.trim().isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}

class _DisplayMed {
  final MedicineModel med;
  final String time;
  final bool taken;
  _DisplayMed({required this.med, required this.time, required this.taken});
}



class _AddMedicineSheet extends StatefulWidget {
  final String targetUid;
  final String creatorUid;
  const _AddMedicineSheet({required this.targetUid, required this.creatorUid});

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    setState(() => _selectedTime = time);
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
              onPressed: () async {
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
                    uid: widget.targetUid,
                    createdBy: widget.creatorUid,
                    name: name,
                    dosage: dosage,
                    times: [formattedTime],
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    C.showSuccess(context, 'Medicine Added', '$name schedule created.');
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Failed to add medicine. Please try again.'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
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
    );
  }
}