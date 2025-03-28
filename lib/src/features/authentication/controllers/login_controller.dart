import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginController extends ChangeNotifier {
  // Form and Controllers
  final formKey = GlobalKey<FormState>();
  final TextEditingController loginIdentifierController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Focus Nodes
  final FocusNode loginIdentifierFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  // State
  bool obscurePassword = true;

  LoginController() {
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    loginIdentifierFocus.addListener(() {
      if (loginIdentifierFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });

    passwordFocus.addListener(() {
      if (passwordFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  // Validation
  String? validateLoginIdentifier(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre identifiant';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(
      r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
    );
    return (emailRegex.hasMatch(value) || phoneRegex.hasMatch(value))
        ? null
        : 'Identifiant invalide';
  }

  String? validatePassword(String? value) {
    return (value == null || value.isEmpty)
        ? 'Veuillez entrer votre mot de passe'
        : null;
  }

  // Actions
  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void submitForm(BuildContext context) {
    if (formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connexion en cours...')));
    }
  }

  @override
  void dispose() {
    loginIdentifierController.dispose();
    passwordController.dispose();
    loginIdentifierFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }
}
