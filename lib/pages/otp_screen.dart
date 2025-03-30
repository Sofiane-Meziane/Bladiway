import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  // Liste des contrôleurs pour les 6 champs OTP
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // Liste des focus nodes pour gérer le focus entre les champs
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Gestion de la navigation entre les champs OTP
  void _onOTPChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        // Passe au champ suivant
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        // Dernier champ, retire le focus
        FocusScope.of(context).unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Retourne au champ précédent si vide
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  // Vérification de l'OTP
  void _verifyOTP() {
    String otp = _otpControllers.map((controller) => controller.text).join();
    if (otp.length == 6) {
      // TODO: Implémenter la logique de vérification OTP
      debugPrint('Verifying OTP: $otp');
      // Exemple: Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Afficher une erreur si l'OTP est incomplet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le code OTP complet'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Renvoyer le code OTP
  void _resendOTP() {
    // TODO: Implémenter la logique de renvoi OTP
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code OTP renvoyé'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  void dispose() {
    // Libérer les contrôleurs et focus nodes pour éviter les fuites de mémoire
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Titre
              Text(
                'Vérification OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Instructions
              Text(
                'Entrez le code de 6 chiffres envoyé à votre numéro de téléphone',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Champs OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 50,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            // ignore: deprecated_member_use
                            color: colorScheme.onSurface.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        errorBorder: UnderlineInputBorder(
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onOTPChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              // Bouton de vérification
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 3,
                ),
                onPressed: _verifyOTP,
                child: const Text(
                  'Vérifier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Bouton pour renvoyer le code
              TextButton(
                onPressed: _resendOTP,
                child: Text(
                  'Renvoyer le code',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
