import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:bladiway/pages/reset_pass_screen.dart';

class ResetPasswordPhoneScreen extends StatefulWidget {
  const ResetPasswordPhoneScreen({super.key});

  @override
  _ResetPasswordPhoneScreenState createState() =>
      _ResetPasswordPhoneScreenState();
}

class _ResetPasswordPhoneScreenState extends State<ResetPasswordPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  PhoneNumber? _currentPhoneNumber;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Validation du numéro de téléphone
  String? _validatePhone(PhoneNumber? phone) {
    final numberToValidate = phone ?? _currentPhoneNumber;
    return (numberToValidate == null || numberToValidate.number.isEmpty)
        ? 'Veuillez entrer votre numéro'
        : null;
  }

  // Mise à jour du numéro de téléphone lors d’un changement
  void _onPhoneChanged(PhoneNumber phone) {
    setState(() {
      _currentPhoneNumber = phone;
    });
  }

  // Vérifie si le numéro de téléphone existe dans Firestore
  Future<bool> _checkPhoneExists(String phoneNumber) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
              .limit(1)
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification du numéro : $e');
      return false;
    }
  }

  // Envoie un code de vérification via Firebase Authentication
  Future<void> _sendVerificationCode(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-résolution si possible (cas rare)
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Numéro de téléphone invalide';
              break;
            default:
              errorMessage = 'Erreur lors de l\'envoi du code : ${e.message}';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        },
        codeSent: (String verificationId, int? resendToken) {
          // Code envoyé avec succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code de vérification envoyé')),
          );
          // Redirection vers la page de réinitialisation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ResetPasswordVerificationScreen(
                    verificationId: verificationId,
                    onPasswordReset: (verificationCode, newPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Mot de passe réinitialisé avec succès',
                          ),
                        ),
                      );
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout pour la récupération automatique
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur inattendue : $e')));
    }
  }

  // Soumission du numéro de téléphone
  void _submitPhone() async {
    if (_formKey.currentState!.validate() && _currentPhoneNumber != null) {
      final phoneNumber = _currentPhoneNumber!.completeNumber;
      final phoneExists = await _checkPhoneExists(phoneNumber);
      if (phoneExists) {
        await _sendVerificationCode(phoneNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun utilisateur trouvé avec ce numéro'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changer de mot de passe',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Votre numéro de téléphone:',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  initialCountryCode: 'DZ',
                  onChanged: _onPhoneChanged,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirmer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
