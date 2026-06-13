enum AuditSeverity {
  low,
  medium,
  high,
  critical,
}

enum AuditStatus {
  passed,
  failed,
  flagged,
}

class AuditModel {
  final String id;
  final String eventName;
  final String actorName;
  final String actorRole;
  final DateTime timestamp;
  final AuditSeverity severity;
  final AuditStatus status;
  final String regulation; 
  final String description;
  final String ipAddress;

  const AuditModel({
    required this.id,
    required this.eventName,
    required this.actorName,
    required this.actorRole,
    required this.timestamp,
    required this.severity,
    required this.status,
    required this.regulation,
    required this.description,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventName': eventName,
      'actorName': actorName,
      'actorRole': actorRole,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'status': status.name,
      'regulation': regulation,
      'description': description,
      'ipAddress': ipAddress,
    };
  }
}