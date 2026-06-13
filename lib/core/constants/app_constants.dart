class AppConstants {
  AppConstants._();

  static const String appName = 'HealthSecure Compliance';
  
  static const String apiBaseUrl = 'https://5l6p1glnc3.execute-api.ap-south-1.amazonaws.com/prod/';
  
  static const bool useMockData = false;
  
  static const String hipaa = 'HIPAA';
  static const String gdpr = 'GDPR';
  static const String soc2 = 'SOC 2 Type II';
  static const String hitech = 'HITECH';

  static const String categoryPrivacy = 'Data Privacy';
  static const String categorySecurity = 'Technical Security';
  static const String categoryAdministrative = 'Administrative Safeguards';
  static const String categoryPhysical = 'Physical Safeguards';

  static const double targetComplianceScore = 100.0;
  static const double minimumPassingScore = 95.0;
}