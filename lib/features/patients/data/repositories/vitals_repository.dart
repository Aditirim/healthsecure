import 'package:healthsecure/features/patients/data/models/vitals_model.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';

class VitalsRepository {
  final PatientApiService _apiService;

  VitalsRepository({PatientApiService? apiService})
      : _apiService = apiService ?? PatientApiService();

  Future<VitalsRegistrationResult> saveVitals(VitalsModel record) async {
    try {
      final response = await _apiService.submitVitals(record);
      final details = response['details'] as Map<String, dynamic>;

      return VitalsRegistrationResult.success(
        vitalsId: details['vitalsId'] ?? record.vitalsId,
        s3Bucket: details['bucket'] ?? 'healthsecure-raw-data',
        s3Key: details['key'] ?? '',
        timestamp: DateTime.tryParse(details['timestamp'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to save vitals to live AWS backend: $e');
    }
  }
}

class VitalsRegistrationResult {
  final bool isSuccess;
  final String vitalsId;
  final String s3Bucket;
  final String s3Key;
  final DateTime timestamp;

  VitalsRegistrationResult({
    required this.isSuccess,
    required this.vitalsId,
    required this.s3Bucket,
    required this.s3Key,
    required this.timestamp,
  });

  factory VitalsRegistrationResult.success({
    required String vitalsId,
    required String s3Bucket,
    required String s3Key,
    required DateTime timestamp,
  }) {
    return VitalsRegistrationResult(
      isSuccess: true,
      vitalsId: vitalsId,
      s3Bucket: s3Bucket,
      s3Key: s3Key,
      timestamp: timestamp,
    );
  }
}