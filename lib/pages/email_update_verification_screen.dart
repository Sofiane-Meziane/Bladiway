import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailUpdateVerificationScreen extends StatefulWidget {
  final String newEmail;
  final Function(String) onEmailUpdated;

  const EmailUpdateVerificationScreen({
    super.key,
    required this.newEmail,
    required this.onEmailUpdated,
  });

  @override
  State<EmailUpdateVerificationScreen> createState() =>
      _EmailUpdateVerificationScreenState();
}

class _EmailUpdateVerificationScreenState
    extends State<EmailUpdateVerificationScreen> {
  bool _isLoading = false;


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification de l\'e-mail'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                'Un e-mail de vérification a été envoyé à :\n${widget.newEmail}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text(
                'Veuillez cliquer sur le lien de vérification dans votre boîte mail.\nPour finaliser la modification, veuillez vous reconnecter avec votre nouvel e-mail.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            setState(() => _isLoading = true);
                            try {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/presentation',
                                  (Route<dynamic> route) => false,
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e')),
                              );
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
