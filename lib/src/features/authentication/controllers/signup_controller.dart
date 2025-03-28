import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/phone_number.dart';

class SignUpController extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController dateNaissanceController = TextEditingController();

  // State variables
  bool isPasswordVisible = false;
  final List<String> genres = ['Homme', 'Femme'];

  // Validation methods
  String? validateNom(String? value) =>
      value?.isEmpty ?? true ? 'Veuillez entrer votre nom' : null;

  String? validatePrenom(String? value) =>
      value?.isEmpty ?? true ? 'Veuillez entrer votre prénom' : null;

  String? validateEmail(String? value) {
    if (value?.isEmpty ?? true) return 'Veuillez entrer votre email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(value!)
        ? null
        : 'Veuillez entrer un email valide';
  }

  String? validatePhone(PhoneNumber? value) =>
      value?.number.isEmpty ?? true ? 'Veuillez entrer votre numéro' : null;

  String? validateDateNaissance(String? value) =>
      value?.isEmpty ?? true
          ? 'Veuillez sélectionner votre date de naissance'
          : null;

  String? validateGenre(String? value) =>
      value == null ? 'Veuillez sélectionner votre genre' : null;

  String? validatePassword(String? value) {
    if (value?.isEmpty ?? true) return 'Veuillez entrer un mot de passe';
    return value!.length < 8
        ? 'Le mot de passe doit contenir au moins 8 caractères'
        : null;
  }

  // Date Picker
  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: Colors.green),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(picked);
      notifyListeners();
    }
  }

  // Password visibility
  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  // Form submission
  void submitForm(BuildContext context) {
    if (formKey.currentState?.validate() ?? false) {
      Navigator.pushReplacementNamed(context, '/otp');
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    dateNaissanceController.dispose();
    super.dispose();
  }
}
