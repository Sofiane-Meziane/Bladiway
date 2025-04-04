import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordVerificationScreen extends StatefulWidget {
  final String verificationId;
  final Function(String, String) onPasswordReset;

  const ResetPasswordVerificationScreen({
    super.key,
    required this.verificationId,
    required this.onPasswordReset,
  });

  @override
  State<ResetPasswordVerificationScreen> createState() =>
      _ResetPasswordVerificationScreenState();
}

class _ResetPasswordVerificationScreenState
    extends State<ResetPasswordVerificationScreen> {
  final TextEditingController verificationCodeController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Vérifie le code de vérification et réinitialise le mot de passe
  Future<void> _verifyCodeAndResetPassword() async {
    if (_formKey.currentState!.validate()) {
      final verificationCode = verificationCodeController.text.trim();
      final newPassword = passwordController.text.trim();

      try {
        // Créer le credential avec le code de vérification
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: verificationCode,
        );

        // Signer avec le credential
        UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        // Mettre à jour le mot de passe
        await userCredential.user!.updatePassword(newPassword);

        // Appeler la fonction de callback pour redirection et message
        widget.onPasswordReset(verificationCode, newPassword);
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage = 'Code de vérification invalide';
            break;
          case 'session-expired':
            errorMessage = 'La session a expiré. Veuillez réessayer.';
            break;
          default:
            errorMessage = 'Erreur : ${e.message}';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur inattendue : $e')));
      }
    }
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
                  'Code de vérification:',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: verificationCodeController,
                  hintText: 'Code de vérification',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer le code de vérification';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Nouveau mot de passe:',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: passwordController,
                  hintText: 'Mot de passe',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un nouveau mot de passe';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirmer le mot de passe:',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  context,
                  controller: confirmPasswordController,
                  hintText: 'Confirmer le mot de passe',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer le mot de passe';
                    }
                    if (value != passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _verifyCodeAndResetPassword,
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

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
    );
  }

  @override
  void dispose() {
    verificationCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
