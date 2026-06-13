import 'dart:math' as math;
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/features/patients/data/models/vitals_model.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/core/constants/app_constants.dart';

class DemoDataGenerator {
  DemoDataGenerator._();
  static final DemoDataGenerator instance = DemoDataGenerator._();

  final List<Map<String, String>> mockUsers = [];
  final List<PatientModel> patients = [];
  final List<VisitModel> visits = [];
  final List<VitalsModel> vitals = [];
  final List<AuditModel> audits = [];
  
  final List<Map<String, dynamic>> pipelineLogs = [];
  int pipelineSubmitted = 0;
  int pipelineValidated = 0;
  int pipelineRejected = 0;

  int cwApiRequests = 0;
  int cwLambdaInvocations = 0;
  int cwLambdaFailures = 0;
  int cwEtlRuns = 0;
  int cwEtlFailures = 0;

  int compliancePassed = 0;
  int complianceFailed = 0;
  int quarantineEvents = 0;

  bool _initialized = false;

  void initialize({bool force = false}) {
    if (_initialized && !force) return;
    
    mockUsers.clear();
    _generateMockUsers();

    if (!AppConstants.useMockData) {
      _initialized = true;
      return;
    }

    patients.clear();
    visits.clear();
    vitals.clear();
    audits.clear();
    pipelineLogs.clear();

    _generateMockPatients();
    _generateMockVisits();
    _generateMockVitals();
    _generateMockAudits();
    _generatePipelineData();
    _generateCloudWatchMetrics();

    _initialized = true;
  }

  void _generateMockUsers() {
    mockUsers.addAll([
      {
        'email': 'admin@healthsecure.com',
        'name': 'System Administrator',
        'role': 'Admin',
        'department': 'IT Infrastructure',
      },
      
      {
        'email': 'doctor1@healthsecure.com',
        'name': 'Dr. Marcus Brody',
        'role': 'Doctor',
        'department': 'Cardiology',
      },
      {
        'email': 'doctor2@healthsecure.com',
        'name': 'Dr. Sarah Chen',
        'role': 'Doctor',
        'department': 'Pediatrics',
      },
      {
        'email': 'doctor3@healthsecure.com',
        'name': 'Dr. Elena Rostova',
        'role': 'Doctor',
        'department': 'Neurology',
      },
      {
        'email': 'doctor4@healthsecure.com',
        'name': 'Dr. Alan Grant',
        'role': 'Doctor',
        'department': 'Oncology',
      },
      {
        'email': 'doctor5@healthsecure.com',
        'name': 'Dr. Ellie Sattler',
        'role': 'Doctor',
        'department': 'Endocrinology',
      },
      
      {
        'email': 'nurse1@healthsecure.com',
        'name': 'Nurse Jane Doe',
        'role': 'Nurse',
        'department': 'Cardiology Clinic',
      },
      {
        'email': 'nurse2@healthsecure.com',
        'name': 'Nurse John Smith',
        'role': 'Nurse',
        'department': 'Pediatrics Clinic',
      },
      {
        'email': 'nurse3@healthsecure.com',
        'name': 'Nurse Clara Barton',
        'role': 'Nurse',
        'department': 'General Intake',
      },
      
      {
        'email': 'analyst1@healthsecure.com',
        'name': 'Analyst Alice Vance',
        'role': 'Analyst',
        'department': 'Biostatistics',
      },
      {
        'email': 'analyst2@healthsecure.com',
        'name': 'Analyst Bob Mercer',
        'role': 'Analyst',
        'department': 'Clinical Informatics',
      },
      
      {
        'email': 'reception1@healthsecure.com',
        'name': 'Receptionist Rachel Green',
        'role': 'Receptionist',
        'department': 'Patient Ingress Desk 1',
      },
      {
        'email': 'reception2@healthsecure.com',
        'name': 'Receptionist Monica Geller',
        'role': 'Receptionist',
        'department': 'Admissions Desk 2',
      },
    ]);
  }

