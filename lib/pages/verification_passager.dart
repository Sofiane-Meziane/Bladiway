import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'scanner_permis.dart'; // Page de soumission de pièce
import 'verification_encour.dart'; // Page en attente de validation

class IdentityRequestPassengerPage extends StatefulWidget {
  const IdentityRequestPassengerPage({super.key});

  @override
  State<IdentityRequestPassengerPage> createState() =>
      _IdentityRequestPassengerPageState();
}

class _IdentityRequestPassengerPageState
    extends State<IdentityRequestPassengerPage> {
  bool _isLoading = false;

  Future<void> checkAndShowIdentityScreen(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar(
          'Vous devez être connecté pour accéder à cette fonctionnalité',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer toutes les pièces d'identité de l'utilisateur et les trier par date de soumission
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .orderBy(
                'date_soumission',
                descending: true,
              ) // Tri par date décroissante pour avoir la plus récente
              .limit(1) // Limite à 1 résultat (la plus récente)
              .get();

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final String statutDoc = doc['statut'] as String;

        // Afficher la date de soumission pour debug si nécessaire
        // final Timestamp dateSubmitted = doc['date_soumission'] as Timestamp;
        // print("Date de soumission: ${dateSubmitted.toDate()}");

        if (statutDoc == 'verifie' || statutDoc == 'en cours') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VerificationPendingScreen(),
            ),
          );
        } else if (statutDoc == 'refuse') {
          _showRejectedDialog();
        } else {
          _navigateToScanner();
        }
      } else {
        _navigateToScanner();
      }
    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
      _showErrorSnackBar(
        'Une erreur est survenue. Veuillez réessayer plus tard.',
      );
    }
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IdentityVerificationScreen(),
      ),
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Pièce refusée',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Votre pièce a été refusée. Veuillez la soumettre à nouveau avec une image claire.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToScanner();
                },
                child: const Text('Soumettre à nouveau'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Bouton de retour
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Contenu principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Bladiway",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: size.height * 0.25,
                          child: Image.asset(
                            'assets/images/identityVerification.png',
                            fit: BoxFit.contain,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  size: 100,
                                  color: theme.colorScheme.onSurface,
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Vérifiez votre identité",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            "Pour accéder à toutes les fonctionnalités de Bladiway en tant que passager, veuillez vérifier votre identité.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _ActionButton(
                    label: "Scanner ma pièce",
                    onPressed: () => checkAndShowIdentityScreen(context),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/reserver'),
                    child: Text(
                      "Skip et continuer",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// Reuse ActionButton
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
