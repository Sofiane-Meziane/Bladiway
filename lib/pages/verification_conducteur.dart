import 'package:flutter/material.dart';

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
  final int _currentPage = 0;

  // Liste des pages à afficher (ici, une seule page pour cette tâche spécifique)
  final List<PermissionPage> _pages = const [
    PermissionPage(
      title: 'Complétez votre profil pour publier un trajet',
      description:
          'Pour publier un trajet, vous devez scanner votre permis de conduire et ajouter au moins une voiture.',
      imagePath: 'assets/images/licenceVerification.jpg', // Mettez ici l'image appropriée
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  // Navigue vers une page spécifique
  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
        child: Padding(
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
              // Indicateurs de page
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return GestureDetector(
                    onTap: () => _navigateToPage(index),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildDot(index == _currentPage),
                    ),
                  );
                }),
              ),
              // Boutons d'action
              const SizedBox(height: 30),
              _ActionButton(
                label: "Scanner le permis",
                onPressed: () => Navigator.pushNamed(context, '/scan_permission'), // Vous pouvez ajouter la logique de scan ici
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: "Ajouter une voiture",
                onPressed: () => Navigator.pushNamed(context, '/add_car'), // Vous pouvez ajouter la logique d'ajout de voiture ici
                isSecondary: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
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
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            page.description,
            textAlign: TextAlign.center,
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

  // Construction d'un point indicateur
  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color:
            isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow:
            isActive
                ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withAlpha(76),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
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
