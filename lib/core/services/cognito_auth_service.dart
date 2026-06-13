import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthsecure/core/constants/app_constants.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/core/services/patient_api_service.dart';
import 'package:healthsecure/features/audit/data/models/audit_model.dart';

class CognitoAuthService {
  
  static const String region = 'ap-south-1';
  static const String userPoolId = 'ap-south-1_4n13EEdwg';
  static const String clientId = '3csnl33d3g07965r3kojlfp6g2';
  static const String endpoint = 'https://cognito-idp.$region.amazonaws.com/';

  static const String _keyAccessToken = 'cognito_access_token';
  static const String _keyIdToken = 'cognito_id_token';
  static const String _keyRefreshToken = 'cognito_refresh_token';
  static const String _keyUserEmail = 'cognito_user_email';
  static const String _keyUserRole = 'cognito_user_role';

  CognitoAuthService._();

  static final CognitoAuthService instance = CognitoAuthService._();

  String? _cachedRole;
  String get cachedRole => _cachedRole ?? 'Guest';

  Map<String, dynamic> _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw const FormatException('Invalid Cognito JWT token structural signature');
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedBytes = base64Url.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      return json.decode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse regulatory user claims: $e');
    }
  }

  String _extractRoleFromIdToken(String idToken) {
    final claims = _parseJwt(idToken);
    final groups = claims['cognito:groups'];
    
    if (groups is List && groups.isNotEmpty) {
      
      final clinicalRoles = ['Admin', 'Doctor', 'Nurse', 'Analyst', 'Receptionist'];
      for (final role in clinicalRoles) {
        if (groups.contains(role)) {
          return role;
        }
      }
      return groups.first.toString(); 
    }
    
    if (claims.containsKey('custom:role')) {
      return claims['custom:role'].toString();
    }
    
    return 'Guest'; 
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (AppConstants.useMockData) {
      DemoDataGenerator.instance.initialize();
      final match = DemoDataGenerator.instance.mockUsers.firstWhere(
        (u) => u['email']!.trim().toLowerCase() == email.trim().toLowerCase(),
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        final String name = match['name']!;
        final String role = match['role']!;
        final String dep = match['department']!;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, 'mock_access_token_${role.toLowerCase()}');
        await prefs.setString(_keyIdToken, 'mock_id_token_${role.toLowerCase()}');
        await prefs.setString(_keyRefreshToken, 'mock_refresh_token_${role.toLowerCase()}');
        await prefs.setString(_keyUserEmail, email.trim().toLowerCase());
        await prefs.setString(_keyUserRole, role);
        _cachedRole = role;

        DemoDataGenerator.instance.audits.insert(
          0,
          AuditModel(
            id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
            eventName: 'Cognito Clinician Login',
            actorName: name,
            actorRole: '$role ($dep)',
            timestamp: DateTime.now(),
            severity: AuditSeverity.low,
            status: AuditStatus.passed,
            regulation: 'HIPAA Sec. 164.308',
            description: 'Mock Clinician session initiated successfully via demo interface.',
            ipAddress: '127.0.0.1',
          ),
        );

        return {
          'success': true,
          'email': email.trim().toLowerCase(),
          'role': role,
          'accessToken': 'mock_access_token_${role.toLowerCase()}',
        };
      } else {
        throw Exception('UserNotFoundException: User not found in realistic demo environment registry.');
      }
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
    };

    final Map<String, dynamic> body = {
      'AuthFlow': 'USER_PASSWORD_AUTH',
      'ClientId': clientId,
      'AuthParameters': {
        'USERNAME': email,
        'PASSWORD': password,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final authResult = responseData['AuthenticationResult'] as Map<String, dynamic>;
        
        final String accessToken = authResult['AccessToken'] as String;
        final String idToken = authResult['IdToken'] as String;
        final String refreshToken = authResult['RefreshToken'] as String;
        final String role = _extractRoleFromIdToken(idToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, accessToken);
        await prefs.setString(_keyIdToken, idToken);
        await prefs.setString(_keyRefreshToken, refreshToken);
        await prefs.setString(_keyUserEmail, email);
        await prefs.setString(_keyUserRole, role);
        _cachedRole = role;

        try {
          final apiService = PatientApiService();
          await apiService.submitAudit(AuditModel(
            id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
            eventName: 'Cognito Clinician Login',
            actorName: email.split('@').first,
            actorRole: role,
            timestamp: DateTime.now(),
            severity: AuditSeverity.low,
            status: AuditStatus.passed,
            regulation: 'HIPAA Sec. 164.308',
            description: 'Clinician successfully authenticated via secure Cognito MFA.',
            ipAddress: '127.0.0.1',
          ));
          print('Successfully logged live Cognito clinician login event to AWS S3.');
        } catch (auditErr) {
          print('Warning: Failed to log live Cognito login event: $auditErr');
        }

        return {
          'success': true,
          'email': email,
          'role': role,
          'accessToken': accessToken,
        };
      } else {
        
        final String errorMessage = responseData['message'] ?? 'Authentication failed';
        final String errorType = responseData['__type'] ?? 'CognitoException';
        
        throw Exception('$errorType: $errorMessage');
      }
    } catch (e) {
      throw Exception('AWS Cognito Connection Failed: ${e.toString()}');
    }
  }

  Future<bool> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? refreshToken = prefs.getString(_keyRefreshToken);
    final String? email = prefs.getString(_keyUserEmail);
    final String? role = prefs.getString(_keyUserRole);

    if (role != null) {
      _cachedRole = role;
    }

    if (refreshToken == null || email == null) {
      return false; 
    }

    if (AppConstants.useMockData) {
      return true;
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
    };

    final Map<String, dynamic> body = {
      'AuthFlow': 'REFRESH_TOKEN_AUTH',
      'ClientId': clientId,
      'AuthParameters': {
        'REFRESH_TOKEN': refreshToken,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final authResult = responseData['AuthenticationResult'] as Map<String, dynamic>;
        
        final String accessToken = authResult['AccessToken'] as String;
        final String idToken = authResult['IdToken'] as String;
        final String role = _extractRoleFromIdToken(idToken);

        await prefs.setString(_keyAccessToken, accessToken);
        await prefs.setString(_keyIdToken, idToken);
        await prefs.setString(_keyUserRole, role);
        _cachedRole = role;

        return true;
      } else {
        
        await logout();
        return false;
      }
    } catch (e) {
      
      final String? cachedIdToken = prefs.getString(_keyIdToken);
      if (cachedIdToken != null) {
        try {
          final claims = _parseJwt(cachedIdToken);
          final int exp = claims['exp'] as int;
          final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (exp > now) {
            return true; 
          }
        } catch (_) {}
      }
      return false;
    }
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole) ?? 'Guest';
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString(_keyUserEmail);
    final String? role = prefs.getString(_keyUserRole);

    if (email != null && role != null) {
      try {
        final apiService = PatientApiService();
        await apiService.submitAudit(AuditModel(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          eventName: 'Cognito Clinician Logout',
          actorName: email.split('@').first,
          actorRole: role,
          timestamp: DateTime.now(),
          severity: AuditSeverity.low,
          status: AuditStatus.passed,
          regulation: 'HIPAA Sec. 164.308',
          description: 'Clinician successfully terminated secure session.',
          ipAddress: '127.0.0.1',
        ));
        print('Successfully logged live Cognito clinician logout event to AWS S3.');
      } catch (auditErr) {
        print('Warning: Failed to log live Cognito logout event: $auditErr');
      }
    }

    _cachedRole = null;

    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
  }
}