import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'buildings_screen.dart';
import 'rooms_screen.dart';
import 'sensors_screen.dart';
import 'appliances_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const Color primaryGreen = Color(0xFF125838);
  static const Color lightGreen = Color(0xFFD9EFE1);

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BuildingsScreen(),
    RoomsScreen(),
    SensorsScreen(),
    AppliancesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EF),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: lightGreen,
          height: 70,
          elevation: 8,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final selected = states.contains(WidgetState.selected);

            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? primaryGreen : Colors.grey.shade600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            final selected = states.contains(WidgetState.selected);

            return IconThemeData(
              size: 23,
              color: selected ? primaryGreen : Colors.grey.shade600,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_outlined),
              selectedIcon: Icon(Icons.business_rounded),
              label: 'Buildings',
            ),
            NavigationDestination(
              icon: Icon(Icons.meeting_room_outlined),
              selectedIcon: Icon(Icons.meeting_room_rounded),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors_rounded),
              label: 'Sensors',
            ),
            NavigationDestination(
              icon: Icon(Icons.electrical_services_outlined),
              selectedIcon: Icon(Icons.electrical_services_rounded),
              label: 'Appliances',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
