import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/patients/data/models/vitals_model.dart';
import 'package:healthsecure/features/patients/data/models/patient_model.dart';
import 'package:healthsecure/features/patients/data/repositories/vitals_repository.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';

class VitalsRecordingPage extends StatefulWidget {
  final String patientName;
  final String mrn;

  const VitalsRecordingPage({
    super.key,
    required this.patientName,
    required this.mrn,
  });

  @override
  State<VitalsRecordingPage> createState() => _VitalsRecordingPageState();
}

class _VitalsRecordingPageState extends State<VitalsRecordingPage> {
  final _formKey = GlobalKey<FormState>();
  String _userRole = 'Guest';

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodSugarController = TextEditingController();

  double? _bmi;
  String _bmiCategory = 'N/A';
  Color _bmiColor = Colors.grey;
  
  final List<String> _clinicalAlerts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    
    _systolicController.addListener(_evaluateVitals);
    _diastolicController.addListener(_evaluateVitals);
    _heartRateController.addListener(_evaluateVitals);
    _tempController.addListener(_evaluateVitals);
    _spo2Controller.addListener(_evaluateVitals);
    _weightController.addListener(_evaluateVitals);
    _heightController.addListener(_evaluateVitals);
    _bloodSugarController.addListener(_evaluateVitals);
  }

  Future<void> _loadUserRole() async {
    final role = await CognitoAuthService.instance.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bloodSugarController.dispose();
    super.dispose();
  }

  void _evaluateVitals() {
    final List<String> alerts = [];

    final double? weight = double.tryParse(_weightController.text);
    final double? height = double.tryParse(_heightController.text);

    if (weight != null && height != null && height > 0) {
      final double heightInMeters = height / 100.0;
      final double calculatedBmi = weight / (heightInMeters * heightInMeters);
      
      _bmi = double.parse(calculatedBmi.toStringAsFixed(1));

      if (_bmi! < 18.5) {
        _bmiCategory = 'Underweight';
        _bmiColor = Colors.orange;
        alerts.add('⚠️ Low BMI Index (Underweight)');
      } else if (_bmi! >= 18.5 && _bmi! <= 24.9) {
        _bmiCategory = 'Normal Weight';
        _bmiColor = AppTheme.complianceSecure;
      } else if (_bmi! >= 25.0 && _bmi! <= 29.9) {
        _bmiCategory = 'Overweight';
        _bmiColor = Colors.orange;
        alerts.add('⚠️ High BMI Index (Overweight)');
      } else {
        _bmiCategory = 'Obese';
        _bmiColor = AppTheme.complianceDanger;
        alerts.add('🚨 Critical BMI Index (Class I+ Obesity)');
      }
    } else {
      _bmi = null;
      _bmiCategory = 'N/A';
      _bmiColor = Colors.grey;
    }

    final int? systolic = int.tryParse(_systolicController.text);
    final int? diastolic = int.tryParse(_diastolicController.text);

    if (systolic != null) {
      if (systolic > 130) {
        alerts.add('⚠️ Elevated Systolic BP (> 130 mmHg)');
      } else if (systolic < 90) {
        alerts.add('🚨 Hypotension Alert: Low Systolic BP (< 90 mmHg)');
      }
    }
    if (diastolic != null) {
      if (diastolic > 80) {
        alerts.add('⚠️ Elevated Diastolic BP (> 80 mmHg)');
      } else if (diastolic < 60) {
        alerts.add('🚨 Hypotension Alert: Low Diastolic BP (< 60 mmHg)');
      }
    }

    final int? hr = int.tryParse(_heartRateController.text);
    if (hr != null) {
      if (hr > 100) {
        alerts.add('🚨 Tachycardia Alert: High Heart Rate (> 100 bpm)');
      } else if (hr < 60) {
        alerts.add('⚠️ Bradycardia Alert: Low Heart Rate (< 60 bpm)');
      }
    }

    final double? temp = double.tryParse(_tempController.text);
    if (temp != null) {
      if (temp > 99.5) {
        alerts.add('🚨 Pyrexia Alert: Patient Fever (> 99.5 °F)');
      } else if (temp < 97.0) {
        alerts.add('⚠️ Hypothermia Alert: Low Body Temp (< 97.0 °F)');
      }
    }

    final int? spo2 = int.tryParse(_spo2Controller.text);
    if (spo2 != null) {
      if (spo2 < 95) {
        alerts.add('🚨 Hypoxia Alert: Critical Oxygen Saturation (< 95%)');
      }
    }

    final int? sugar = int.tryParse(_bloodSugarController.text);
    if (sugar != null) {
      if (sugar > 140) {
        alerts.add('⚠️ Hyperglycemia Alert: Elevated Blood Sugar (> 140 mg/dL)');
      } else if (sugar < 70) {
        alerts.add('🚨 Hypoglycemia Alert: Low Blood Sugar (< 70 mg/dL)');
      }
    }

    setState(() {
      _clinicalAlerts.clear();
      _clinicalAlerts.addAll(alerts);
    });
  }

  Color _getFieldHighlightColor(String value, bool isAbnormal, Color primaryColor) {
    if (value.trim().isEmpty) return Colors.grey.withOpacity(0.3);
    return isAbnormal ? AppTheme.complianceDanger : AppTheme.complianceSecure;
  }

  bool _isSystolicAbnormal() {
    final int? val = int.tryParse(_systolicController.text);
    return val != null && (val > 130 || val < 90);
  }

  bool _isDiastolicAbnormal() {
    final int? val = int.tryParse(_diastolicController.text);
    return val != null && (val > 80 || val < 60);
  }

  bool _isHrAbnormal() {
    final int? val = int.tryParse(_heartRateController.text);
    return val != null && (val > 100 || val < 60);
  }

  bool _isTempAbnormal() {
    final double? val = double.tryParse(_tempController.text);
    return val != null && (val > 99.5 || val < 97.0);
  }

  bool _isSpo2Abnormal() {
    final int? val = int.tryParse(_spo2Controller.text);
    return val != null && val < 95;
  }

  bool _isSugarAbnormal() {
    final int? val = int.tryParse(_bloodSugarController.text);
    return val != null && (val > 140 || val < 70);
  }

  void _handleSaveVitals(Color primaryColor, bool isDark) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      String patientId = widget.mrn;
      try {
        final matchingPatient = DemoDataGenerator.instance.patients.firstWhere(
          (p) => p.mrn.toLowerCase() == widget.mrn.toLowerCase(),
        );
        patientId = matchingPatient.id;
      } catch (_) {}

      final systolic = int.tryParse(_systolicController.text) ?? 120;
      final diastolic = int.tryParse(_diastolicController.text) ?? 80;
      final hr = int.tryParse(_heartRateController.text) ?? 72;
      final temp = double.tryParse(_tempController.text) ?? 98.6;
      final spo2 = int.tryParse(_spo2Controller.text) ?? 98;
      final weight = double.tryParse(_weightController.text) ?? 70.0;
      final height = double.tryParse(_heightController.text) ?? 170.0;
      final sugar = int.tryParse(_bloodSugarController.text) ?? 90;
      final bmi = _bmi ?? 24.2;

      final record = VitalsModel(
        vitalsId: 'VTL-${math.Random().nextInt(9000) + 1000}',
        patientId: patientId,
        bloodPressure: '$systolic/$diastolic',
        heartRate: hr,
        temperature: temp,
        spo2: spo2,
        weight: weight,
        height: height,
        bmi: bmi,
        bloodSugar: sugar,
        recordedAt: DateTime.now(),
      );

      final result = await VitalsRepository().saveVitals(record);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            final isDarkTheme = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: const [
                  Icon(Icons.cloud_upload_outlined, color: AppTheme.complianceSecure, size: 28),
                  SizedBox(width: 12),
                  Text('AWS Ingest Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vitals record successfully validated, KMS encrypted and synchronized to AWS S3 cold vault.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkTheme ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildReceiptRow('INGEST STACK', 'prod/vitals', theme),
                        const Divider(height: 16),
                        _buildReceiptRow('S3 BUCKET', result.s3Bucket, theme),
                        const Divider(height: 16),
                        _buildReceiptRow('S3 KEY', result.s3Key, theme),
                        const Divider(height: 16),
                        _buildReceiptRow('ENCRYPTION', 'KMS AES-256', theme),
                        const Divider(height: 16),
                        _buildReceiptRow('RECORD ID', result.vitalsId, theme),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Back to Registry'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Widget _buildReceiptRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 0.5),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Vital Signs',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Patient: ${_userRole == 'Admin' ? widget.patientName : PatientModel.maskName(widget.patientName)} (${widget.mrn})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 11,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      _buildDiagnosticSummaryBox(isDark),
                      const SizedBox(height: 24),

                      Text(
                        'PHYSIOLOGICAL TELEMETRY',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Systolic BP (mmHg)',
                              controller: _systolicController,
                              prefixIcon: Icons.speed_outlined,
                              isAbnormal: _isSystolicAbnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Diastolic BP (mmHg)',
                              controller: _diastolicController,
                              prefixIcon: Icons.speed_outlined,
                              isAbnormal: _isDiastolicAbnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Heart Rate (bpm)',
                              controller: _heartRateController,
                              prefixIcon: Icons.favorite_border,
                              isAbnormal: _isHrAbnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Body Temp (°F)',
                              controller: _tempController,
                              prefixIcon: Icons.thermostat_outlined,
                              isAbnormal: _isTempAbnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                              isDecimal: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Oxygen SpO2 (%)',
                              controller: _spo2Controller,
                              prefixIcon: Icons.bubble_chart_outlined,
                              isAbnormal: _isSpo2Abnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                              maxVal: 100,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildVitalsInputField(
                              labelText: 'Blood Sugar (mg/dL)',
                              controller: _bloodSugarController,
                              prefixIcon: Icons.grain_outlined,
                              isAbnormal: _isSugarAbnormal(),
                              primaryColor: primaryColor,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      const Divider(),
                      const SizedBox(height: 20),

                      Text(
                        'BIOMETRIC GAUGES',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                labelText: 'Height (cm)',
                                hintText: '175.5',
                                prefixIcon: const Icon(Icons.height),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Required';
                                if (double.tryParse(value) == null) return 'Numbers only';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                labelText: 'Weight (kg)',
                                hintText: '72.3',
                                prefixIcon: const Icon(Icons.monitor_weight_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Required';
                                if (double.tryParse(value) == null) return 'Numbers only';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildBmiDisplayPanel(isDark),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : () => _handleSaveVitals(primaryColor, isDark),
                    icon: _isSaving 
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isSaving ? 'Syncing...' : 'Sync & Save Vitals'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsInputField({
    required String labelText,
    required TextEditingController controller,
    required IconData prefixIcon,
    required bool isAbnormal,
    required Color primaryColor,
    required bool isDark,
    bool isDecimal = false,
    int? maxVal,
  }) {
    final String value = controller.text;
    final Color highlightColor = _getFieldHighlightColor(value, isAbnormal, primaryColor);

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontWeight: value.trim().isNotEmpty ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(
          prefixIcon,
          color: value.trim().isEmpty 
              ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)) 
              : highlightColor,
        ),
        suffixIcon: value.trim().isNotEmpty
            ? Icon(
                isAbnormal ? Icons.warning_amber : Icons.check_circle_outline,
                color: highlightColor,
                size: 16,
              )
            : null,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: value.trim().isEmpty ? primaryColor : highlightColor,
            width: 2.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: value.trim().isEmpty
                ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                : highlightColor.withOpacity(0.5),
            width: value.trim().isEmpty ? 1.0 : 1.5,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final num? parsed = isDecimal ? double.tryParse(val) : int.tryParse(val);
        if (parsed == null) return 'Numbers only';
        if (maxVal != null && parsed > maxVal) return 'Max $maxVal';
        return null;
      },
    );
  }

  Widget _buildDiagnosticSummaryBox(bool isDark) {
    if (_clinicalAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.complianceSecure.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.complianceSecure.withOpacity(0.2), width: 1.2),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.complianceSecure, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'All physiological parameters reside within standard clinical reference bounds.',
                style: TextStyle(
                  color: AppTheme.complianceSecure,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.complianceDanger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.complianceDanger.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: AppTheme.complianceDanger, size: 20),
              SizedBox(width: 12),
              Text(
                'CLINICAL DIAGNOSTIC ALERTS ACTIVE',
                style: TextStyle(
                  color: AppTheme.complianceDanger,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: _clinicalAlerts.map((alert) {
              final isRed = alert.startsWith('🚨');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isRed 
                              ? AppTheme.complianceDanger 
                              : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBmiDisplayPanel(bool isDark) {
    if (_bmi == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            'Enter Height & Weight to auto-calculate BMI',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bmiColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bmiColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: _bmiColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$_bmi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _bmiColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BODY MASS INDEX (BMI)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _bmiCategory,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _bmiColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Auto-calculated based on clinical metrics.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}