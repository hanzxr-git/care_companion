// models/audit_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String logId;
  final String action;
  final String details;
  final DateTime timestamp;

  const AuditLogModel({
    required this.logId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AuditLogModel(
      logId: doc.id,
      action: d['action'] ?? 'Unknown Action',
      details: d['details'] ?? '',
      timestamp: (d['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
