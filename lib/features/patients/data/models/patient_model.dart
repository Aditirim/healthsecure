enum ConsentStatus {
  signed,
  pending,
  revoked,
  expired,
}

class PatientModel {
  final String id;
  final String mrn; 
  final String name;
  final String dateOfBirth;
  final ConsentStatus consentStatus;
  final bool isDataEncrypted;
  final String primaryCarePhysician;
  final DateTime lastAuditDate;
  final double complianceScore; 
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String? phone;
  final String? address;
  final String? insuranceProvider;
  final String? emergencyContact;

  const PatientModel({
    required this.id,
    required this.mrn,
    required this.name,
    required this.dateOfBirth,
    required this.consentStatus,
    required this.isDataEncrypted,
    required this.primaryCarePhysician,
    required this.lastAuditDate,
    required this.complianceScore,
    this.age,
    this.gender,
    this.bloodGroup,
    this.phone,
    this.address,
    this.insuranceProvider,
    this.emergencyContact,
  });

  String get consentStatusLabel {
    switch (consentStatus) {
      case ConsentStatus.signed:
        return 'Signed & Verified';
      case ConsentStatus.pending:
        return 'Signature Pending';
      case ConsentStatus.revoked:
        return 'Revoked';
      case ConsentStatus.expired:
        return 'Expired';
    }
  }

  String getNameForRole(String role) {
    if (role == 'Admin') return name;
    return maskName(name);
  }

  String getPhoneForRole(String role) {
    if (role == 'Admin') return phone ?? '';
    final val = phone ?? '';
    if (val.isEmpty) return '';
    if (val.length <= 4) return '••••';
    return '${val.substring(0, val.length - 4)}••••';
  }

  String getAddressForRole(String role) {
    if (role == 'Admin') return address ?? '';
    final val = address ?? '';
    if (val.isEmpty) return '';
    return '••••••••';
  }

  String getEmergencyContactForRole(String role) {
    if (role == 'Admin') return emergencyContact ?? '';
    final val = emergencyContact ?? '';
    if (val.isEmpty) return '';
    return '••••••••';
  }

  static String maskName(String value) {
    if (value.isEmpty) return value;
    final parts = value.trim().split(' ');
    final masked = parts.map((p) {
      if (p.isEmpty) return '';
      if (p.length <= 1) return '${p[0]}*';
      return '${p[0]}${'*' * (p.length - 1)}';
    }).join(' ');
    return masked;
  }
}