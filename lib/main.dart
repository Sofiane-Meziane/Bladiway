import 'package:bladiway/firebase_options.dart';
import 'package:bladiway/src/features/authentication/views/otp_screen.dart';
import 'package:bladiway/src/features/authentication/controllers/signup_controller.dart';
import 'package:bladiway/src/features/authentication/controllers/login_controller.dart';
import 'package:bladiway/src/features/authentication/controllers/presentation_controller.dart';
import 'package:bladiway/src/features/authentication/controllers/otp_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bladiway/src/features/authentication/views/login.dart';
import 'package:bladiway/src/features/authentication/views/presentation.dart';
import 'package:bladiway/src/features/authentication/views/signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SignUpController()),
        ChangeNotifierProvider(create: (_) => LoginController()),
        ChangeNotifierProvider(create: (_) => PresentationController()),
        ChangeNotifierProvider(create: (_) => OTPController()),
      ],
      
      child: const MyApp(),
    ),
  );
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
      },
    );
  }
}
