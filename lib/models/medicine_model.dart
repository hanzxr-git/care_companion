// models/medicine_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineModel {
  final String medId;
  final String uid;         // owner (the person who takes it)
  final String createdBy;   // uid of creator (could be monitor)
  final String name;
  final String dosage;
  final List<String> times; // ['08:00', '20:00']
  final List<int> daysOfWeek; // [1,2,3,4,5,6,7] — 1=Mon, 7=Sun
  final bool active;
  final DateTime createdAt;
  final String ringtone;
  final bool vibrate;
  final bool deleteAfterTaken;

  const MedicineModel({
    required this.medId,
    required this.uid,
    required this.createdBy,
    required this.name,
    required this.dosage,
    required this.times,
    required this.daysOfWeek,
    this.active = true,
    required this.createdAt,
    this.ringtone = 'Medication',
    this.vibrate = true,
    this.deleteAfterTaken = false,
  });

  factory MedicineModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MedicineModel(
      medId: doc.id,
      uid: d['uid'] ?? '',
      createdBy: d['createdBy'] ?? '',
      name: d['name'] ?? '',
      dosage: d['dosage'] ?? '',
      times: List<String>.from(d['times'] ?? []),
      daysOfWeek: List<int>.from(d['daysOfWeek'] ?? [1,2,3,4,5,6,7]),
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ringtone: d['ringtone'] ?? 'Medication',
      vibrate: d['vibrate'] ?? true,
      deleteAfterTaken: d['deleteAfterTaken'] ?? d['deleteAfterAlarm'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'createdBy': createdBy,
    'name': name,
    'dosage': dosage,
    'times': times,
    'daysOfWeek': daysOfWeek,
    'active': active,
    'createdAt': Timestamp.fromDate(createdAt),
    'ringtone': ringtone,
    'vibrate': vibrate,
    'deleteAfterTaken': deleteAfterTaken,
  };

  // Check if scheduled for today
  bool get isScheduledToday {
    final weekday = DateTime.now().weekday; // 1=Mon, 7=Sun
    return daysOfWeek.contains(weekday);
  }
}

class MedLogModel {
  final String logId;
  final String medId;
  final String uid;
  final DateTime takenAt;
  final String scheduledTime; // '08:00'
  final String status; // 'taken' or 'missed'

  const MedLogModel({
    required this.logId,
    required this.medId,
    required this.uid,
    required this.takenAt,
    required this.scheduledTime,
    required this.status,
  });

  factory MedLogModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MedLogModel(
      logId: doc.id,
      medId: d['medId'] ?? '',
      uid: d['uid'] ?? '',
      takenAt: (d['takenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledTime: d['scheduledTime'] ?? '',
      status: d['status'] ?? 'taken',
    );
  }

  Map<String, dynamic> toMap() => {
    'medId': medId,
    'uid': uid,
    'takenAt': Timestamp.fromDate(takenAt),
    'scheduledTime': scheduledTime,
    'status': status,
  };

  bool get isTaken => status == 'taken';
}
