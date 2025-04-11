import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// Modèle de données avec clés de traduction
class PermissionPage {
  final String titleKey;
  final String descriptionKey;
  final String imagePath;

  const PermissionPage({
    required this.titleKey,
    required this.descriptionKey,
    required this.imagePath,
  });
}

// Écran principal
class PermissionAddCarPage extends StatefulWidget {
  const PermissionAddCarPage({super.key});

  @override
  State<PermissionAddCarPage> createState() => _PermissionAddCarPageState();
}

class _PermissionAddCarPageState extends State<PermissionAddCarPage> {
  final PageController _pageController = PageController();
  final int _currentPage = 0;

  final List<PermissionPage> _pages = const [
    PermissionPage(
      titleKey: 'Complétez votre profil pour publier un trajet',
      descriptionKey: 'Pour publier un trajet, vous devez scanner votre permis de conduire et ajouter au moins une voiture.',
      imagePath: 'assets/images/licenceVerification.jpg',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
              // Back button
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                    onPressed: () => Navigator.pop(context), // Navigate back
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Center the "bladiway" text
              Center(
                child: Text(
                  "bladiway".tr(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) =>
                      _buildPageContent(_pages[index], size),
                ),
              ),
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
              const SizedBox(height: 30),
              _ActionButton(
                label: "Scanner le permis".tr(),
                onPressed: () =>
                    Navigator.pushNamed(context, '/scanner_permis'),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: "Ajouter une voiture".tr(),
                onPressed: () => Navigator.pushNamed(context, '/add_car'),
                isSecondary: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(PermissionPage page, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: size.height * 0.25,
          child: Image.asset(
            page.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              size: 100,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          page.titleKey.tr(),
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
            page.descriptionKey.tr(),
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

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: isActive
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

// Composant pour les boutons
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
        backgroundColor: isSecondary
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.primary,
        foregroundColor: isSecondary
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
