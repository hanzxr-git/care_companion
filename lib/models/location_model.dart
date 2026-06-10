// models/location_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final double lat;
  final double lng;
  final String label;
  final DateTime updatedAt;
  final bool sharing;

  const LocationModel({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.label,
    required this.updatedAt,
    this.sharing = true,
  });

  factory LocationModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LocationModel(
      uid: doc.id,
      lat: (d['lat'] ?? 0.0).toDouble(),
      lng: (d['lng'] ?? 0.0).toDouble(),
      label: d['label'] ?? 'Unknown',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sharing: d['sharing'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'label': label,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'sharing': sharing,
  };

  // How long ago was location updated
  String get agoText {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
