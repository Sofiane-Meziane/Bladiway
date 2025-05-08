import 'package:bladiway/pages/car_add.dart';
import 'package:bladiway/pages/edit_car_page.dart';
import 'package:bladiway/pages/ajouter_trajet.dart';
import 'package:bladiway/pages/mes_trajet.dart';
import 'package:bladiway/pages/otp_screen.dart';
import 'package:bladiway/pages/presentation.dart';
import 'package:bladiway/pages/profile_screen.dart';
import 'package:bladiway/pages/reservation.dart';
import 'package:bladiway/pages/reservations_screen.dart';
import 'package:bladiway/pages/scanner_permis.dart';
import 'package:bladiway/pages/verification_conducteur.dart';
import 'package:bladiway/pages/verification_encour.dart';
import 'package:bladiway/pages/verification_passager.dart';
import 'package:bladiway/services/evaluation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'pages/home_page.dart';
import 'pages/settings_screen.dart';
import 'authentication/login_screen.dart';
import 'authentication/signup_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  // Activation de Firebase App Check avec mode Debug
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

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

// Widget wrapper qui vérifie les évaluations en attente
class EvaluationCheckWrapper extends StatefulWidget {
  final Widget child;

  const EvaluationCheckWrapper({super.key, required this.child});

  @override
  _EvaluationCheckWrapperState createState() => _EvaluationCheckWrapperState();
}

class _EvaluationCheckWrapperState extends State<EvaluationCheckWrapper> {
  final EvaluationService _evaluationService = EvaluationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingEvaluations();
    });
  }

  void _checkPendingEvaluations() {
    if (FirebaseAuth.instance.currentUser != null) {
      _evaluationService.checkPendingEvaluations(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Bladiway',
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2196F3),
          secondary: Color.fromARGB(255, 197, 209, 212),
          surface: Colors.white,
          error: Color(0xFFE53935),
          // Ajout de la couleur verte personnalisée
          onSecondary: Color(0xFF43A047),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2196F3),
          secondary: Colors.white,
          surface: Color(0xFF202020),
          error: Color(0xFFE53935),
          // Ajout de la couleur verte personnalisée
          onSecondary: Color(0xFF43A047),
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
            return EvaluationCheckWrapper(child: const HomePage());
          }

          return const PresentationPage();
        },
      ),
      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => EvaluationCheckWrapper(child: const HomePage()),
        '/settings':
            (context) => EvaluationCheckWrapper(child: const ParametresPage()),
        '/verifier_Passager':
            (context) => EvaluationCheckWrapper(
              child: const IdentityRequestPassengerPage(),
            ),
        '/profile':
            (context) => EvaluationCheckWrapper(child: const ProfileScreen()),
        '/presentation': (context) => const PresentationPage(),
        '/otp': (context) => const OTPScreen(),
        '/info_trajet':
            (context) => EvaluationCheckWrapper(child: const InfoTrajet()),
        '/add_car':
            (context) =>
                EvaluationCheckWrapper(child: const CarRegistrationScreen()),
        '/verifier_Conducteur':
            (context) =>
                EvaluationCheckWrapper(child: const PermissionAddCarPage()),
        '/verification_encours':
            (context) => EvaluationCheckWrapper(
              child: const VerificationPendingScreen(),
            ),
        '/scan_permission':
            (context) => EvaluationCheckWrapper(
              child: const IdentityVerificationScreen(),
            ),
        '/reservations':
            (context) =>
                EvaluationCheckWrapper(child: const ReservationsScreen()),
        '/trips':
            (context) => EvaluationCheckWrapper(child: const MesTrajetScreen()),
        '/reserver':
            (context) => EvaluationCheckWrapper(child: const ReservationPage()),
        '/edit_car': (context) {
          final voiture =
              ModalRoute.of(context)!.settings.arguments as DocumentSnapshot;
          return EvaluationCheckWrapper(child: EditCarPage(voiture: voiture));
        },
      },
    );
  }
}
