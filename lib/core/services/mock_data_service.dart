import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/features/patients/data/models/vitals_model.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';

class MockDataService {
  MockDataService._();

  static final PatientApiService _apiService = PatientApiService();

  static List<PatientModel> _patientsCache = [];
  static List<VisitModel> _visitsCache = [];
  static List<AuditModel> _auditsCache = [];
  static bool _hasLoaded = false;

  static Future<List<PatientModel>> getPatients({bool forceRefresh = false}) async {
    if (!_hasLoaded || forceRefresh) {
      await syncFromBackend();
    }
    return _patientsCache;
  }

  static Future<List<VisitModel>> getVisits({bool forceRefresh = false}) async {
    if (!_hasLoaded || forceRefresh) {
      await syncFromBackend();
    }
    return _visitsCache;
  }

  static Future<List<AuditModel>> getAudits({bool forceRefresh = false}) async {
    if (!_hasLoaded || forceRefresh) {
      await syncFromBackend();
    }
    return _auditsCache;
  }

  static List<PatientModel> getPatientsSync() {
    return _patientsCache;
  }

  static List<VisitModel> getVisitsSync() {
    return _visitsCache;
  }

  static List<AuditModel> getAuditsSync() {
    return _auditsCache;
  }

  static double get overallComplianceScore {
    if (_patientsCache.isEmpty) return 100.0;
    final sum = _patientsCache.map((p) => p.complianceScore).reduce((a, b) => a + b);
    return double.parse((sum / _patientsCache.length).toStringAsFixed(1));
  }

