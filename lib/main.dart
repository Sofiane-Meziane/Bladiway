import 'package:bladiway/pages/car_add.dart';
import 'package:bladiway/pages/info_trajet.dart';
import 'package:bladiway/pages/otp_screen.dart';
import 'package:bladiway/pages/presentation.dart';
import 'package:bladiway/pages/scanner_permis.dart';
import 'package:bladiway/pages/verification_conducteur.dart';
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
import 'pages/centre_aide_page.dart';

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
      path: 'assets/translations', // Chemin vers les fichiers JSON
      fallbackLocale: Locale('fr'),
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
      title: 'BladiWay',
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2196F3),
          secondary: Color.fromARGB(255, 197, 209, 212),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2196F3),
          secondary: Colors.white,
          surface: Colors.grey,
        ),
      ),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const PresentationPage();
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
        '/centre-aide': (context) => const CentreAidePage(),
          '/scanner_permis': (context) => const LicenseVerificationScreen (),

      },
    );
  }
}
