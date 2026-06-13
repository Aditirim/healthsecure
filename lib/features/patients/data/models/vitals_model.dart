class VitalsModel {
  final String vitalsId;
  final String patientId;
  final String bloodPressure; 
  final int heartRate;
  final double temperature;
  final int spo2;
  final double weight;
  final double height;
  final double bmi;
  final int bloodSugar;
  final DateTime recordedAt;

  const VitalsModel({
    required this.vitalsId,
    required this.patientId,
    required this.bloodPressure,
    required this.heartRate,
    required this.temperature,
    required this.spo2,
    required this.weight,
    required this.height,
    required this.bmi,
    required this.bloodSugar,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'vitalsId': vitalsId,
      'patientId': patientId,
      'bloodPressure': bloodPressure,
      'heartRate': heartRate,
      'temperature': temperature,
      'spo2': spo2,
      'weight': weight,
      'height': height,
      'bmi': bmi,
      'bloodSugar': bloodSugar,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  bool get isNormal {
    
    try {
      final parts = bloodPressure.split('/');
      if (parts.length == 2) {
        final systolic = int.parse(parts[0]);
        final diastolic = int.parse(parts[1]);
        if (systolic < 90 || systolic > 130 || diastolic < 60 || diastolic > 85) {
          return false;
        }
      }
    } catch (_) {
      return false;
    }

    if (spo2 < 95) return false;

    if (heartRate < 60 || heartRate > 100) return false;

    if (temperature < 97.0 || temperature > 99.5) return false;

    if (bloodSugar < 70 || bloodSugar > 140) return false;

    return true;
  }
}