import 'package:flutter/material.dart';
import 'package:healthsecure/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:healthsecure/features/patients/presentation/pages/patients_page.dart';
import 'package:healthsecure/features/visits/presentation/pages/visits_page.dart';
import 'package:healthsecure/features/analytics/presentation/pages/analytics_page.dart';
import 'package:healthsecure/features/audit/presentation/pages/audit_page.dart';
import 'package:healthsecure/features/patients/presentation/pages/nurse_vitals_queue_page.dart';
import 'package:healthsecure/features/patients/presentation/pages/receptionist_registration_page.dart';
import 'package:healthsecure/core/services/cognito_auth_service.dart';
import 'package:healthsecure/core/services/demo_data_generator.dart';
import 'package:healthsecure/features/auth/presentation/pages/login_page.dart';

class NavigationItem {
  final Widget page;
  final NavigationDestination destination;

  NavigationItem({required this.page, required this.destination});
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  String _role = 'Guest';
  String _name = '';
  bool _isLoading = true;
  final List<NavigationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final role = await CognitoAuthService.instance.getUserRole();
    final email = await CognitoAuthService.instance.getUserEmail();
    
    String name = 'Staff Member';
    if (email != null) {
      final user = DemoDataGenerator.instance.mockUsers.firstWhere(
        (u) => u['email']!.toLowerCase() == email.toLowerCase(),
        orElse: () => {},
      );
      if (user.isNotEmpty) {
        name = user['name']!;
      }
    }

    if (mounted) {
      setState(() {
        _role = role;
        _name = name;
        _buildNavigationItems();
        _isLoading = false;
      });
    }
  }

  void _buildNavigationItems() {
    _items.clear();
    switch (_role) {
      case 'Admin':
        _items.addAll([
          NavigationItem(
            page: const DashboardPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          ),
          NavigationItem(
            page: const PatientsPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Patients',
            ),
          ),
          NavigationItem(
            page: const VisitsPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.checklist_rtl_outlined),
              selectedIcon: Icon(Icons.checklist_rtl),
              label: 'Visits',
            ),
          ),
          NavigationItem(
            page: const AnalyticsPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
          ),
          NavigationItem(
            page: const AuditPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Audit',
            ),
          ),
        ]);
        break;
      case 'Doctor':
        _items.addAll([
          NavigationItem(
            page: PatientsPage(doctorNameFilter: _name),
            destination: const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Patients',
            ),
          ),
          NavigationItem(
            page: VisitsPage(providerNameFilter: _name),
            destination: const NavigationDestination(
              icon: Icon(Icons.checklist_rtl_outlined),
              selectedIcon: Icon(Icons.checklist_rtl),
              label: 'Visits',
            ),
          ),
        ]);
        break;
      case 'Nurse':
        _items.add(
          NavigationItem(
            page: const NurseVitalsQueuePage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Vitals Queue',
            ),
          ),
        );
        break;
      case 'Analyst':
        _items.addAll([
          NavigationItem(
            page: const AnalyticsPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
          ),
          NavigationItem(
            page: const DashboardPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          ),
        ]);
        break;
      case 'Receptionist':
        _items.addAll([
          NavigationItem(
            page: const ReceptionistRegistrationPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.person_add_alt_1_outlined),
              selectedIcon: Icon(Icons.person_add_alt_1),
              label: 'Intake',
            ),
          ),
          NavigationItem(
            page: const PatientsPage(),
            destination: const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Registry',
            ),
          ),
        ]);
        break;
      default:
        _items.add(
          NavigationItem(
            page: const Center(child: Text('Unauthorized workspace.')),
            destination: const NavigationDestination(
              icon: Icon(Icons.lock),
              label: 'Access Denied',
            ),
          ),
        );
    }
  }

  Future<void> _handleLogout() async {
    await CognitoAuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        title: Row(
          children: [
            Text(
              'Session: $_name',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85)).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _role.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF007E85),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, size: 12),
            label: const Text('Sign Out', style: TextStyle(fontSize: 10)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _items.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: _items.length > 1
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: _items.map((item) => item.destination).toList(),
            )
          : null,
    );
  }
}