import 'package:flutter/material.dart';

// Modèle de données pour une page d'introduction
class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// Écran principal de présentation
class PresentationPage extends StatefulWidget {
  const PresentationPage({super.key});

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Liste des pages à afficher
  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: 'Voyagez en bonne compagnie',
      description:
          'Rencontrez des personnes sympas et rendez vos trajets plus agréables et conviviaux.',
      imagePath: 'assets/images/links.png',
    ),
    OnboardingPage(
      title: 'Réduire l\'empreinte carbone',
      description:
          'Réduisez vos émissions de carbone en partageant des trajets avec d\'autres',
      imagePath: 'assets/images/Nature.png',
    ),
    OnboardingPage(
      title: 'Économisez sur vos trajets',
      description:
          'Partagez vos déplacements et réduisez considérablement vos frais de transport.',
      imagePath: 'assets/images/savemoney.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageChange);
  }

  // Met à jour la page courante lors du défilement
  void _handlePageChange() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
    }
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
              // Titre de l'application
              Text(
                "Bladiway",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              // Vue paginée
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _pages.length,
                  itemBuilder:
                      (context, index) =>
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
                label: "S'inscrire",
                onPressed: () => Navigator.pushNamed(context, '/signup'),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: "Se connecter",
                onPressed: () => Navigator.pushNamed(context, '/login'),
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
  Widget _buildPageContent(OnboardingPage page, Size size) {
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
