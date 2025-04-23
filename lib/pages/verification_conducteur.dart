import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Pour le formatage de date

// Importations de nos écrans personnalisés
import 'scanner_permis.dart'; // Notre écran modifié précédemment
import 'verification_encour.dart'; // Notre nouvel écran d'attente

// Modèle de données pour cette nouvelle page
class PermissionPage {
  final String title;
  final String description;
  final String imagePath;

  const PermissionPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// Écran principal pour la page de scan du permis et ajout de voiture
class PermissionAddCarPage extends StatefulWidget {
  const PermissionAddCarPage({super.key});

  @override
  State<PermissionAddCarPage> createState() => _PermissionAddCarPageState();
}

class _PermissionAddCarPageState extends State<PermissionAddCarPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Liste des pages à afficher (ici, une seule page pour cette tâche spécifique)
  final List<PermissionPage> _pages = const [
    PermissionPage(
      title: 'Complétez votre profil pour publier un trajet',
      description:
          'Pour publier un trajet, vous devez scanner votre permis de conduire valide et ajouter au moins une voiture.',
      imagePath: 'assets/images/licenceVerification.jpg', // Mettez ici l'image appropriée
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  // Navigue vers une page spécifique
  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Vérification des documents d'identité pour rediriger vers le bon écran
  Future<void> checkAndShowLicenseScreen(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Vous devez être connecté pour accéder à cette fonctionnalité');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Récupérer tous les documents de type permis pour cet utilisateur
      final docsSnapshot = await FirebaseFirestore.instance
          .collection('piece_identite')
          .where('id_proprietaire', isEqualTo: user.uid)
          .where('type_piece', isEqualTo: 'permis')
          .orderBy('date_soumission', descending: true) // Tri par date de soumission décroissante
          .limit(1) // On ne récupère que le plus récent
          .get();

      setState(() {
        _isLoading = false;
      });

      if (docsSnapshot.docs.isNotEmpty) {
        final doc = docsSnapshot.docs.first;
        final String statutDoc = doc['statut'] as String;
        
        // Vérification de l'expiration du permis
        if (doc.data().containsKey('date_expiration')) {
          final String expirationDateStr = doc['date_expiration'] as String;
          final DateTime expirationDate = DateFormat('yyyy-MM-dd').parse(expirationDateStr);
          final DateTime today = DateTime.now();
          
          if (expirationDate.isBefore(today)) {
            // Le permis est expiré
            if (!mounted) return;
            _showPermisExpiredDialog();
            return;
          }
        }

        if (!mounted) return;

        if (statutDoc == 'verifie') {
          // Permis vérifié et non expiré, l'utilisateur peut continuer
          Navigator.pushNamed(context, '/add_car');
        } else if (statutDoc == 'en cours') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPendingScreen(
                documentType: 'permis',
              ),
            ),
          );
        } else if (statutDoc == 'refuse') {
          _showPermisRejectedDialog();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IdentityVerificationScreen(
                forcedIdType: 'permis',
              ),
            ),
          );
        }
      } else {
        // Aucun permis soumis, on redirige vers la page de soumission
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const IdentityVerificationScreen(
              forcedIdType: 'permis',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification des documents: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Une erreur est survenue. Veuillez réessayer plus tard.');
    }
  }

  // Vérification et navigation vers la page appropriée pour les voitures
  Future<void> checkAndShowCarScreen(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Vous devez être connecté pour accéder à cette fonctionnalité');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Vérifier si l'utilisateur a déjà au moins une voiture
      final carsSnapshot = await FirebaseFirestore.instance
          .collection('voitures')
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      // Rediriger vers la page appropriée en fonction du nombre de voitures
      if (carsSnapshot.docs.isNotEmpty) {
        // L'utilisateur a au moins une voiture, afficher la liste des voitures
        Navigator.pushNamed(context, '/mes_voitures');
      } else {
        // L'utilisateur n'a pas encore de voiture, afficher la page d'ajout
        Navigator.pushNamed(context, '/add_car');
      }
    } catch (e) {
      print('Erreur lors de la vérification des voitures: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Une erreur est survenue. Veuillez réessayer plus tard.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPermisRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Permis de conduire requis',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Vous avez déjà soumis une pièce d\'identité, mais pour publier un trajet vous devez spécifiquement soumettre votre permis de conduire.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Naviguer vers le formulaire avec permis présélectionné
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IdentityVerificationScreen(
                      forcedIdType: 'permis',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Soumettre mon permis'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  void _showPermisRejectedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Permis de conduire refusé',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Votre permis de conduire a été refusé. Veuillez le soumettre à nouveau avec une image plus claire et lisible.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Naviguer vers le formulaire avec permis présélectionné
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IdentityVerificationScreen(
                      forcedIdType: 'permis',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Soumettre à nouveau'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  // Dialogue pour les permis expirés
  void _showPermisExpiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Permis de conduire expiré',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Votre permis de conduire a expiré. Pour publier un trajet, vous devez soumettre un permis valide.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Naviguer vers le formulaire avec permis présélectionné
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IdentityVerificationScreen(
                      forcedIdType: 'permis',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Soumettre un permis valide'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Titre de la page
                  Text(
                    "Bladiway",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Vue paginée (mais ici il y a une seule page)
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) =>
                          _buildPageContent(_pages[index], size),
                    ),
                  ),
                  
                  // Boutons d'action
                  const SizedBox(height: 30),
                  _ActionButton(
                    label: "Scanner le permis",
                    onPressed: () => checkAndShowLicenseScreen(context),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: "Ajouter une voiture",
                    onPressed: () => checkAndShowCarScreen(context),
                    isSecondary: true,
                  ),
                  const SizedBox(height: 12),
                  // Bouton Skip
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/info_trajet'),
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
            // Indicateur de chargement
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Construction du contenu d'une page
  Widget _buildPageContent(PermissionPage page, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: size.height * 0.25,
          child: Image.asset(
            page.imagePath,
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) => Icon(
                  Icons.broken_image_outlined,
                  size: 100,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          page.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center, // Centrer le titre
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            page.description,
            textAlign: TextAlign.center, // Centrer la description
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// Composant personnalisé pour les boutons
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSecondary
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.primary,
        foregroundColor:
            isSecondary
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}