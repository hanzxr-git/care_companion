// models/circle_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CircleMember {
  final String uid;
  final String role; // 'monitor' or 'member'
  final DateTime joinedAt;

  const CircleMember({
    required this.uid,
    required this.role,
    required this.joinedAt,
  });

  factory CircleMember.fromMap(Map<String, dynamic> m) => CircleMember(
    uid: m['uid'] ?? '',
    role: m['role'] ?? 'member',
    joinedAt: (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'role': role,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };
}

class CircleRequest {
  final String uid;
  final String role; // 'member' or 'monitor'
  final DateTime requestedAt;

  const CircleRequest({
    required this.uid,
    required this.role,
    required this.requestedAt,
  });

  factory CircleRequest.fromMap(Map<String, dynamic> m) => CircleRequest(
    uid: m['uid'] ?? '',
    role: m['role'] ?? 'member',
    requestedAt: (m['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'role': role,
    'requestedAt': Timestamp.fromDate(requestedAt),
  };
}

class CircleModel {
  final String circleId;
  final String name;
  final String ownerId;
  final List<CircleMember> members;
  final List<CircleRequest> pendingRequests;
  final List<String> pendingRequestUids;
  final String inviteCode;
  final DateTime createdAt;

  const CircleModel({
    required this.circleId,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.pendingRequests,
    required this.pendingRequestUids,
    required this.inviteCode,
    required this.createdAt,
  });

  factory CircleModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final membersList = (d['members'] as List<dynamic>? ?? [])
      .map((m) => CircleMember.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList();
    final requestsList = (d['pendingRequests'] as List<dynamic>? ?? [])
      .map((m) => CircleRequest.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList();
    final requestUids = List<String>.from(d['pendingRequestUids'] ?? []);
    return CircleModel(
      circleId: doc.id,
      name: d['name'] ?? '',
      ownerId: d['ownerId'] ?? '',
      members: membersList,
      pendingRequests: requestsList,
      pendingRequestUids: requestUids,
      inviteCode: d['inviteCode'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerId': ownerId,
    'members': members.map((m) => m.toMap()).toList(),
    'memberUids': memberUids,
    'pendingRequests': pendingRequests.map((r) => r.toMap()).toList(),
    'pendingRequestUids': pendingRequestUids,
    'inviteCode': inviteCode,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  // Check if a uid is a monitor in this circle
  bool isMonitor(String uid) =>
    members.any((m) => m.uid == uid && m.role == 'monitor');

  // Get all member uids
  List<String> get memberUids => members.map((m) => m.uid).toList();
}

