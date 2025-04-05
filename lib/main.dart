import 'package:bladiway/firebase_options.dart';
import 'package:bladiway/pages/home_page.dart';
import 'package:bladiway/pages/otp_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bladiway/authentication/login_screen.dart';
import 'package:bladiway/pages/presentation.dart';
import 'package:bladiway/authentication/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color.fromARGB(255, 12, 143, 251),
          secondary: const Color.fromARGB(255, 197, 209, 212),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color.fromARGB(255, 12, 143, 251),
          secondary: Colors.white,
          surface: Colors.grey[800]!,
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const PresentationPage(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OTPScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
