// services/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/circle_model.dart';
import '../models/checkin_model.dart';
import '../models/medicine_model.dart';
import '../models/location_model.dart';
import '../models/audit_log_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ─── Collection references ───────────────────────────────
  CollectionReference get _users     => _db.collection('users');
  CollectionReference get _circles   => _db.collection('circles');
  CollectionReference get _checkins  => _db.collection('checkins');
  CollectionReference get _medicines => _db.collection('medicines');
  CollectionReference get _medLogs   => _db.collection('med_logs');
  CollectionReference get _locations => _db.collection('locations');
  CollectionReference get _logs      => _db.collection('logs');

  // ─── USER ────────────────────────────────────────────────

  /// Create user document after phone auth
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
    await logSystemEvent('User Registered', 'New user ${user.username} registered via phone auth.');
    
    // Welcome Notification
    await createNotification(
      user.uid,
      title: 'Welcome to Carely!',
      body: 'We are so glad to have you. Please explore and join a circle!',
      type: 'WELCOME',
    );
  }

  /// Check if user document exists by UID
  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }

  /// Check if user document exists by phone number
  Future<bool> phoneExists(String phone) async {
    final query = await _users.where('phone', isEqualTo: phone).limit(1).get();
    return query.docs.isNotEmpty;
  }

  /// Get user by uid (one-time fetch)
  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  /// Stream user document (live updates)
  Stream<UserModel?> streamUser(String uid) =>
    _users.doc(uid).snapshots().map((doc) =>
      doc.exists ? UserModel.fromDoc(doc) : null);

  /// Update user fields
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
    await logSystemEvent('Profile Updated', 'User $uid updated profile fields: ${fields.keys.join(", ")}');
  }

  /// Update FCM token when it refreshes
  Future<void> updateFcmToken(String uid, String token) async {
    await _users.doc(uid).update({'fcmToken': token});
  }

  /// Update account status (Admin only)
  Future<void> updateUserStatus(String uid, String status) async {
    await _users.doc(uid).update({'accountStatus': status});
    await logSystemEvent('User Status Changed', 'User $uid status set to $status');
  }

  /// Delete user profile (Admin only)
  Future<void> deleteUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    final name = doc.exists ? (doc.data() as Map<String, dynamic>)['username'] ?? (doc.data() as Map<String, dynamic>)['displayName'] ?? uid : uid;
    await _users.doc(uid).delete();
    await logSystemEvent('User Deleted', 'Admin deleted user profile for $name');
  }

  // ─── CIRCLE ──────────────────────────────────────────────

  /// Generate a unique 8-char invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'CC-$code';
  }

  /// Create a new circle (owner becomes first member as member)
  Future<CircleModel> createCircle(String ownerUid, String name) async {
    final code = _generateInviteCode();
    final member = CircleMember(
      uid: ownerUid,
      role: 'member',
      joinedAt: DateTime.now(),
    );
    final ref = _circles.doc();
    final circle = CircleModel(
      circleId: ref.id,
      name: name,
      ownerId: ownerUid,
      members: [member],
      pendingRequests: const [],
      pendingRequestUids: const [],
      inviteCode: code,
      createdAt: DateTime.now(),
    );
    await ref.set(circle.toMap());
    await logSystemEvent('Circle Created', 'User $ownerUid created a new circle: "$name".');
    return circle;
  }

  /// Join a circle via invite code
  Future<CircleModel?> joinCircleByCode(String uid, String code) async {
    final query = await _circles
      .where('inviteCode', isEqualTo: code.toUpperCase())
      .limit(1)
      .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final circle = CircleModel.fromDoc(doc);

    // Check if already a member
    if (circle.memberUids.contains(uid)) return circle;

    const requestedRole = 'member';

    // If already has a pending request
    if (circle.pendingRequestUids.contains(uid)) return circle;

    final newRequest = CircleRequest(
      uid: uid,
      role: requestedRole,
      requestedAt: DateTime.now(),
    );

    await doc.reference.update({
      'pendingRequests': FieldValue.arrayUnion([newRequest.toMap()]),
      'pendingRequestUids': FieldValue.arrayUnion([uid]),
    });

    return CircleModel.fromDoc(await doc.reference.get());
  }

  /// Get all pending circles where user is requesting to join
  Stream<List<CircleModel>> streamMyPendingCircles(String uid) =>
    _circles
      .where('pendingRequestUids', arrayContains: uid)
      .snapshots()
      .map((q) => q.docs.map(CircleModel.fromDoc).toList());

  /// Accept a join request
  Future<void> acceptJoinRequest(String circleId, String uid, String role) async {
    final docRef = _circles.doc(circleId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final circle = CircleModel.fromDoc(doc);
    final updatedRequests = circle.pendingRequests.where((r) => r.uid != uid).map((r) => r.toMap()).toList();
    final updatedRequestUids = circle.pendingRequestUids.where((id) => id != uid).toList();

    final newMember = CircleMember(
      uid: uid,
      role: role,
      joinedAt: DateTime.now(),
    );

    await docRef.update({
      'pendingRequests': updatedRequests,
      'pendingRequestUids': updatedRequestUids,
      'members': FieldValue.arrayUnion([newMember.toMap()]),
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    
    // Circle Join Notification
    await createNotification(
      uid,
      title: 'Circle Joined',
      body: 'You have successfully joined ${circle.name}.',
      type: 'CIRCLE',
      referenceId: circleId,
    );
  }

  /// Decline a join request
  Future<void> declineJoinRequest(String circleId, String uid) async {
    final docRef = _circles.doc(circleId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final circle = CircleModel.fromDoc(doc);
    final updatedRequests = circle.pendingRequests.where((r) => r.uid != uid).map((r) => r.toMap()).toList();
    final updatedRequestUids = circle.pendingRequestUids.where((id) => id != uid).toList();

    await docRef.update({
      'pendingRequests': updatedRequests,
      'pendingRequestUids': updatedRequestUids,
    });
  }

  /// Leave a circle
  Future<void> leaveCircle(String circleId, String uid) async {
    final docRef = _circles.doc(circleId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final circle = CircleModel.fromDoc(doc);
    final updatedMembers = circle.members.where((m) => m.uid != uid).map((m) => m.toMap()).toList();
    final updatedMemberUids = circle.memberUids.where((id) => id != uid).toList();

    await docRef.update({
      'members': updatedMembers,
      'memberUids': updatedMemberUids,
    });
  }

  /// Rename a circle
  Future<void> renameCircle(String circleId, String newName) async {
    await _circles.doc(circleId).update({'name': newName});
  }


  /// Get all circles where user is a member
  Stream<List<CircleModel>> streamMyCircles(String uid) =>
    _circles
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((q) {
        final list = <CircleModel>[];
        for (final doc in q.docs) {
          try {
            list.add(CircleModel.fromDoc(doc));
          } catch (e) {
            // Rethrow so the developer/user sees the type-casting or parsing issue
            throw FormatException('Error parsing circle ${doc.id}: $e');
          }
        }
        return list;
      });

  /// Get circle by ID (stream)
  Stream<CircleModel?> streamCircle(String circleId) =>
    _circles.doc(circleId).snapshots().map((doc) =>
      doc.exists ? CircleModel.fromDoc(doc) : null);

  /// Stream users (profiles) who are members of a specific circle
  Stream<List<UserModel>> streamCircleMemberProfiles(List<String> uids) {
    if (uids.isEmpty) return Stream.value([]);
    return _users
      .where(FieldPath.documentId, whereIn: uids)
      .snapshots()
      .map((q) => q.docs.map(UserModel.fromDoc).toList());
  }

  /// Get all users in the system (Admin only)
  Stream<List<UserModel>> streamAllUsers() =>
    _users
      .snapshots()
      .map((q) => q.docs.map(UserModel.fromDoc).toList());

  /// Get all circles in the system (Admin only)
  Stream<List<CircleModel>> streamAllCircles() =>
    _circles
      .snapshots()
      .map((q) => q.docs.map(CircleModel.fromDoc).toList());

  // ─── CHECK-IN ────────────────────────────────────────────

  /// Submit today's check-in
  Future<CheckinModel> submitCheckin({
    required String uid,
    required String circleId,
    String? mood,
    String? note,
  }) async {
    final todayCheckin = await getTodayCheckin(uid, circleId);
    if (todayCheckin != null) {
      final updates = <String, dynamic>{
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };
      if (mood != null) updates['mood'] = mood;
      
      if (mood == 'okay') {
        updates['note'] = FieldValue.delete();
      } else if (note != null) {
        updates['note'] = note;
      }
      
      await _checkins.doc(todayCheckin.checkinId).update(updates);
      
      if (mood == 'SOS') {
        final udoc = await _users.doc(uid).get();
        final name = udoc.exists ? ((udoc.data() as Map)['username'] ?? (udoc.data() as Map)['Username'] ?? (udoc.data() as Map)['displayName'] ?? (udoc.data() as Map)['DisplayName'] ?? 'User') : 'User';
        await logSystemEvent('Alert Triggered', 'SOS triggered by $name.');
      }
      
      return CheckinModel(
        checkinId: todayCheckin.checkinId,
        uid: uid,
        circleId: circleId,
        mood: mood ?? todayCheckin.mood,
        timestamp: DateTime.now(),
        streakDay: todayCheckin.streakDay,
        note: mood == 'okay' ? null : (note ?? todayCheckin.note),
      );
    }

    final streak = await _calculateStreak(uid, circleId);
    final ref = _checkins.doc();
    final checkin = CheckinModel(
      checkinId: ref.id,
      uid: uid,
      circleId: circleId,
      mood: mood,
      timestamp: DateTime.now(),
      streakDay: streak + 1,
      note: note,
    );
    await ref.set(checkin.toMap());
    await logSystemEvent('Check-in Completed', 'User $uid checked in to circle $circleId (Status: ${mood ?? 'Safe'}).');
    
    // Streak Notification (Milestones)
    final newStreak = streak + 1;
    if (newStreak == 3 || newStreak == 7 || newStreak == 14 || newStreak == 30 || newStreak % 30 == 0) {
      await createNotification(
        uid,
        title: 'Streak Milestone!',
        body: 'Amazing! You have checked in for $newStreak days in a row.',
        type: 'STREAK',
      );
    }
    
    return checkin;
  }

  /// Check if user has checked in today
  Future<bool> hasCheckedInToday(String uid, String circleId) async {
    final todayCheckin = await getTodayCheckin(uid, circleId);
    return todayCheckin != null;
  }

  /// Get today's check-in for a user
  Future<CheckinModel?> getTodayCheckin(String uid, String circleId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final query = await _checkins
      .where('uid', isEqualTo: uid)
      .get();

    final matches = query.docs
      .map(CheckinModel.fromDoc)
      .where((c) => c.circleId == circleId && c.timestamp.isAfter(startOfDay))
      .toList();

    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.first;
  }

  /// Stream last 14 check-ins for a user
  Stream<List<CheckinModel>> streamRecentCheckins(String uid, String circleId) =>
    _checkins
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final list = q.docs.map(CheckinModel.fromDoc).toList();
        final filtered = list.where((c) => c.circleId == circleId).toList();
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return filtered.take(14).toList();
      });

  /// Stream check-ins for the current month
  Stream<List<CheckinModel>> streamMonthlyCheckins(String uid, String circleId) =>
    _checkins
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final list = q.docs.map(CheckinModel.fromDoc).toList();
        final filtered = list.where((c) => c.circleId == circleId).toList();
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final now = DateTime.now();
        return filtered.where((c) => c.timestamp.year == now.year && c.timestamp.month == now.month).toList();
      });

  /// Stream check-ins for the current month for an entire circle
  Stream<List<CheckinModel>> streamAllMonthlyCheckins(String circleId) =>
    _checkins
      .where('circleId', isEqualTo: circleId)
      .snapshots()
      .map((q) {
        final list = q.docs.map(CheckinModel.fromDoc).toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final now = DateTime.now();
        return list.where((c) => c.timestamp.year == now.year && c.timestamp.month == now.month).toList();
      });

  /// Calculate current streak from previous check-ins
  Future<int> _calculateStreak(String uid, String circleId) async {
    final query = await _checkins
      .where('uid', isEqualTo: uid)
      .get();

    final list = query.docs.map(CheckinModel.fromDoc).toList();
    final filtered = list.where((c) => c.circleId == circleId).toList();
    if (filtered.isEmpty) return 0;

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final last = filtered.first;
    final lastDate = DateTime(
      last.timestamp.year, last.timestamp.month, last.timestamp.day);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day);

    // If last check-in was yesterday, continue streak
    if (lastDate == yesterdayDate) return last.streakDay;
    // If last check-in was today (duplicate tap), return same
    if (last.isToday) return last.streakDay;
    // Streak broken
    return 0;
  }

  // ─── MEDICINE ────────────────────────────────────────────

  /// Add a medicine schedule
  Future<MedicineModel> addMedicine({
    required String uid,
    required String createdBy,
    required String name,
    required String dosage,
    required List<String> times,
    List<int>? daysOfWeek,
    String? ringtone,
    bool? vibrate,
    bool? deleteAfterTaken,
  }) async {
    final ref = _medicines.doc();
    final med = MedicineModel(
      medId: ref.id,
      uid: uid,
      createdBy: createdBy,
      name: name,
      dosage: dosage,
      times: times,
      daysOfWeek: daysOfWeek ?? [1,2,3,4,5,6,7],
      createdAt: DateTime.now(),
      ringtone: ringtone ?? 'Medication',
      vibrate: vibrate ?? true,
      deleteAfterTaken: deleteAfterTaken ?? false,
    );
    await ref.set(med.toMap());
    await logSystemEvent('Medication Added', 'Medication "$name" added by $createdBy.');
    return med;
  }

  /// Update an existing medicine schedule
  Future<void> updateMedicine({
    required String medId,
    required String name,
    required String dosage,
    required List<String> times,
    required List<int> daysOfWeek,
    required String ringtone,
    required bool vibrate,
    required bool deleteAfterTaken,
  }) async {
    await _medicines.doc(medId).update({
      'name': name,
      'dosage': dosage,
      'times': times,
      'daysOfWeek': daysOfWeek,
      'ringtone': ringtone,
      'vibrate': vibrate,
      'deleteAfterTaken': deleteAfterTaken,
    });
  }

  /// Stream medicines for a user
  Stream<List<MedicineModel>> streamMedicines(String uid) =>
    _medicines
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final list = q.docs.map(MedicineModel.fromDoc).toList();
        final filtered = list.where((m) => m.active).toList();
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return filtered;
      });

  /// Delete (deactivate) a medicine
  Future<void> deactivateMedicine(String medId) async {
    await _medicines.doc(medId).update({'active': false});
  }

  /// Log medicine as taken
  Future<MedLogModel> logMedicineTaken({
    required String medId,
    required String uid,
    required String scheduledTime,
    String? proofUrl,
  }) async {
    final ref = _medLogs.doc();
    final log = MedLogModel(
      logId: ref.id,
      medId: medId,
      uid: uid,
      takenAt: DateTime.now(),
      scheduledTime: scheduledTime,
      status: 'taken',
      proofUrl: proofUrl,
    );
    await ref.set(log.toMap());
    await logSystemEvent('Medication Logged', 'Medication $medId logged as taken by $uid.');
    return log;
  }

  /// Unlog medicine as taken (delete today's log entry)
  Future<void> unlogMedicineTaken({
    required String medId,
    required String uid,
    required String scheduledTime,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final query = await _medLogs
        .where('uid', isEqualTo: uid)
        .where('medId', isEqualTo: medId)
        .where('scheduledTime', isEqualTo: scheduledTime)
        .get();

    for (final doc in query.docs) {
      final log = MedLogModel.fromDoc(doc);
      if (log.takenAt.isAfter(startOfDay)) {
        await doc.reference.delete();
      }
    }
  }

  /// Get today's med logs for a user
  Stream<List<MedLogModel>> streamTodayMedLogs(String uid) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _medLogs
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final list = q.docs.map(MedLogModel.fromDoc).toList();
        final filtered = list.where((log) => log.takenAt.isAfter(startOfDay)).toList();
        return filtered;
      });
  }

  // ─── LOCATION ────────────────────────────────────────────

  /// Update (upsert) user location
  Future<void> updateLocation({
    required String uid,
    required double lat,
    required double lng,
    required String label,
    bool sharing = true,
  }) async {
    await _locations.doc(uid).set({
      'lat': lat,
      'lng': lng,
      'label': label,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'sharing': sharing,
    }, SetOptions(merge: true));
    await _users.doc(uid).update({'locationSharing': sharing});
  }

  /// Stream a user's location
  Stream<LocationModel?> streamLocation(String uid) =>
    _locations.doc(uid).snapshots().map((doc) =>
      doc.exists ? LocationModel.fromDoc(doc) : null);

  Future<void> setLocationSharing(String uid, bool sharing) async {
    await _locations.doc(uid).update({'sharing': sharing});
    await _users.doc(uid).update({'locationSharing': sharing});
    await logSystemEvent('Location Settings', 'User $uid set location sharing to $sharing.');
  }

  // ─── SYSTEM LOGS (Admin) ─────────────────────────────────

  Future<void> logSystemEvent(String action, String details) async {
    final log = AuditLogModel(
      logId: '',
      action: action,
      details: details,
      timestamp: DateTime.now(),
    );
    await _logs.add(log.toMap());
  }

  Stream<List<AuditLogModel>> streamSystemLogs() {
    return _logs
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((q) => q.docs.map(AuditLogModel.fromDoc).toList());
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────

  /// Stream notifications for a user
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _users.doc(uid).collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Create a persistent notification
  Future<void> createNotification(String uid, {
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) async {
    final ref = _users.doc(uid).collection('notifications').doc();
    final notif = NotificationModel(
      id: ref.id,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      isRead: false,
      referenceId: referenceId,
    );
    await ref.set(notif.toMap());
  }

  /// Mark a single notification as read
  Future<void> markNotificationAsRead(String uid, String notificationId) async {
    await _users.doc(uid).collection('notifications').doc(notificationId).update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String uid) async {
    final batch = _db.batch();
    final unread = await _users.doc(uid).collection('notifications').where('isRead', isEqualTo: false).get();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete a single notification
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _users.doc(uid).collection('notifications').doc(notificationId).delete();
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications(String uid) async {
    final batch = _db.batch();
    final allNotifs = await _users.doc(uid).collection('notifications').get();
    for (var doc in allNotifs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