  static Future<void> syncFromBackend() async {
    try {
      print('Initiating Live S3 Compliance Synchronization from AWS Backend...');

      final rawPatients = await _apiService.fetchPatients();
      final List<PatientModel> patientsList = [];
      for (final item in rawPatients) {
        try {
          final id = item['patientId'] ?? item['id'] ?? '';
          if (id.isEmpty) continue;

          ConsentStatus consent = ConsentStatus.signed;
          if (item['consentStatus'] != null) {
            final consentStr = item['consentStatus'].toString().toLowerCase();
            if (consentStr.contains('pending')) {
              consent = ConsentStatus.pending;
            } else if (consentStr.contains('revoked')) {
              consent = ConsentStatus.revoked;
            } else if (consentStr.contains('expired')) {
              consent = ConsentStatus.expired;
            }
          }

          int age = 35;
          if (item['age'] != null) {
            age = int.tryParse(item['age'].toString()) ?? 35;
          } else if (item['dob'] != null && item['dob'].toString().isNotEmpty) {
            try {
              final birthYear = int.parse(item['dob'].split('-')[0]);
              age = DateTime.now().year - birthYear;
            } catch (_) {}
          }

          patientsList.add(PatientModel(
            id: id,
            mrn: item['mrn'] ?? 'MRN-${id.replaceAll('PT-', '')}-${id.hashCode % 90 + 10}',
            name: item['name'] ?? 'Anonymous Patient',
            dateOfBirth: item['dob'] ?? item['dateOfBirth'] ?? '1990-01-01',
            consentStatus: consent,
            isDataEncrypted: item['isDataEncrypted'] ?? true,
            primaryCarePhysician: item['primaryCarePhysician'] ?? 'Dr. Marcus Brody',
            lastAuditDate: (DateTime.tryParse(item['lastAuditDate'] ?? '') ?? DateTime.now()).toLocal(),
            complianceScore: (item['complianceScore'] as num?)?.toDouble() ?? 100.0,
            age: age,
            gender: item['gender'] ?? 'Female',
            bloodGroup: item['bloodGroup'] ?? 'A+',
            phone: item['phone'] ?? item['phoneNumber'] ?? '',
            address: item['address'] ?? '',
            insuranceProvider: item['insuranceProvider'] ?? '',
            emergencyContact: item['emergencyContact'] ?? '',
          ));
        } catch (itemErr) {
          print('Failed parsing patient record JSON: $itemErr');
        }
      }
      _patientsCache = patientsList;

      final rawVisits = await _apiService.fetchVisits();
      final List<VisitModel> visitsList = [];
      for (final item in rawVisits) {
        try {
          final id = item['id'] ?? '';
          if (id.isEmpty) continue;

          EhrSyncStatus syncVal = EhrSyncStatus.synced;
          if (item['syncStatus'] != null) {
            final syncStr = item['syncStatus'].toString().toLowerCase();
            if (syncStr.contains('pending')) {
              syncVal = EhrSyncStatus.pending;
            } else if (syncStr.contains('failed')) {
              syncVal = EhrSyncStatus.failed;
            }
          }

          visitsList.add(VisitModel(
            id: id,
            patientId: item['patientId'] ?? '',
            patientName: item['patientName'] ?? 'Unknown Patient',
            mrn: item['mrn'] ?? '',
            providerName: item['providerName'] ?? 'Dr. Marcus Brody',
            visitDate: (DateTime.tryParse(item['visitDate'] ?? '') ?? DateTime.now()).toLocal(),
            syncStatus: syncVal,
            hasPhysicianSignature: item['hasPhysicianSignature'] ?? true,
            billingCoded: item['billingCoded'] ?? true,
            complianceCleared: item['complianceCleared'] ?? true,
            notes: item['notes'] ?? '',
            doctorId: item['doctorId'] ?? '',
            chiefComplaint: item['chiefComplaint'] ?? '',
            diagnosis: item['diagnosis'] ?? '',
            followUpDate: DateTime.tryParse(item['followUpDate'] ?? '')?.toLocal(),
          ));
        } catch (itemErr) {
          print('Failed parsing visit JSON: $itemErr');
        }
      }
      visitsList.sort((a, b) => b.visitDate.compareTo(a.visitDate));
      _visitsCache = visitsList;

      final rawVitals = await _apiService.fetchVitals();
      final List<VitalsModel> vitalsList = [];
      for (final item in rawVitals) {
        try {
          final vitalsId = item['vitalsId'] ?? '';
          if (vitalsId.isEmpty) continue;

          vitalsList.add(VitalsModel(
            vitalsId: vitalsId,
            patientId: item['patientId'] ?? '',
            bloodPressure: item['bloodPressure'] ?? '120/80',
            heartRate: int.tryParse(item['heartRate']?.toString() ?? '') ?? 72,
            temperature: double.tryParse(item['temperature']?.toString() ?? '') ?? 98.6,
            spo2: int.tryParse(item['spo2']?.toString() ?? '') ?? 98,
            weight: double.tryParse(item['weight']?.toString() ?? '') ?? 70.0,
            height: double.tryParse(item['height']?.toString() ?? '') ?? 170.0,
            bmi: double.tryParse(item['bmi']?.toString() ?? '') ?? 24.2,
            bloodSugar: int.tryParse(item['bloodSugar']?.toString() ?? '') ?? 90,
            recordedAt: (DateTime.tryParse(item['recordedAt'] ?? '') ?? DateTime.now()).toLocal(),
          ));
        } catch (itemErr) {
          print('Failed parsing vitals JSON: $itemErr');
        }
      }
      vitalsList.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      DemoDataGenerator.instance.patients.clear();
      DemoDataGenerator.instance.patients.addAll(_patientsCache);

      DemoDataGenerator.instance.visits.clear();
      DemoDataGenerator.instance.visits.addAll(_visitsCache);

      DemoDataGenerator.instance.vitals.clear();
      DemoDataGenerator.instance.vitals.addAll(vitalsList);

      final rawAudits = await _apiService.fetchAudits();
      final List<AuditModel> auditsList = [];
      for (final item in rawAudits) {
        try {
          final id = item['id'] ?? '';
          if (id.isEmpty) continue;

          AuditSeverity severityVal = AuditSeverity.low;
          if (item['severity'] != null) {
            final sevStr = item['severity'].toString().toLowerCase();
            if (sevStr.contains('medium')) {
              severityVal = AuditSeverity.medium;
            } else if (sevStr.contains('high')) {
              severityVal = AuditSeverity.high;
            } else if (sevStr.contains('critical')) {
              severityVal = AuditSeverity.critical;
            }
          }

          AuditStatus statusVal = AuditStatus.passed;
          if (item['status'] != null) {
            final statStr = item['status'].toString().toLowerCase();
            if (statStr.contains('failed')) {
              statusVal = AuditStatus.failed;
            } else if (statStr.contains('flagged')) {
              statusVal = AuditStatus.flagged;
            }
          }

          auditsList.add(AuditModel(
            id: id,
            eventName: item['eventName'] ?? 'Trace Log',
            actorName: item['actorName'] ?? 'System',
            actorRole: item['actorRole'] ?? 'Monitor',
            timestamp: (DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now()).toLocal(),
            severity: severityVal,
            status: statusVal,
            regulation: item['regulation'] ?? 'HIPAA',
            description: item['description'] ?? '',
            ipAddress: item['ipAddress'] ?? '127.0.0.1',
          ));
        } catch (itemErr) {
          print('Failed parsing audit trace: $itemErr');
        }
      }
      auditsList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _auditsCache = auditsList;

      DemoDataGenerator.instance.audits.clear();
      DemoDataGenerator.instance.audits.addAll(_auditsCache);

      _hasLoaded = true;
      print('AWS S3 Compliance Cache successfully synchronized. Loaded: '
          '${_patientsCache.length} Patients, ${_visitsCache.length} Visits, '
          '${vitalsList.length} Vitals, ${_auditsCache.length} Audits.');
    } catch (e) {
      print('Warning: S3 Cache synchronization failed (Backend offline or initializing): $e');
      throw e;
    }
  }
}