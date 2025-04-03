import 'package:bladiway/methods/commun_methods.dart';
import 'package:bladiway/widgets/loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  final _passwordController = TextEditingController();
  CommunMethods cMethods = CommunMethods();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _fullPhoneNumber;
  bool _isPasswordVisible = false;
  String? _selectedGenre;
  String? _phoneError;
  String? _emailError;
  final List<String> _genres = ['Homme', 'Femme'];

  /// Vérifie la disponibilité du réseau (supposée implémentée dans CommunMethods)
  checkIfTheNetworkIsAvailable(context) {
    cMethods.checkConnectivity(context);
  }

  /// Vérifie si le numéro de téléphone est déjà utilisé dans la base de données
  Future<bool> _checkPhoneNumberAvailability(String phoneNumber) async {
    try {
      DataSnapshot snapshot =
          await _database
              .child('users')
              .orderByChild('phone')
              .equalTo(phoneNumber)
              .get();

      if (snapshot.exists) {
        setState(() {
          _phoneError = 'Ce numéro de téléphone est déjà utilisé';
        });
        return false;
      }
      return true;
    } on FirebaseException catch (e) {
      setState(() {
        if (e.code == 'permission-denied') {
          _phoneError = 'Permission refusée pour accéder à la base de données';
        } else {
          _phoneError = 'Erreur Firebase : ${e.message}';
        }
      });
      print('Erreur Firebase dans _checkPhoneNumberAvailability : $e');
      return false;
    } catch (e) {
      setState(() {
        _phoneError = 'Erreur inattendue : ${e.toString()}';
      });
      print('Erreur inattendue dans _checkPhoneNumberAvailability : $e');
      return false;
    }
  }

  /// Vérifie si l'email est déjà utilisé avec Firebase Auth.
  /// Met à jour l'état _emailError via setState et retourne true si l'email est disponible, false sinon.
  Future<bool> _checkEmailAvailability(String email) async {
    final String trimmedEmail = email.trim(); // Supprimer les espaces vides

    // 1. Validation initiale (format et non vide) - Optionnelle car Firebase valide aussi
    // Note: Cette vérification regex donne un retour immédiat pour les erreurs de format simples.
    if (trimmedEmail.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmedEmail)) {
      setState(() {
        // Si le validator du TextFormField gère déjà le format,
        // cette partie pourrait être redondante ou simplifiée.
        // Gardons-la pour l'instant pour correspondre à l'original.
        _emailError = 'Veuillez entrer un email valide';
      });
      print(
        "Validation échouée (format/vide): $trimmedEmail",
      ); // Log pour debug
      return false; // Format invalide ou email vide
    }

    // 2. Vérification auprès de Firebase
    try {
      print("Vérification Firebase pour: $trimmedEmail"); // Log pour debug
      final methods = await _auth.fetchSignInMethodsForEmail(trimmedEmail);

      // 3. Analyse du résultat
      if (methods.isNotEmpty) {
        // L'email est déjà associé à un compte
        print("Email déjà utilisé: $trimmedEmail"); // Log pour debug
        setState(() {
          _emailError = 'Cet email est déjà utilisé';
        });
        return false; // Email non disponible
      } else {
        // L'email est disponible
        print("Email disponible: $trimmedEmail"); // Log pour debug
        // On ne met à null ici que si on est sûr qu'aucune autre erreur
        // (comme le téléphone) n'est présente ou si l'UI le gère.
        // Il est peut-être préférable de le laisser à startSignUpProcess
        // ou de le gérer différemment. Pour l'instant, gardons la logique
        // d'effacer si l'email *spécifiquement* est OK.
        setState(() {
          _emailError = null;
        });
        return true; // Email disponible
      }
    } on FirebaseAuthException catch (e) {
      // 4. Gestion des erreurs spécifiques de Firebase Auth
      print(
        'Erreur FirebaseAuthException dans _checkEmailAvailability (${e.code}): ${e.message}',
      );
      setState(() {
        if (e.code == 'invalid-email') {
          _emailError = 'Le format de l\'email est invalide (selon Firebase)';
        } else if (e.code == 'too-many-requests') {
          _emailError = 'Trop de tentatives. Réessayez plus tard.';
        } else {
          _emailError = 'Erreur Firebase (Email): ${e.message ?? e.code}';
        }
      });
      return false; // Erreur Firebase
    } catch (e) {
      // 5. Gestion des autres erreurs inattendues
      print('Erreur inattendue dans _checkEmailAvailability : $e');
      setState(() {
        _emailError = 'Erreur inattendue (Email).';
      });
      return false; // Erreur inattendue
    }
  }

  /// Lance le processus d'inscription
  Future<void> startSignUpProcess() async {
    if (!_formKey.currentState!.validate() || _phoneError != null) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) =>
              LoadingDialog(messageText: 'Vérification en cours...'),
    );

    try {
      setState(() {
        _emailError = null;
        _phoneError = null;
      });

      final results = await Future.wait([
        _checkEmailAvailability(_emailController.text.trim()),
        _checkPhoneNumberAvailability(_fullPhoneNumber!),
      ]);

      bool isEmailAvailable = results[0];
      bool isPhoneAvailable = results[1];

      if (!isEmailAvailable || !isPhoneAvailable) {
        Navigator.pop(context);
        return;
      }

      if (_fullPhoneNumber != null && _fullPhoneNumber!.isNotEmpty) {
        await startPhoneVerification(_fullPhoneNumber!);
      } else {
        throw Exception('Numéro de téléphone requis');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      cMethods.displaySnackBar('Erreur inattendue : ${e.toString()}', context);
      print('Erreur dans startSignUpProcess : $e');
    }
  }

  /// Lance la vérification par OTP
  Future<void> startPhoneVerification(String phoneNumber) async {
    try {
      print('Début de la vérification téléphonique pour : $phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          print('Échec de la vérification : ${e.code} - ${e.message}');
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_getErrorMessage(e.code))));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code SMS envoyé, verificationId : $verificationId');
          if (mounted) {
            Navigator.pop(context);
            Navigator.pushNamed(
              context,
              '/otp',
              arguments: {
                'verificationId': verificationId,
                'phoneNumber': phoneNumber,
                'nom': _nomController.text.trim(),
                'prenom': _prenomController.text.trim(),
                'email': _emailController.text.trim(),
                'password': _passwordController.text.trim(),
                'dateNaissance': _dateNaissanceController.text.trim(),
                'genre': _selectedGenre,
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Timeout de récupération automatique : $verificationId');
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la vérification : ${e.toString()}'),
          ),
        );
      }
      print('Erreur dans startPhoneVerification : $e');
    }
  }

  /// Retourne un message d'erreur personnalisé basé sur le code d'erreur
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      default:
        return 'Une erreur est survenue : $code';
    }
  }

  /// Affiche le sélecteur de date
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

  @override
  void dispose() {
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
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: primaryColor),
                    border: const OutlineInputBorder(),
                    errorText: _emailError,
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
                  onChanged: (value) {
                    setState(() {
                      _emailError =
                          null; // Réinitialiser l'erreur au changement
                    });
                  },
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntlPhoneField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: const OutlineInputBorder(),
                        errorText: _phoneError,
                      ),
                      initialCountryCode: 'DZ',
                      onChanged: (phone) {
                        setState(() {
                          _fullPhoneNumber = phone.completeNumber;
                          if (!phone.isValidNumber()) {
                            _phoneError = 'Numéro de téléphone invalide';
                          } else {
                            _phoneError = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    await checkIfTheNetworkIsAvailable(context);
                    await startSignUpProcess();
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
                      text: 'Vous avez déjà un compte? ',
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
