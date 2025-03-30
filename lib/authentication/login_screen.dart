import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bladiway/pages/email_input_screen.dart'; 
import 'package:bladiway/pages/phone_input_screen.dart'; 
import 'package:bladiway/pages/reset_pass_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Clé pour valider le formulaire
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de texte
  final _loginIdentifierController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus nodes pour gérer le focus entre les champs
  final _loginIdentifierFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // État pour la visibilité du mot de passe
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  // Configurer les listeners pour afficher le clavier
  void _setupFocusListeners() {
    _loginIdentifierFocus.addListener(() {
      if (_loginIdentifierFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  // Validation de l'identifiant (email ou téléphone)
  String? _validateLoginIdentifier(String? value) {
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

  // Validation du mot de passe
  String? _validatePassword(String? value) {
    return (value == null || value.isEmpty)
        ? 'Veuillez entrer votre mot de passe'
        : null;
  }

  // Basculer la visibilité du mot de passe
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // Soumettre le formulaire
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connexion en cours...')));
      // TODO: Implémenter la logique de connexion ici
    }
  }

  // Afficher les options de réinitialisation du mot de passe
  void _showPasswordResetOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPasswordResetOptions(),
    );
  }

  // Construire le modal des options de réinitialisation
  Widget _buildPasswordResetOptions() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choisis une méthode !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionne l’une des options ci-dessous pour réinitialiser ton mot de passe.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _buildOptionTile(
            icon: Icons.email,
            title: 'E-Mail',
            subtitle: 'Réinitialisation par e-mail',
            onTap: () {
              Navigator.pop(context);
              _resetViaEmail();
            },
          ),
          const SizedBox(height: 16),
          _buildOptionTile(
            icon: Icons.phone_android,
            title: 'Numéro de téléphone',
            subtitle: 'Réinitialisation par téléphone',
            onTap: () {
              Navigator.pop(context);
              _resetViaPhone();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Construire une tuile d'option pour le modal
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Réinitialisation via email
  void _resetViaEmail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResetPasswordEmailScreen(
              onEmailSubmit: (email) {
                // TODO: Envoyer le code de vérification à l'email
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ResetPasswordVerificationScreen(
                          onPasswordReset: (verificationCode, newPassword) {
                            // TODO: Vérifier le code et mettre à jour le mot de passe
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mot de passe mis à jour avec succès',
                                ),
                              ),
                            );
                            Navigator.popUntil(
                              context,
                              ModalRoute.withName('/login'),
                            );
                          },
                        ),
                  ),
                );
              },
            ),
      ),
    );
  }

  // Réinitialisation via téléphone
  void _resetViaPhone() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResetPasswordPhoneScreen(
              onPhoneSubmit: (phone) {
                if (phone.isNotEmpty) {
                  // TODO: Envoyer le code de vérification au numéro
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ResetPasswordVerificationScreen(
                            onPasswordReset: (verificationCode, newPassword) {
                              // TODO: Vérifier le code et mettre à jour le mot de passe
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mot de passe mis à jour avec succès',
                                  ),
                                ),
                              );
                              Navigator.popUntil(
                                context,
                                ModalRoute.withName('/login'),
                              );
                            },
                          ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Numéro de téléphone invalide'),
                    ),
                  );
                }
              },
            ),
      ),
    );
  }

  @override
  void dispose() {
    // Libérer les ressources pour éviter les fuites de mémoire
    _loginIdentifierController.dispose();
    _passwordController.dispose();
    _loginIdentifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(color: primaryColor),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Titre
                    Text(
                      "Connexion",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Logo ou icône par défaut
                    Image.asset(
                      'assets/logo.png',
                      height: 120,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            Icons.account_circle,
                            size: 120,
                            color: primaryColor,
                          ),
                    ),
                    const SizedBox(height: 40),
                    // Champ identifiant
                    TextFormField(
                      controller: _loginIdentifierController,
                      focusNode: _loginIdentifierFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email ou numéro de téléphone',
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        border: const OutlineInputBorder(),
                        hintText: 'exemple@email.com ou +33612345678',
                      ),
                      validator: _validateLoginIdentifier,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    // Champ mot de passe
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock, color: primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: primaryColor,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                    ),
                    // Bouton mot de passe oublié
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showPasswordResetOptions,
                        child: Text(
                          'Mot de passe oublié?',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Bouton de connexion
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _submitForm,
                      child: const Text(
                        "Se connecter",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    
                    // Lien vers inscription
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: Text.rich(
                        TextSpan(
                          text: 'Vous n\'avez pas de compte? ',
                          style: const TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: 'S\'inscrire',
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
        ),
      ),
    );
  }
}
