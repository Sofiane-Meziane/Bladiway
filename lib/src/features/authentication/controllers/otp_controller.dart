import 'package:flutter/material.dart';

class OTPController extends ChangeNotifier {
  // Controllers et focus nodes pour les champs OTP
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  // BuildContext gardé en référence pour les opérations nécessitant le contexte
  BuildContext? _context;

  // Initialiser les focus nodes
  void initFocusNodes(BuildContext context) {
    _context = context;
  }

  // Gestion de la navigation entre les champs OTP
  void onOTPChanged(int index, String value) {
    if (_context == null) return;

    if (value.length == 1) {
      if (index < 5) {
        // Move focus to next input
        FocusScope.of(_context!).requestFocus(focusNodes[index + 1]);
      } else {
        // Last input, unfocus
        FocusScope.of(_context!).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Move back if empty
      FocusScope.of(_context!).requestFocus(focusNodes[index - 1]);
    }
  }

  // Vérification de l'OTP
  void verifyOTP() {
    if (_context == null) return;

    // Collecter l'OTP
    String otp = otpControllers.map((controller) => controller.text).join();

    if (otp.length == 6) {
      // TODO: Implement OTP verification logic
      debugPrint('Verifying OTP: $otp');
      // Exemple: Navigator.pushReplacementNamed(_context!, '/home');
    } else {
      // Afficher une erreur si l'OTP est incomplet
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le code OTP complet'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Renvoyer le code OTP
  void resendOTP() {
    if (_context == null) return;

    // TODO: Implement resend OTP logic
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: const Text('Code OTP renvoyé'),
        backgroundColor: Theme.of(_context!).colorScheme.primary,
      ),
    );
  }

  // Nettoyer les resources à la suppression du contrôleur
  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    _context = null;
    super.dispose();
  }
}