  void _generateMockPatients() {
    final rand = math.Random(42); 
    final firstNames = [
      'John', 'Mary', 'James', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Elizabeth',
      'William', 'Linda', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica',
      'Thomas', 'Sarah', 'Charles', 'Karen', 'Christopher', 'Nancy', 'Daniel', 'Lisa',
      'Matthew', 'Betty', 'Anthony', 'Margaret', 'Mark', 'Sandra', 'Donald', 'Ashley'
    ];
    final lastNames = [
      'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Garcia',
      'Rodriguez', 'Wilson', 'Martinez', 'Anderson', 'Taylor', 'Thomas', 'Hernandez', 'Moore',
      'Martin', 'Jackson', 'Thompson', 'White', 'Lopez', 'Lee', 'Gonzalez', 'Harris'
    ];
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final insuranceProviders = ['Blue Cross Blue Shield', 'Aetna', 'UnitedHealthcare', 'Cigna', 'Humana', 'Medicare'];
    final addresses = [
      '742 Evergreen Terrace, Springfield', '221B Baker St, London', '120 E Delaware Pl, Chicago',
      '1600 Pennsylvania Ave, Washington', '350 Fifth Ave, New York', '10880 Malibu Point, Malibu',
      '4 Privet Drive, Little Whinging', '124 Conch St, Bikini Bottom', '312 Maple St, Seattle'
    ];

    for (int i = 0; i < 50; i++) {
      final String fn = firstNames[rand.nextInt(firstNames.length)];
      final String ln = lastNames[rand.nextInt(lastNames.length)];
      final String fullName = '$fn $ln';
      final String patientId = 'PT-${100 + i}';
      final String mrn = 'MRN-${8000 + i}-${rand.nextInt(90) + 10}';
      final int age = 18 + rand.nextInt(73); 
      final String gender = rand.nextBool() ? 'Male' : (rand.nextDouble() < 0.9 ? 'Female' : 'Other');
      final String bg = bloodGroups[rand.nextInt(bloodGroups.length)];
      final String phone = '+1 (${200 + rand.nextInt(800)}) 555-${1000 + rand.nextInt(9000)}';
      final String address = '${rand.nextInt(9999)} ${addresses[rand.nextInt(addresses.length)]}';
      final String ins = insuranceProviders[rand.nextInt(insuranceProviders.length)];
      final String emergencyName = '${firstNames[rand.nextInt(firstNames.length)]} $ln';
      final String emergencyPhone = '+1 (${200 + rand.nextInt(800)}) 555-${1000 + rand.nextInt(9000)}';
      final String emergencyContact = '$emergencyName (Spouse) - $emergencyPhone';

      final doctors = mockUsers.where((u) => u['role'] == 'Doctor').toList();
      final doctor = doctors[rand.nextInt(doctors.length)];
      final String docName = doctor['name']!;

      final dob = DateTime.now().subtract(Duration(days: age * 365 + rand.nextInt(365)));
      final consent = ConsentStatus.values[rand.nextInt(ConsentStatus.values.length)];

      final double score = 50.0 + rand.nextDouble() * 50.0; 

      patients.add(
        PatientModel(
          id: patientId,
          mrn: mrn,
          name: fullName,
          dateOfBirth: "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}",
          consentStatus: consent,
          isDataEncrypted: consent == ConsentStatus.signed ? true : rand.nextBool(),
          primaryCarePhysician: docName,
          lastAuditDate: DateTime.now().subtract(Duration(days: rand.nextInt(10))),
          complianceScore: double.parse(score.toStringAsFixed(1)),
          age: age,
          gender: gender,
          bloodGroup: bg,
          phone: phone,
          address: address,
          insuranceProvider: ins,
          emergencyContact: emergencyContact,
        ),
      );
    }
  }

