enum EhrSyncStatus {
  synced,
  pending,
  failed,
}

class VisitModel {
  final String id;
  final String patientId;
  final String patientName;
  final String mrn;
  final String providerName;
  final DateTime visitDate;
  final EhrSyncStatus syncStatus;
  final bool hasPhysicianSignature;
  final bool billingCoded;
  final bool complianceCleared;
  final String notes;
  final String? doctorId;
  final String? chiefComplaint;
  final String? diagnosis;
  final DateTime? followUpDate;

  const VisitModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.mrn,
    required this.providerName,
    required this.visitDate,
    required this.syncStatus,
    required this.hasPhysicianSignature,
    required this.billingCoded,
    required this.complianceCleared,
    required this.notes,
    this.doctorId,
    this.chiefComplaint,
    this.diagnosis,
    this.followUpDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'mrn': mrn,
      'providerName': providerName,
      'visitDate': visitDate.toIso8601String(),
      'syncStatus': syncStatus.name,
      'hasPhysicianSignature': hasPhysicianSignature,
      'billingCoded': billingCoded,
      'complianceCleared': complianceCleared,
      'notes': notes,
      'doctorId': doctorId,
      'chiefComplaint': chiefComplaint,
      'diagnosis': diagnosis,
      'followUpDate': followUpDate?.toIso8601String(),
    };
  }

  String getPatientNameForRole(String role) {
    if (role == 'Admin') return patientName;
    if (patientName.isEmpty) return patientName;
    final parts = patientName.trim().split(' ');
    final masked = parts.map((p) {
      if (p.isEmpty) return '';
      if (p.length <= 1) return '${p[0]}*';
      return '${p[0]}${'*' * (p.length - 1)}';
    }).join(' ');
    return masked;
  }
}