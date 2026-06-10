// services/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/circle_model.dart';
import '../models/checkin_model.dart';
import '../models/medicine_model.dart';
import '../models/location_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ─── Collection references ───────────────────────────────
  CollectionReference get _users     => _db.collection('users');
  CollectionReference get _circles   => _db.collection('circles');
  CollectionReference get _checkins  => _db.collection('checkins');
  CollectionReference get _medicines => _db.collection('medicines');
  CollectionReference get _medLogs   => _db.collection('med_logs');
  CollectionReference get _locations => _db.collection('locations');

  // ─── USER ────────────────────────────────────────────────

  /// Create user document after phone auth
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  /// Check if user document exists (returning user vs new)
  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
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
  }

  /// Update FCM token when it refreshes
  Future<void> updateFcmToken(String uid, String token) async {
    await _users.doc(uid).update({'fcmToken': token});
  }

  // ─── CIRCLE ──────────────────────────────────────────────

  /// Generate a unique 8-char invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'CC-$code';
  }

  /// Create a new circle (owner becomes first member as monitor)
  Future<CircleModel> createCircle(String ownerUid, String name) async {
    final code = _generateInviteCode();
    final member = CircleMember(
      uid: ownerUid,
      role: 'monitor',
      joinedAt: DateTime.now(),
    );
    final ref = _circles.doc();
    final circle = CircleModel(
      circleId: ref.id,
      name: name,
      ownerId: ownerUid,
      members: [member],
      inviteCode: code,
      createdAt: DateTime.now(),
    );
    await ref.set(circle.toMap());
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

    final newMember = CircleMember(
      uid: uid,
      role: 'member',
      joinedAt: DateTime.now(),
    );

    await doc.reference.update({
      'members': FieldValue.arrayUnion([newMember.toMap()]),
      'memberUids': FieldValue.arrayUnion([uid]),
    });

    return CircleModel.fromDoc(await doc.reference.get());
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
        if (mood != null) 'mood': mood,
        if (note != null) 'note': note,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };
      await _checkins.doc(todayCheckin.checkinId).update(updates);
      return CheckinModel(
        checkinId: todayCheckin.checkinId,
        uid: uid,
        circleId: circleId,
        mood: mood ?? todayCheckin.mood,
        timestamp: DateTime.now(),
        streakDay: todayCheckin.streakDay,
        note: note ?? todayCheckin.note,
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
    return checkin;
  }

  /// Check if user has checked in today
  Future<bool> hasCheckedInToday(String uid, String circleId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final query = await _checkins
      .where('uid', isEqualTo: uid)
      .where('circleId', isEqualTo: circleId)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .limit(1)
      .get();
    return query.docs.isNotEmpty;
  }

  /// Get today's check-in for a user
  Future<CheckinModel?> getTodayCheckin(String uid, String circleId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final query = await _checkins
      .where('uid', isEqualTo: uid)
      .where('circleId', isEqualTo: circleId)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .limit(1)
      .get();
    if (query.docs.isEmpty) return null;
    return CheckinModel.fromDoc(query.docs.first);
  }

  /// Stream last 14 check-ins for a user
  Stream<List<CheckinModel>> streamRecentCheckins(String uid, String circleId) =>
    _checkins
      .where('uid', isEqualTo: uid)
      .where('circleId', isEqualTo: circleId)
      .orderBy('timestamp', descending: true)
      .limit(14)
      .snapshots()
      .map((q) => q.docs.map(CheckinModel.fromDoc).toList());

  /// Calculate current streak from previous check-ins
  Future<int> _calculateStreak(String uid, String circleId) async {
    final query = await _checkins
      .where('uid', isEqualTo: uid)
      .where('circleId', isEqualTo: circleId)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();

    if (query.docs.isEmpty) return 0;
    final last = CheckinModel.fromDoc(query.docs.first);
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
    );
    await ref.set(med.toMap());
    return med;
  }

  /// Stream medicines for a user
  Stream<List<MedicineModel>> streamMedicines(String uid) =>
    _medicines
      .where('uid', isEqualTo: uid)
      .where('active', isEqualTo: true)
      .orderBy('createdAt')
      .snapshots()
      .map((q) => q.docs.map(MedicineModel.fromDoc).toList());

  /// Delete (deactivate) a medicine
  Future<void> deactivateMedicine(String medId) async {
    await _medicines.doc(medId).update({'active': false});
  }

  /// Log medicine as taken
  Future<MedLogModel> logMedicineTaken({
    required String medId,
    required String uid,
    required String scheduledTime,
  }) async {
    final ref = _medLogs.doc();
    final log = MedLogModel(
      logId: ref.id,
      medId: medId,
      uid: uid,
      takenAt: DateTime.now(),
      scheduledTime: scheduledTime,
      status: 'taken',
    );
    await ref.set(log.toMap());
    return log;
  }

  /// Get today's med logs for a user
  Stream<List<MedLogModel>> streamTodayMedLogs(String uid) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _medLogs
      .where('uid', isEqualTo: uid)
      .where('takenAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .snapshots()
      .map((q) => q.docs.map(MedLogModel.fromDoc).toList());
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
  }

  /// Stream a user's location
  Stream<LocationModel?> streamLocation(String uid) =>
    _locations.doc(uid).snapshots().map((doc) =>
      doc.exists ? LocationModel.fromDoc(doc) : null);

  /// Toggle location sharing
  Future<void> setLocationSharing(String uid, bool sharing) async {
    await _locations.doc(uid).update({'sharing': sharing});
  }
}
