import 'package:bladiway/pages/car_add.dart';
import 'package:bladiway/pages/info_trajet.dart';
import 'package:bladiway/pages/otp_screen.dart';
import 'package:bladiway/pages/presentation.dart';
import 'package:bladiway/pages/scanner_permis.dart';
import 'package:bladiway/pages/verification_conducteur.dart';
import 'package:bladiway/pages/reservations_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'pages/home_page.dart';
import 'pages/settings_screen.dart';
import 'pages/profile_screen.dart';
import 'authentication/login_screen.dart';
import 'authentication/signup_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  final themeProvider = ThemeProvider();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
        Locale('fr', 'DZ'), // Utilisé comme fallback pour Tamazight (Kabyle)
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr', 'FR'),
      child: ChangeNotifierProvider.value(
        value: themeProvider,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF2196F3),
          secondary: const Color.fromARGB(255, 197, 209, 212),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2196F3),
          secondary: Colors.white,
          surface: Colors.grey[800]!,
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.hasData ? const HomePage() : const PresentationPage();
        },
      ),
      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const ParametresPage(),
        '/profile': (context) => const ProfileScreen(),
        '/presentation': (context) => const PresentationPage(),
        '/otp': (context) => const OTPScreen(),
        '/info_trajet': (context) => const InfoTrajet(),
        '/add_car': (context) => const CarRegistrationScreen(),
        '/verifier_Conducteur': (context) => const PermissionAddCarPage(),
        '/scan_permission': (context) => const LicenseVerificationScreen(),
        '/reservations': (context) => const ReservationsScreen(),
      },
    );
  }
}
