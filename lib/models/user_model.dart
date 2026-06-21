// models/user_model.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phone;
  final String username;
  final String? email;
  final String avatarInitials;
  final int avatarColorValue;
  final String? avatarUrl;
  final bool elderMode;
  final bool locationSharing;
  final bool sosActive;
  final String? fcmToken;
  final String accountStatus;
  final DateTime createdAt;
  final DateTime? birthDate;
  final String? gender;

  const UserModel({
    required this.uid,
    required this.phone,
    required this.username,
    this.email,
    required this.avatarInitials,
    required this.avatarColorValue,
    this.avatarUrl,
    this.elderMode = false,
    this.locationSharing = true,
    this.sosActive = false,
    this.fcmToken,
    this.accountStatus = 'ACTIVE',
    required this.createdAt,
    this.birthDate,
    this.gender,
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
      username: d['username'] ?? d['Username'] ?? d['displayName'] ?? d['DisplayName'] ?? 'User',
      email: d['email'],
      avatarInitials: d['avatarInitials'] ?? '??',
      avatarColorValue: d['avatarColorValue'] ?? 0xFF7C6FCD,
      avatarUrl: d['avatarUrl'],
      elderMode: d['elderMode'] ?? false,
      locationSharing: d['locationSharing'] ?? true,
      sosActive: d['sosActive'] ?? false,
      fcmToken: d['fcmToken'],
      accountStatus: d['accountStatus'] ?? 'ACTIVE',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      birthDate: (d['birthDate'] as Timestamp?)?.toDate(),
      gender: d['gender'],
    );
  }

  // To Firestore map
  Map<String, dynamic> toMap() => {
    'phone': phone,
    'username': username,
    if (email != null) 'email': email,
    'avatarInitials': avatarInitials,
    'avatarColorValue': avatarColorValue,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'elderMode': elderMode,
    'locationSharing': locationSharing,
    'sosActive': sosActive,
    if (fcmToken != null) 'fcmToken': fcmToken,
    'accountStatus': accountStatus,
    'createdAt': Timestamp.fromDate(createdAt),
    if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
    if (gender != null) 'gender': gender,
  };

  UserModel copyWith({
    String? username,
    String? email,
    String? avatarUrl,
    bool? elderMode,
    bool? locationSharing,
    bool? sosActive,
    String? fcmToken,
    String? accountStatus,
    DateTime? birthDate,
    String? gender,
  }) => UserModel(
    uid: uid,
    phone: phone,
    username: username ?? this.username,
    email: email ?? this.email,
    avatarInitials: username != null
      ? initialsFrom(username) : avatarInitials,
    avatarColorValue: avatarColorValue,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    elderMode: elderMode ?? this.elderMode,
    locationSharing: locationSharing ?? this.locationSharing,
    sosActive: sosActive ?? this.sosActive,
    fcmToken: fcmToken ?? this.fcmToken,
    accountStatus: accountStatus ?? this.accountStatus,
    createdAt: createdAt,
    birthDate: birthDate ?? this.birthDate,
    gender: gender ?? this.gender,
  );

  /// Helper to build the user's avatar widget uniformly across the app.
  /// Handles Firebase Storage URLs, Base64 strings, and fallback initials.
  Widget buildAvatar({double radius = 24}) {
    ImageProvider? imageProvider;
    
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (avatarUrl!.startsWith('http')) {
        imageProvider = NetworkImage(avatarUrl!);
      } else {
        try {
          final bytes = base64Decode(avatarUrl!);
          imageProvider = MemoryImage(bytes);
        } catch (e) {
          // invalid base64, fallback
        }
      }
    }

    if (imageProvider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Color(avatarColorValue),
        backgroundImage: imageProvider,
      );
    }

    // Fallback initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(avatarColorValue),
      child: Text(
        avatarInitials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
