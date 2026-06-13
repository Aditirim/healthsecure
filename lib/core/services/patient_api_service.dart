import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:healthsecure/core/constants/app_constants.dart';
import 'package:healthsecure/features/patients/data/models/patient_registration_model.dart';
import 'package:healthsecure/features/visits/data/models/visit_model.dart';
import 'package:healthsecure/features/patients/data/models/vitals_model.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';

class PatientApiService {
  final http.Client _httpClient;

  PatientApiService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  Future<Map<String, String>> _getHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final String? accessToken = await CognitoAuthService.instance.getAccessToken();
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    } catch (authError) {
      print('Warning: Active Cognito session credentials not found: $authError');
    }
    return headers;
  }

  Future<Map<String, dynamic>> submitPatientRecord(PatientRegistrationModel patient) async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}patient');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.post(
        endpoint,
        headers: headers,
        body: json.encode(patient.toJson()),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return responseData;
      } else if (response.statusCode == 400) {
        final List<dynamic> errors = responseData['errors'] ?? ['Validation rejected.'];
        final String message = responseData['message'] ?? 'Validation failure';
        throw PatientValidationException(message, List<String>.from(errors));
      } else {
        final String message = responseData['message'] ?? 'Record ingestion failed';
        throw Exception('AWS Ingestion Failure (${response.statusCode}): $message');
      }
    } catch (e) {
      if (e is PatientValidationException) {
        rethrow;
      }
      throw Exception('Clinical Ingestion Channel Unavailable: ${e.toString()}');
    }
  }

  Future<List<dynamic>> fetchPatients() async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}patient');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.get(endpoint, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to fetch patient list from AWS (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('AWS Backend Connection Refused: $e');
    }
  }

  Future<Map<String, dynamic>> submitVisit(VisitModel visit) async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}visit');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.post(
        endpoint,
        headers: headers,
        body: json.encode(visit.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('AWS Visit Ingestion Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('AWS Visit Connection Refused: $e');
    }
  }

  Future<List<dynamic>> fetchVisits() async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}visit');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.get(endpoint, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to fetch visits from AWS (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('AWS Backend Connection Refused: $e');
    }
  }

  Future<Map<String, dynamic>> submitVitals(VitalsModel vitals) async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}vitals');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.post(
        endpoint,
        headers: headers,
        body: json.encode(vitals.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('AWS Vitals Ingestion Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('AWS Vitals Connection Refused: $e');
    }
  }

  Future<List<dynamic>> fetchVitals() async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}vitals');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.get(endpoint, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to fetch vitals from AWS (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('AWS Backend Connection Refused: $e');
    }
  }

  Future<List<dynamic>> fetchAudits() async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}audit');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.get(endpoint, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to fetch audit traces from AWS (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('AWS Backend Connection Refused: $e');
    }
  }

  Future<Map<String, dynamic>> submitAudit(AuditModel audit) async {
    final endpoint = Uri.parse('${AppConstants.apiBaseUrl}audit');
    final headers = await _getHeaders();

    try {
      final response = await _httpClient.post(
        endpoint,
        headers: headers,
        body: json.encode(audit.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('AWS Audit Ingestion Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('AWS Audit Connection Refused: $e');
    }
  }
}

class PatientValidationException implements Exception {
  final String message;
  final List<String> validationErrors;

  PatientValidationException(this.message, this.validationErrors);

  @override
  String toString() {
    return 'PatientValidationException: $message\nErrors: ${validationErrors.join(', ')}';
  }
}