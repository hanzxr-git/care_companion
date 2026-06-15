// models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phone;
  final String displayName;
  final String? email;
  final String avatarInitials;
  final int avatarColorValue;
  final String? avatarUrl;
  final bool elderMode;
  final bool locationSharing;
  final bool sosActive;
  final String? fcmToken;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.phone,
    required this.displayName,
    this.email,
    required this.avatarInitials,
    required this.avatarColorValue,
    this.avatarUrl,
    this.elderMode = false,
    this.locationSharing = true,
    this.sosActive = false,
    this.fcmToken,
    required this.createdAt,
  });

  // Generate initials from display name
  static String initialsFrom(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  // Avatar color based on phone number (consistent per user)
  static int colorFrom(String phone) {
    const colors = [
      0xFF7C6FCD, // purple
      0xFF26A69A, // teal
      0xFF5C6BC0, // indigo
      0xFFEC407A, // pink
      0xFF26C6DA, // cyan
      0xFFFF7043, // deep orange
      0xFF66BB6A, // green
      0xFFAB47BC, // violet
    ];
    final hash = phone.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  // From Firestore document
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phone: d['phone'] ?? '',
      displayName: d['displayName'] ?? '',
      email: d['email'],
      avatarInitials: d['avatarInitials'] ?? '??',
      avatarColorValue: d['avatarColorValue'] ?? 0xFF7C6FCD,
      avatarUrl: d['avatarUrl'],
      elderMode: d['elderMode'] ?? false,
      locationSharing: d['locationSharing'] ?? true,
      sosActive: d['sosActive'] ?? false,
      fcmToken: d['fcmToken'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // To Firestore map
  Map<String, dynamic> toMap() => {
    'phone': phone,
    'displayName': displayName,
    if (email != null) 'email': email,
    'avatarInitials': avatarInitials,
    'avatarColorValue': avatarColorValue,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'elderMode': elderMode,
    'locationSharing': locationSharing,
    'sosActive': sosActive,
    if (fcmToken != null) 'fcmToken': fcmToken,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  UserModel copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? elderMode,
    bool? locationSharing,
    bool? sosActive,
    String? fcmToken,
  }) => UserModel(
    uid: uid,
    phone: phone,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    avatarInitials: displayName != null
      ? initialsFrom(displayName) : avatarInitials,
    avatarColorValue: avatarColorValue,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    elderMode: elderMode ?? this.elderMode,
    locationSharing: locationSharing ?? this.locationSharing,
    sosActive: sosActive ?? this.sosActive,
    fcmToken: fcmToken ?? this.fcmToken,
    createdAt: createdAt,
  );
}
