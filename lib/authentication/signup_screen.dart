import 'package:bladiway/methods/commun_methods.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Clé pour valider le formulaire
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de texte
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  final _passwordController = TextEditingController();
  CommunMethods cMethods = CommunMethods();

  // Variables d'état
  bool _isPasswordVisible = false; // Visibilité du mot de passe
  // ignore: unused_field
  String? _selectedGenre; // Genre sélectionné
  String? _phoneError; // Erreur pour le champ téléphone
  final List<String> _genres = ['Homme', 'Femme']; // Options de genre

  // Méthode pour vérifier la connectivité réseau
  checkIfTheNetworkIsAvailable(context)
  {
    cMethods.checkConnectivity(context);
  }

  // Méthode pour sélectionner une date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: Colors.green),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Validation du numéro de téléphone
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      setState(() {
        _phoneError = 'Veuillez entrer votre numéro';
      });
      return _phoneError;
    }
    setState(() {
      _phoneError = null;
    });
    return null;
  }

  // Soumission du formulaire
  void _submitForm() {
    if (_formKey.currentState!.validate() && _phoneError == null) {
      Navigator.pushReplacementNamed(context, '/otp');
    }
  }

  @override
  void dispose() {
    // Libérer les contrôleurs pour éviter les fuites de mémoire
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateNaissanceController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Créer un compte',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Champ Nom
                TextFormField(
                  controller: _nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Veuillez entrer votre nom' : null,
                ),
                const SizedBox(height: 16),

                // Champ Prénom
                TextFormField(
                  controller: _prenomController,
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Veuillez entrer votre prénom'
                              : null,
                ),
                const SizedBox(height: 16),

                // Champ Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Veuillez entrer votre email';
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    return emailRegex.hasMatch(value)
                        ? null
                        : 'Veuillez entrer un email valide';
                  },
                ),
                const SizedBox(height: 16),

                // Champ Numéro de téléphone
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntlPhoneField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: const OutlineInputBorder(),
                      ),
                      initialCountryCode: 'DZ',
                      onChanged: (phone) => _validatePhone(phone.number),
                    ),
                    if (_phoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          _phoneError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Champ Date de naissance
                TextFormField(
                  controller: _dateNaissanceController,
                  decoration: InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_month, color: primaryColor),
                      onPressed: _selectDate,
                    ),
                  ),
                  readOnly: true,
                  onTap: _selectDate,
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Veuillez sélectionner votre date de naissance'
                              : null,
                ),
                const SizedBox(height: 16),

                // Menu déroulant Genre
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Genre',
                    prefixIcon: Icon(Icons.people, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      _genres
                          .map(
                            (genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _selectedGenre = value),
                  validator:
                      (value) =>
                          value == null
                              ? 'Veuillez sélectionner votre genre'
                              : null,
                ),
                const SizedBox(height: 16),

                // Champ Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed:
                          () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Veuillez entrer un mot de passe';
                    }
                    return value.length < 8
                        ? 'Le mot de passe doit contenir au moins 8 caractères'
                        : null;
                  },
                ),
                const SizedBox(height: 24),

                // Bouton d'inscription
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    // Attendre la vérification de la connectivité
                    await checkIfTheNetworkIsAvailable(context);
                    // Appeler la soumission du formulaire si tout est valide
                    _submitForm();
                  }, 
                  child: const Text(
                    "S'inscrire",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: Text.rich(
                    TextSpan(
                      text: 'Vous avez déja un compte? ',
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: 'Connectez-vous',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
