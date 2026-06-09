import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'presentations_screen.dart';
import 'join_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // List ini berisi halaman-halaman yang akan dipanggil oleh Bottom Navigation
  final List<Widget> _screens = [
    const PresentationsScreen(), // Tab 1 sekarang sudah memanggil halaman aslinya
    const JoinScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEAEAF0), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          elevation: 0,
          height: 64,
          indicatorColor: const Color(0xFFEEEDFE),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.slideshow_outlined, color: Color(0xFF9CA3AF)),
              selectedIcon: Icon(
                Icons.slideshow_rounded,
                color: Color(0xFF4F46E5),
              ),
              label: 'Presentasi',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.qr_code_scanner_outlined,
                color: Color(0xFF9CA3AF),
              ),
              selectedIcon: Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF4F46E5),
              ),
              label: 'Join',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF9CA3AF),
              ),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: Color(0xFF4F46E5),
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
