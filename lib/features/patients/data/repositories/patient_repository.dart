import 'package:healthsecure/features/patients/data/models/patient_registration_model.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';

class PatientRepository {
  final PatientApiService _apiService;

  PatientRepository({PatientApiService? apiService}) 
      : _apiService = apiService ?? PatientApiService();

  Future<PatientRegistrationResult> registerPatient(PatientRegistrationModel registration) async {
    try {
      final response = await _apiService.submitPatientRecord(registration);
      
      final details = response['details'] as Map<String, dynamic>;

      return PatientRegistrationResult.success(
        patientId: details['patientId'] ?? registration.patientId,
        s3Bucket: details['bucket'] ?? 'healthsecure-raw-data',
        s3Key: details['key'] ?? '',
        timestamp: DateTime.tryParse(details['timestamp'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      
      if (e is PatientValidationException) {
        return PatientRegistrationResult.validationFailure(
          errorMessage: e.message,
          errors: e.validationErrors,
        );
      } else {
        return PatientRegistrationResult.systemFailure(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}

enum RegistrationStatus { success, validationFailure, systemFailure }

class PatientRegistrationResult {
  final RegistrationStatus status;
  final String errorMessage;
  final List<String> validationErrors;
  
  final String patientId;
  final String s3Bucket;
  final String s3Key;
  final DateTime? timestamp;

  PatientRegistrationResult._({
    required this.status,
    this.errorMessage = '',
    this.validationErrors = const [],
    this.patientId = '',
    this.s3Bucket = '',
    this.s3Key = '',
    this.timestamp,
  });

  factory PatientRegistrationResult.success({
    required String patientId,
    required String s3Bucket,
    required String s3Key,
    required DateTime timestamp,
  }) {
    return PatientRegistrationResult._(
      status: RegistrationStatus.success,
      patientId: patientId,
      s3Bucket: s3Bucket,
      s3Key: s3Key,
      timestamp: timestamp,
    );
  }

  factory PatientRegistrationResult.validationFailure({
    required String errorMessage,
    required List<String> errors,
  }) {
    return PatientRegistrationResult._(
      status: RegistrationStatus.validationFailure,
      errorMessage: errorMessage,
      validationErrors: errors,
    );
  }

  factory PatientRegistrationResult.systemFailure({
    required String errorMessage,
  }) {
    return PatientRegistrationResult._(
      status: RegistrationStatus.systemFailure,
      errorMessage: errorMessage,
    );
  }

  bool get isSuccess => status == RegistrationStatus.success;
  bool get isValidationFailure => status == RegistrationStatus.validationFailure;
  bool get isSystemFailure => status == RegistrationStatus.systemFailure;
}