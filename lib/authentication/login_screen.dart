import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bladiway/pages/email_input_screen.dart';
import 'package:bladiway/pages/phone_input_screen.dart';
import 'package:bladiway/pages/reset_pass_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginIdentifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginIdentifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

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

  String? _validatePassword(String? value) {
    return (value == null || value.isEmpty)
        ? 'Veuillez entrer votre mot de passe'
        : null;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<String?> _getEmailFromPhone(String phoneNumber) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
              .limit(1)
              .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['email'];
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de l\'email : $e');
      return null;
    }
  }

  Future<void> _signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Aucun utilisateur trouvé avec cet email';
          break;
        case 'wrong-password':
          errorMessage = 'Mot de passe incorrect';
          break;
        case 'invalid-email':
          errorMessage = 'Email invalide';
          break;
        default:
          errorMessage = 'Erreur de connexion : ${e.message}';
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      String identifier = _loginIdentifierController.text.trim();
      String password = _passwordController.text.trim();

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      final phoneRegex = RegExp(
        r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
      );

      if (emailRegex.hasMatch(identifier)) {
        await _signInWithEmail(identifier, password);
      } else if (phoneRegex.hasMatch(identifier)) {
        String? email = await _getEmailFromPhone(identifier);
        if (email != null) {
          await _signInWithEmail(email, password);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun utilisateur trouvé avec ce numéro'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Identifiant invalide')));
      }
    }
  }

  void _showPasswordResetOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPasswordResetOptions(),
    );
  }

  Widget _buildPasswordResetOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
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
              Text(
                'Choisis une méthode !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionne l’une des options ci-dessous pour réinitialiser ton mot de passe.',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
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
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetViaEmail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResetPasswordEmailScreen(onEmailSubmit: (email) {}),
      ),
    );
  }

  void _resetViaPhone() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResetPasswordPhoneScreen()),
    );
  }

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _passwordController.dispose();
    _loginIdentifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.primary,
          ),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primary,
            ),
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
                    Text(
                      "Connexion",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _loginIdentifierController,
                      focusNode: _loginIdentifierFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email ou numéro de téléphone',
                        prefixIcon: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'exemple@email.com ou +33612345678',
                      ),
                      validator: _validateLoginIdentifier,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(
                          Icons.lock,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showPasswordResetOptions,
                        child: Text(
                          'Mot de passe oublié?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _submitForm,
                      child: Text(
                        "Se connecter",
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: Text.rich(
                        TextSpan(
                          text: 'Vous n\'avez pas de compte? ',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          children: [
                            TextSpan(
                              text: 'S\'inscrire',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
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
