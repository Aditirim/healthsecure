import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';

class VisitRepository {
  final PatientApiService _apiService;

  VisitRepository({PatientApiService? apiService}) 
      : _apiService = apiService ?? PatientApiService();

  Future<VisitRegistrationResult> saveVisit(VisitModel visit) async {
    try {
      final response = await _apiService.submitVisit(visit);
      final details = response['details'] as Map<String, dynamic>;
      
      return VisitRegistrationResult.success(
        visitId: details['visitId'] ?? visit.id,
        s3Bucket: details['bucket'] ?? 'healthsecure-raw-data',
        s3Key: details['key'] ?? '',
        timestamp: DateTime.tryParse(details['timestamp'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to save visit to live AWS backend: $e');
    }
  }
}

class VisitRegistrationResult {
  final bool isSuccess;
  final String visitId;
  final String s3Bucket;
  final String s3Key;
  final DateTime timestamp;

  VisitRegistrationResult({
    required this.isSuccess,
    required this.visitId,
    required this.s3Bucket,
    required this.s3Key,
    required this.timestamp,
  });

  factory VisitRegistrationResult.success({
    required String visitId,
    required String s3Bucket,
    required String s3Key,
    required DateTime timestamp,
  }) {
    return VisitRegistrationResult(
      isSuccess: true,
      visitId: visitId,
      s3Bucket: s3Bucket,
      s3Key: s3Key,
      timestamp: timestamp,
    );
  }
}