  void _generateMockVisits() {
    final rand = math.Random(101);
    final clinicalComplaints = [
      'Routine annual exam', 'Chest tightness & shortness of breath', 'Diabetes HbA1c review',
      'Persistent dry cough for 2 weeks', 'Severe migraine headaches', 'Chronic lower back pain',
      'Follow-up post-cardiac stent', 'Fever & sore throat', 'Joint pain and knee swelling',
      'Abdominal discomfort & nausea', 'Allergy evaluation', 'Blood pressure calibration'
    ];
    final diagnoses = [
      'Essential hypertension', 'Type 2 diabetes mellitus', 'Acute viral bronchitis',
      'Migraine without aura', 'Lumbago with sciatica', 'Hyperlipidemia, mixed',
      'Acute pharyngitis', 'Osteoarthritis of knee', 'Gastroesophageal reflux disease',
      'Normal physical checkup', 'Allergic rhinitis, unspecified'
    ];

    final doctors = mockUsers.where((u) => u['role'] == 'Doctor').toList();

    for (int i = 0; i < 150; i++) {
      final patient = patients[rand.nextInt(patients.length)];
      final doc = doctors[rand.nextInt(doctors.length)];
      final docName = doc['name']!;
      final docEmail = doc['email']!;
      
      final complaint = clinicalComplaints[rand.nextInt(clinicalComplaints.length)];
      final dx = diagnoses[rand.nextInt(diagnoses.length)];
      
      final daysAgo = rand.nextInt(180); 
      final visitDate = DateTime.now().subtract(Duration(days: daysAgo, hours: rand.nextInt(24)));
      final followUpDate = visitDate.add(Duration(days: 14 + rand.nextInt(90)));

      visits.add(
        VisitModel(
          id: 'VS-${1000 + i}',
          patientId: patient.id,
          patientName: patient.name,
          mrn: patient.mrn,
          providerName: docName,
          visitDate: visitDate,
          syncStatus: EhrSyncStatus.values[rand.nextInt(EhrSyncStatus.values.length)],
          hasPhysicianSignature: rand.nextDouble() > 0.08, 
          billingCoded: rand.nextDouble() > 0.12,
          complianceCleared: patient.consentStatus == ConsentStatus.signed && rand.nextDouble() > 0.05,
          notes: 'Chief Complaint: $complaint. Clinical Assessment & Diagnosis: $dx.',
          doctorId: docEmail,
          chiefComplaint: complaint,
          diagnosis: dx,
          followUpDate: followUpDate,
        ),
      );
    }

    visits.sort((a, b) => b.visitDate.compareTo(a.visitDate));
  }

