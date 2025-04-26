import 'dart:io';
import 'package:bladiway/methods/commun_methods.dart';
import 'package:bladiway/widgets/loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

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
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  String? _fullPhoneNumber;
  bool _isPasswordVisible = false;
  String? _selectedGenre;
  String? _phoneError;
  String? _emailError;
  final List<String> _genres = ['Homme'.tr(), 'Femme'.tr()];

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _imageError;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageError = null;
        });
      }
    } catch (e) {
      setState(() {
        _imageError = 'Erreur lors de la sélection de l\'image'.tr();
      });
      print('Erreur lors de la sélection de l\'image: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choisir une image de profil'.tr()),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Prendre une photo'.tr()),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Choisir depuis la galerie'.tr()),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  checkIfTheNetworkIsAvailable(context) {
    cMethods.checkConnectivity(context);
  }

  Future<bool> _checkPhoneNumberAvailability(String phoneNumber) async {
    try {
      final querySnapshot =
          await _usersCollection.where('phone', isEqualTo: phoneNumber).get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _phoneError = 'Ce numéro de téléphone est déjà utilisé'.tr();
        });
        return false;
      }
      return true;
    } on FirebaseException catch (e) {
      setState(() {
        if (e.code == 'permission-denied') {
          _phoneError =
              'Permission refusée pour accéder à la base de données'.tr();
        } else {
          _phoneError = 'Erreur Firebase : ${e.message}'.tr();
        }
      });
      print('Erreur Firebase dans _checkPhoneNumberAvailability : $e');
      return false;
    } catch (e) {
      setState(() {
        _phoneError = 'Erreur inattendue : ${e.toString()}'.tr();
      });
      print('Erreur inattendue dans _checkPhoneNumberAvailability : $e');
      return false;
    }
  }

  Future<bool> _checkEmailAvailability(String email) async {
    final String trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmedEmail)) {
      setState(() {
        _emailError = 'Veuillez entrer un email valide'.tr();
      });
      print("Validation échouée (format/vide): $trimmedEmail");
      return false;
    }

    try {
      print("Vérification Firebase pour: $trimmedEmail");
      final methods = await _auth.fetchSignInMethodsForEmail(trimmedEmail);

      if (methods.isNotEmpty) {
        print("Email déjà utilisé: $trimmedEmail");
        setState(() {
          _emailError = 'Cet email est déjà utilisé'.tr();
        });
        return false;
      } else {
        print("Email disponible: $trimmedEmail");
        setState(() {
          _emailError = null;
        });
        return true;
      }
    } on FirebaseAuthException catch (e) {
      print(
        'Erreur FirebaseAuthException dans _checkEmailAvailability (${e.code}): ${e.message}',
      );
      setState(() {
        if (e.code == 'invalid-email') {
          _emailError =
              'Le format de l\'email est invalide (selon Firebase)'.tr();
        } else if (e.code == 'too-many-requests') {
          _emailError = 'Trop de tentatives. Réessayez plus tard.'.tr();
        } else {
          _emailError = 'Erreur Firebase (Email): ${e.message ?? e.code}'.tr();
        }
      });
      return false;
    } catch (e) {
      print('Erreur inattendue dans _checkEmailAvailability : $e');
      setState(() {
        _emailError = 'Erreur inattendue (Email).'.tr();
      });
      return false;
    }
  }

  Future<void> startSignUpProcess() async {
    if (_imageFile == null) {
      setState(() {
        _imageError = 'Veuillez sélectionner une image de profil'.tr();
      });
      return;
    }

    if (!_formKey.currentState!.validate() ||
        _phoneError != null ||
        _imageError != null) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) =>
              LoadingDialog(messageText: 'Vérification en cours...'.tr()),
    );

    try {
      setState(() {
        _emailError = null;
        _phoneError = null;
        _imageError = null;
      });

      print('Début de la vérification des disponibilités...');
      final results = await Future.wait([
        _checkEmailAvailability(_emailController.text.trim()),
        _checkPhoneNumberAvailability(_fullPhoneNumber!),
      ]);

      bool isEmailAvailable = results[0];
      bool isPhoneAvailable = results[1];

      print('Email disponible: $isEmailAvailable');
      print('Numéro disponible: $isPhoneAvailable');

      if (!isEmailAvailable || !isPhoneAvailable) {
        Navigator.pop(context);
        return;
      }

      if (_fullPhoneNumber != null && _fullPhoneNumber!.isNotEmpty) {
        print('Lancement de la vérification OTP...');
        await startPhoneVerification(_fullPhoneNumber!);
      } else {
        throw Exception('Numéro de téléphone requis'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      cMethods.displaySnackBar(
        'Erreur inattendue : ${e.toString()}'.tr(),
        context,
      );
      print('Erreur dans startSignUpProcess : $e');
    }
  }

  Future<void> startPhoneVerification(String phoneNumber) async {
    try {
      print('Début de la vérification téléphonique pour : $phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Vérification automatique réussie');
        },
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
          print('Code SMS envoyé avec verificationId : $verificationId');
          if (mounted) {
            Navigator.pop(context);
            print('Navigation vers OTPScreen...');
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
                'imagePath': _imageFile?.path, // Correction ici
              },
            );
          } else {
            print('Widget non monté, navigation annulée');
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
            content: Text(
              'Erreur lors de la vérification : ${e.toString()}'.tr(),
            ),
          ),
        );
      }
      print('Erreur dans startPhoneVerification : $e');
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide'.tr();
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard'.tr();
      default:
        return 'Une erreur est survenue : $code'.tr();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'), // Ajout de la locale française
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
        _dateNaissanceController.text = DateFormat(
          'dd/MM/yyyy',
          'fr_FR',
        ).format(picked); // Locale ajoutée
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
          'Créer un compte'.tr(),
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
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              child:
                                  _imageFile != null
                                      ? ClipOval(
                                        child: Image.file(
                                          _imageFile!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[600],
                                      ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_imageError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _imageError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Text(
                          "Photo de profil".tr(),
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom'.tr(),
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Veuillez entrer votre nom'.tr()
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _prenomController,
                  decoration: InputDecoration(
                    labelText: 'Prénom'.tr(),
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Veuillez entrer votre prénom'.tr()
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email'.tr(),
                    prefixIcon: Icon(Icons.email, color: primaryColor),
                    border: const OutlineInputBorder(),
                    errorText: _emailError,
                  ),
                  validator: (value) {
                    if (value!.isEmpty)
                      return 'Veuillez entrer votre email'.tr();
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    return emailRegex.hasMatch(value)
                        ? null
                        : 'Veuillez entrer un email valide'.tr();
                  },
                  onChanged: (value) {
                    setState(() {
                      _emailError = null;
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
                        labelText: 'Numéro de téléphone'.tr(),
                        border: const OutlineInputBorder(),
                        errorText: _phoneError,
                      ),
                      initialCountryCode: 'DZ',
                      onChanged: (phone) {
                        setState(() {
                          _fullPhoneNumber = phone.completeNumber;
                          if (!phone.isValidNumber()) {
                            _phoneError = 'Numéro de téléphone invalide'.tr();
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
                    labelText: 'Date de naissance'.tr(),
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
                                  .tr()
                              : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Genre'.tr(),
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
                              ? 'Veuillez sélectionner votre genre'.tr()
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe'.tr(),
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
                      return 'Veuillez entrer un mot de passe'.tr();
                    }
                    return value.length < 8
                        ? 'Le mot de passe doit contenir au moins 8 caractères'
                            .tr()
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
                  child: Text(
                    "S'inscrire".tr(),
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: Text.rich(
                    TextSpan(
                      text: 'Vous avez déjà un compte? '.tr(),
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: 'Connectez-vous'.tr(),
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
