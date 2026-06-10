// models/mock_data.dart
import 'package:flutter/material.dart';

class MockFamilyMember {
  final String id;
  final String name;
  final String avatarInitials;
  final Color avatarColor;
  final double lat;
  final double lng;
  final String locationLabel;
  final int streakDays;
  final bool checkedInToday;
  final DateTime lastSeen;
  final List<MockMedicine> medicines;
  final List<MockEvent> events;

  const MockFamilyMember({
    required this.id,
    required this.name,
    required this.avatarInitials,
    required this.avatarColor,
    required this.lat,
    required this.lng,
    required this.locationLabel,
    required this.streakDays,
    required this.checkedInToday,
    required this.lastSeen,
    required this.medicines,
    required this.events,
  });
}

class MockMedicine {
  final String name;
  final String dosage;
  final TimeOfDay time;
  final bool takenToday;

  const MockMedicine({
    required this.name,
    required this.dosage,
    required this.time,
    required this.takenToday,
  });
}

class MockEvent {
  final String title;
  final DateTime dateTime;
  final String location;

  const MockEvent({
    required this.title,
    required this.dateTime,
    required this.location,
  });
}

class MockData {
  static final List<MockFamilyMember> familyMembers = [
    MockFamilyMember(
      id: 'fm1',
      name: 'Ahmad bin Ali',
      avatarInitials: 'AA',
      avatarColor: const Color(0xFF5C6BC0),
      lat: 3.0738,
      lng: 101.5183,
      locationLabel: 'Home — Puchong',
      streakDays: 12,
      checkedInToday: true,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      medicines: [
        MockMedicine(name: 'Metformin', dosage: '500mg', time: const TimeOfDay(hour: 8, minute: 0), takenToday: true),
        MockMedicine(name: 'Amlodipine', dosage: '5mg', time: const TimeOfDay(hour: 20, minute: 0), takenToday: false),
      ],
      events: [
        MockEvent(title: 'Clinic appointment', dateTime: DateTime.now().add(const Duration(days: 2)), location: 'Klinik Kesihatan Puchong'),
        MockEvent(title: 'Family lunch', dateTime: DateTime.now().add(const Duration(days: 5)), location: 'Home'),
      ],
    ),
    MockFamilyMember(
      id: 'fm2',
      name: 'Siti binti Hassan',
      avatarInitials: 'SH',
      avatarColor: const Color(0xFF26A69A),
      lat: 3.1412,
      lng: 101.6865,
      locationLabel: 'Kuala Lumpur City',
      streakDays: 3,
      checkedInToday: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 18)),
      medicines: [
        MockMedicine(name: 'Lisinopril', dosage: '10mg', time: const TimeOfDay(hour: 7, minute: 30), takenToday: false),
      ],
      events: [],
    ),
  ];

  static final List<Map<String, dynamic>> adminUsers = [
    {'name': 'Farhan Amin', 'role': 'User', 'members': 2, 'joined': '12 Jan 2026'},
    {'name': 'Ahmad Ali', 'role': 'Family Member', 'members': 0, 'joined': '12 Jan 2026'},
    {'name': 'Siti Hassan', 'role': 'Family Member', 'members': 0, 'joined': '15 Jan 2026'},
    {'name': 'Zainab Yusof', 'role': 'User', 'members': 1, 'joined': '20 Feb 2026'},
  ];
}