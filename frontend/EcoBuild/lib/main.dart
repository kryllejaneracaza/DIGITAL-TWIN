import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/building_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/room_provider.dart';

import 'services/api_service.dart';

import 'services/building_service.dart';
import 'services/room_service.dart';
import 'services/sensor_service.dart';
import 'services/appliance_service.dart';

import 'screens/intro_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        Provider<ApiService>(create: (_) => ApiService()),

        Provider<BuildingService>(
          create: (context) =>
              BuildingService(apiService: context.read<ApiService>()),
        ),

        ChangeNotifierProvider<BuildingProvider>(
          create: (context) => BuildingProvider(
            buildingService: context.read<BuildingService>(),
          ),
        ),

        Provider<RoomService>(
          create: (context) =>
              RoomService(apiService: context.read<ApiService>()),
        ),
        ChangeNotifierProvider<RoomProvider>(
          create: (context) =>
              RoomProvider(roomService: context.read<RoomService>()),
        ),

        Provider<SensorService>(
          create: (context) =>
              SensorService(apiService: context.read<ApiService>()),
        ),

        ChangeNotifierProvider<SensorProvider>(
          create: (context) =>
              SensorProvider(sensorService: context.read<SensorService>()),
        ),

        Provider<ApplianceService>(
          create: (context) =>
              ApplianceService(apiService: context.read<ApiService>()),
        ),
      ],
      child: const EcoBuildApp(),
    ),
  );
}

class EcoBuildApp extends StatelessWidget {
  const EcoBuildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoBuild',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primaryColor: const Color(0xFF125838),
        scaffoldBackgroundColor: const Color(0xFFEAF8EF),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF125838)),
      ),

      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFFEAF8EF),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF125838)),
              ),
            );
          }

          if (auth.isAuthenticated) {
            return const MainNavigationScreen();
          }

          return const IntroScreen();
        },
      ),
    );
  }
}
