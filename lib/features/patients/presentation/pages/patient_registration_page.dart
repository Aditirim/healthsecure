import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/features/patients/data/models/patient_registration_model.dart';
import 'package:healthsecure/features/patients/data/repositories/patient_repository.dart';

class PatientRegistrationPage extends StatefulWidget {
  const PatientRegistrationPage({super.key});

  @override
  State<PatientRegistrationPage> createState() => _PatientRegistrationPageState();
}

class _PatientRegistrationPageState extends State<PatientRegistrationPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  late String _patientId;
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _emergencyController = TextEditingController();

  bool _hipaaAccepted = false;
  bool _consentSigned = false;

  @override
  void initState() {
    super.initState();
    
    final randomIdNum = math.Random().nextInt(900) + 100;
    _patientId = 'PT-$randomIdNum';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _insuranceController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      return _step1Key.currentState?.validate() ?? false;
    } else if (_currentStep == 1) {
      return _step2Key.currentState?.validate() ?? false;
    } else {
      final isFormValid = _step3Key.currentState?.validate() ?? false;
      if (!isFormValid) return false;
      
      if (!_hipaaAccepted || !_consentSigned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Clinical compliance requires accepting HIPAA & Consent safeguards.'),
            backgroundColor: AppTheme.complianceDanger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return false;
      }
      return true;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _submitRegistration();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _submitRegistration() {
    final registration = PatientRegistrationModel(
      patientId: _patientId,
      name: _nameController.text.trim(),
      dob: _dobController.text.trim(),
      gender: _selectedGender,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      insuranceProvider: _insuranceController.text.trim(),
      emergencyContact: _emergencyController.text.trim(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.verified, color: AppTheme.complianceSecure, size: 28),
              SizedBox(width: 12),
              Text(
                'Record Verified',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New patient chart has passed automated HIPAA structural and validation checks. Encrypted storage volume mapped.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('PATIENT ID', _patientId, theme),
                    const Divider(height: 16),
                    _buildReceiptRow('FULL NAME', _nameController.text, theme),
                    const Divider(height: 16),
                    _buildReceiptRow('BLOOD GROUP', _selectedBloodGroup, theme),
                    const Divider(height: 16),
                    _buildReceiptRow('CLINICAL GENDER', _selectedGender, theme),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Edit Details'),
            ),
            FilledButton(
              onPressed: () async {
                
                await PatientRepository().registerPatient(registration);
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  Navigator.of(context).pop(registration);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85),
              ),
              child: const Text('Commit to Registry'),
            ),
          ],
        );
      },
    );
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2DD4BF)
                      : const Color(0xFF007E85),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Register New Patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            
            _buildCustomStepperHeader(primaryColor, isDark),
            const SizedBox(height: 16),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), 
                children: [
                  _buildStep1Page(theme, primaryColor, isDark),
                  _buildStep2Page(theme, primaryColor, isDark),
                  _buildStep3Page(theme, primaryColor, isDark),
                ],
              ),
            ),

            _buildBottomActionBar(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStepperHeader(Color primaryColor, bool isDark) {
    final steps = ['Personal', 'Contact', 'Insurance'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            
            final stepIdx = index ~/ 2;
            final isCompleted = _currentStep > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? AppTheme.complianceSecure : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            );
          } else {
            
            final stepIdx = index ~/ 2;
            final isActive = _currentStep == stepIdx;
            final isCompleted = _currentStep > stepIdx;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.complianceSecure
                        : isActive
                            ? primaryColor.withOpacity(0.12)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.complianceSecure
                          : isActive
                              ? primaryColor
                              : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${stepIdx + 1}',
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.white
                                  : isActive
                                      ? primaryColor
                                      : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[stepIdx],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? primaryColor
                        : isCompleted
                            ? AppTheme.complianceSecure
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildStep1Page(ThemeData theme, Color primaryColor, bool isDark) {
    final genderOptions = ['Male', 'Female', 'Non-Binary', 'Other'];
    final bloodGroupOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERSONAL DETAILS',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              initialValue: _patientId,
              enabled: false,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Registry Patient ID',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: const Icon(Icons.lock, size: 16),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Johnathan Smith',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Patient name is required';
                }
                if (value.trim().length < 3) {
                  return 'Enter a valid clinic patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => _selectDateOfBirth(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _dobController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Patient Date of Birth is required';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Clinical Gender',
                      prefixIcon: const Icon(Icons.transgender),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: genderOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: (String? newVal) {
                      if (newVal != null) {
                        setState(() {
                          _selectedGender = newVal;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: const Icon(Icons.bloodtype_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: bloodGroupOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: (String? newVal) {
                      if (newVal != null) {
                        setState(() {
                          _selectedBloodGroup = newVal;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Page(ThemeData theme, Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONTACT INFORMATION',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+1 (555) 019-2834',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Patient Phone Number is required';
                }
                if (value.trim().length < 8) {
                  return 'Enter a valid numerical phone connection';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              maxLines: 3,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Residential Street Address',
                hintText: '128 Clinical Parkway, Suite 4B\nSeattle, WA 98101',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Residential home address is required';
                }
                if (value.trim().length < 10) {
                  return 'Enter detailed street, city and zip details';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Page(ThemeData theme, Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CLINICAL INSURANCE & EMERGENCY CONTACT',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _insuranceController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Insurance Provider Name',
                hintText: 'Blue Cross Blue Shield / Cigna / Aetna',
                prefixIcon: const Icon(Icons.health_and_safety_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Insurance provider details are required (enter Self-Pay if none)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _emergencyController,
              keyboardType: TextInputType.name,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Emergency Contact Person & Phone',
                hintText: 'Sarah Smith (Spouse) - +1 (555) 018-9922',
                prefixIcon: const Icon(Icons.contact_phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Emergency Contact details are required for safeguards';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            const Divider(),
            const SizedBox(height: 16),

            Row(
              children: const [
                Icon(Icons.shield_outlined, color: AppTheme.complianceSecure, size: 16),
                SizedBox(width: 8),
                Text(
                  'HIPAA Safeguards Acknowledgment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            CheckboxListTile(
              value: _hipaaAccepted,
              activeColor: primaryColor,
              title: const Text(
                'I confirm this patient chart contains verified physical identities and maps clean biological metadata.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (bool? val) {
                setState(() {
                  _hipaaAccepted = val ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            CheckboxListTile(
              value: _consentSigned,
              activeColor: primaryColor,
              title: const Text(
                'I verify that HIPAA disclosure consent forms have been electronically signed and audited for record release.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (bool? val) {
                setState(() {
                  _consentSigned = val ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
          _currentStep > 0
              ? OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),

          FilledButton.icon(
            onPressed: _nextStep,
            icon: Icon(_currentStep == 2 ? Icons.check : Icons.arrow_forward),
            label: Text(_currentStep == 2 ? 'Verify & Register' : 'Next Step'),
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}