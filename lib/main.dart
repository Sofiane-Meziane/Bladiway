import 'package:bladiway/pages/info_trajet.dart';
import 'package:bladiway/pages/otp_screen.dart';
import 'package:bladiway/pages/presentation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/settings_screen.dart';
import 'pages/profile_screen.dart';
import 'authentication/login_screen.dart';
import 'authentication/signup_screen.dart';
import 'providers/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialiser le ThemeProvider
  final themeProvider = ThemeProvider();
  // Pas besoin d'appeler _loadThemeFromPrefs() explicitement
  // car il est déjà appelé dans le constructeur

  runApp(
    ChangeNotifierProvider.value(value: themeProvider, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de thème
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        // Ajoutez d'autres locales si nécessaire, comme Locale('en', 'US')
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: Color(0xFF2196F3),
          secondary: const Color.fromARGB(255, 197, 209, 212),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF2196F3),
          secondary: Colors.white,
          surface: Colors.grey[800]!,
        ),
      ),
      themeMode:
          themeProvider.themeMode, // Utiliser le mode de thème du provider
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
      },
    );
  }
}