  void _generateMockVitals() {
    final rand = math.Random(202);
    
    for (int i = 0; i < 300; i++) {
      final patient = patients[rand.nextInt(patients.length)];
      
      final bool generateAbnormal = rand.nextDouble() < 0.25; 
      
      int systolic, diastolic, hr, spo2, glucose;
      double temp, w, h, bmi;

      h = 150.0 + rand.nextInt(40); 
      w = 50.0 + rand.nextInt(60);  
      bmi = double.parse((w / math.pow(h / 100, 2)).toStringAsFixed(1));

      if (generateAbnormal) {
        
        if (rand.nextBool()) {
          systolic = 140 + rand.nextInt(35); 
          diastolic = 90 + rand.nextInt(15);
        } else {
          systolic = 80 + rand.nextInt(9); 
          diastolic = 50 + rand.nextInt(9);
        }
        
        hr = rand.nextBool() ? 45 + rand.nextInt(14) : 101 + rand.nextInt(30);
        
        temp = rand.nextBool() ? 95.0 + rand.nextDouble() * 1.5 : 100.4 + rand.nextDouble() * 3.0;

        spo2 = 85 + rand.nextInt(10); 

        glucose = 140 + rand.nextInt(150); 
      } else {
        
        systolic = 110 + rand.nextInt(15);
        diastolic = 70 + rand.nextInt(12);
        hr = 60 + rand.nextInt(35);
        temp = 97.2 + rand.nextDouble() * 2.0;
        spo2 = 96 + rand.nextInt(4);
        glucose = 70 + rand.nextInt(55);
      }

      final recordedAt = DateTime.now().subtract(Duration(days: rand.nextInt(90), hours: rand.nextInt(24)));

      vitals.add(
        VitalsModel(
          vitalsId: 'VTL-${5000 + i}',
          patientId: patient.id,
          bloodPressure: '$systolic/$diastolic',
          heartRate: hr,
          temperature: double.parse(temp.toStringAsFixed(1)),
          spo2: spo2,
          weight: double.parse(w.toStringAsFixed(1)),
          height: double.parse(h.toStringAsFixed(1)),
          bmi: bmi,
          bloodSugar: glucose,
          recordedAt: recordedAt,
        ),
      );
    }

    vitals.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  void _generateMockAudits() {
    final rand = math.Random(303);
    final users = mockUsers.toList();

    final auditActions = [
      {'name': 'Cognito Clinician Login', 'desc': 'Clinician authenticated successfully via secure multi-factor authentication (MFA).', 'reg': 'HIPAA Sec. 164.308'},
      {'name': 'Patient Profile Created', 'desc': 'New patient registry chart committed and KMS encryption keys generated.', 'reg': 'HIPAA Sec. 164.312'},
      {'name': 'Patient Chart Updated', 'desc': 'Demographic and insurance policy metadata synchronized.', 'reg': 'HIPAA Sec. 164.502'},
      {'name': 'Vitals Telemetry Ingested', 'desc': 'Uploaded and validated physiological vital stats measurements.', 'reg': 'HIPAA Sec. 164.312(b)'},
      {'name': 'Clinical Visit Recorded', 'desc': 'Visit diagnosis notes committed. Syncing with regional EHR node.', 'reg': 'SOC 2 Type II'},
      {'name': 'Analytics Dashboard Viewed', 'desc': 'Executive reporting query executed. Aggregated population graphs loaded.', 'reg': 'HIPAA Sec. 164.312(c)'},
      {'name': 'Cognito Clinician Logout', 'desc': 'User session terminated. Active auth tokens flushed.', 'reg': 'HIPAA Sec. 164.308'},
    ];

    for (int i = 0; i < 200; i++) {
      final user = users[rand.nextInt(users.length)];
      final action = auditActions[rand.nextInt(auditActions.length)];
      final daysAgo = rand.nextInt(30);
      final timestamp = DateTime.now().subtract(Duration(days: daysAgo, hours: rand.nextInt(24), minutes: rand.nextInt(60)));
      
      final bool isCritical = action['name'] == 'S3 Ingestion Quarantined' || rand.nextDouble() < 0.03;
      final severity = isCritical
          ? AuditSeverity.critical
          : (rand.nextDouble() < 0.15 ? AuditSeverity.medium : AuditSeverity.low);
          
      final status = severity == AuditSeverity.critical
          ? AuditStatus.failed
          : (severity == AuditSeverity.medium ? AuditStatus.flagged : AuditStatus.passed);

      audits.add(
        AuditModel(
          id: 'AUD-${1000 + i}',
          eventName: action['name']!,
          actorName: user['name']!,
          actorRole: user['role']!,
          timestamp: timestamp,
          severity: severity,
          status: status,
          regulation: action['reg']!,
          description: action['desc']!,
          ipAddress: '192.168.10.${50 + rand.nextInt(150)}',
        ),
      );
    }

    audits.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _generatePipelineData() {
    final rand = math.Random(404);
    pipelineLogs.clear();

    pipelineSubmitted = 115;
    pipelineValidated = 100;
    pipelineRejected = 15;

    for (int i = 0; i < 100; i++) {
      final String ptId = 'PT-${100 + rand.nextInt(50)}';
      pipelineLogs.add({
        'timestamp': DateTime.now().subtract(Duration(hours: rand.nextInt(120), minutes: rand.nextInt(60))),
        'type': 'success',
        'message': 'Ingestion verified: S3 s3://healthsecure-raw-data/$ptId-vitals.json scrubbed of PII, encrypted KMS, synced to curated.',
        'details': {
          'patientId': ptId,
          'bp': '${110 + rand.nextInt(15)}/${70 + rand.nextInt(12)}',
          'weight': double.parse((55.0 + rand.nextDouble() * 30.0).toStringAsFixed(1)),
          'phone': '+1 555-019-923${rand.nextInt(10)}',
        }
      });
    }

    for (int i = 0; i < 4; i++) {
      pipelineLogs.add({
        'timestamp': DateTime.now().subtract(Duration(hours: rand.nextInt(72), minutes: rand.nextInt(60))),
        'type': 'quarantine',
        'message': '🚨 Quarantine Alert: Ingestion rejected. Missing patient identifier key. Payload isolated to s3://healthsecure-quarantine/err-missing-id-${100+i}.json',
        'details': {
          'patientId': '',
          'bp': '120/80',
          'weight': 70.0,
          'phone': '+1 555-102-3040',
        }
      });
    }

    for (int i = 0; i < 4; i++) {
      final String ptId = 'PT-${100 + rand.nextInt(50)}';
      final badBp = rand.nextBool() ? 'HIGH-BP' : '120_80';
      pipelineLogs.add({
        'timestamp': DateTime.now().subtract(Duration(hours: rand.nextInt(72), minutes: rand.nextInt(60))),
        'type': 'quarantine',
        'message': '🚨 Quarantine Alert: Ingestion failed for $ptId. Invalid Blood Pressure format \'$badBp\'. Expected \'Systolic/Diastolic\' numeric standard.',
        'details': {
          'patientId': ptId,
          'bp': badBp,
          'weight': 68.5,
          'phone': '+1 555-123-4567',
        }
      });
    }

    for (int i = 0; i < 4; i++) {
      final String ptId = 'PT-${100 + rand.nextInt(50)}';
      final badWeight = -45.0 - rand.nextInt(20);
      pipelineLogs.add({
        'timestamp': DateTime.now().subtract(Duration(hours: rand.nextInt(72), minutes: rand.nextInt(60))),
        'type': 'quarantine',
        'message': '🚨 Quarantine Alert: Ingestion failed for $ptId. Physiological weight validation failed (received \'$badWeight kg\'). Negatives isolated to quarantine.',
        'details': {
          'patientId': ptId,
          'bp': '118/79',
          'weight': badWeight,
          'phone': '+1 555-333-2211',
        }
      });
    }

    for (int i = 0; i < 3; i++) {
      final String ptId = 'PT-${100 + rand.nextInt(50)}';
      final badPhone = '123';
      pipelineLogs.add({
        'timestamp': DateTime.now().subtract(Duration(hours: rand.nextInt(72), minutes: rand.nextInt(60))),
        'type': 'quarantine',
        'message': '🚨 Quarantine Alert: Ingestion failed for $ptId. Phone number \'$badPhone\' failed E.164 compliance checks (minimum length constraint).',
        'details': {
          'patientId': ptId,
          'bp': '122/80',
          'weight': 74.2,
          'phone': badPhone,
        }
      });
    }

    pipelineLogs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
  }

  void _generateCloudWatchMetrics() {
    final rand = math.Random(505);
    cwApiRequests = 25000 + rand.nextInt(8000);
    cwLambdaInvocations = 42000 + rand.nextInt(12000);
    cwLambdaFailures = 15 + rand.nextInt(25);
    cwEtlRuns = 350 + rand.nextInt(80);
    cwEtlFailures = 4 + rand.nextInt(8);

    compliancePassed = 1240 + rand.nextInt(150);
    complianceFailed = 12 + rand.nextInt(8);
    quarantineEvents = pipelineRejected; 
  }
}