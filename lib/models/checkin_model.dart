// models/checkin_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinModel {
  final String checkinId;
  final String uid;
  final String circleId;
  final String? mood; // 'great','good','okay','low','sad'
  final DateTime timestamp;
  final int streakDay;
  final String? note;

  const CheckinModel({
    required this.checkinId,
    required this.uid,
    required this.circleId,
    this.mood,
    required this.timestamp,
    required this.streakDay,
    this.note,
  });

  factory CheckinModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CheckinModel(
      checkinId: doc.id,
      uid: d['uid'] ?? '',
      circleId: d['circleId'] ?? '',
      mood: d['mood'],
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      streakDay: d['streakDay'] ?? 1,
      note: d['note'],
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'circleId': circleId,
    if (mood != null) 'mood': mood,
    'timestamp': Timestamp.fromDate(timestamp),
    'streakDay': streakDay,
    if (note != null) 'note': note,
  };

  // Check if this checkin is from today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
      timestamp.month == now.month &&
      timestamp.day == now.day;
  }
}
