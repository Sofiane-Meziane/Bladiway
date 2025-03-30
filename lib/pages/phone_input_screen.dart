import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

class ResetPasswordPhoneScreen extends StatefulWidget {
  final Function(String) onPhoneSubmit;

  const ResetPasswordPhoneScreen({super.key, required this.onPhoneSubmit});

  @override
  // ignore: library_private_types_in_public_api
  _ResetPasswordPhoneScreenState createState() =>
      _ResetPasswordPhoneScreenState();
}

class _ResetPasswordPhoneScreenState extends State<ResetPasswordPhoneScreen> {
  // Clé pour valider le formulaire
  final _formKey = GlobalKey<FormState>();

  // Contrôleur pour le champ téléphone
  final _phoneController = TextEditingController();

  // Variable pour stocker le numéro de téléphone courant
  PhoneNumber? _currentPhoneNumber;

  // Validation du numéro de téléphone
  String? _validatePhone(PhoneNumber? phone) {
    final numberToValidate = phone ?? _currentPhoneNumber;
    return (numberToValidate == null || numberToValidate.number.isEmpty)
        ? 'Veuillez entrer votre numéro'
        : null;
  }

  // Mise à jour du numéro de téléphone lors d'un changement
  void _onPhoneChanged(PhoneNumber phone) {
    setState(() {
      _currentPhoneNumber = phone;
    });
  }

  // Soumission du numéro de téléphone
  void _submitPhone() {
    if (_formKey.currentState!.validate() && _currentPhoneNumber != null) {
      widget.onPhoneSubmit(_currentPhoneNumber!.completeNumber);
    }
  }

  @override
  void dispose() {
    // Libérer le contrôleur pour éviter les fuites de mémoire
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
                // Titre
                Text(
                  'Changer de mot de passe',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 40),

                // Label du champ téléphone
                Text(
                  'Votre numéro de téléphone:',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),

                // Champ numéro de téléphone
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

                // Bouton de confirmation
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
