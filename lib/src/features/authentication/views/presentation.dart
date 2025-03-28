import 'package:flutter/material.dart';

class OnboardingModel {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingModel({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class PresentationPage extends StatefulWidget {
  const PresentationPage({super.key});

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const List<OnboardingModel> _pages = [
    OnboardingModel(
      title: 'Voyagez en bonne compagnie',
      description:
          'Rencontrez des personnes sympas et rendez vos trajets plus agréables et conviviaux.',
      imagePath: 'assets/images/links.png',
    ),
    OnboardingModel(
      title: 'Réduire l\'empreinte carbone',
      description:
          'Réduisez vos émissions de carbone en partageant des trajets avec d\'autres',
      imagePath: 'assets/images/Nature.png',
    ),
    OnboardingModel(
      title: 'Économisez sur vos trajets',
      description:
          'Partagez vos déplacements et réduisez considérablement vos frais de transport.',
      imagePath: 'assets/images/savemoney.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
    }
  }

  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "BladiWay",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged:
                      (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder:
                      (context, index) =>
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
              _buildActionButton(
                label: "S'inscrire",
                onPressed: () => Navigator.pushNamed(context, '/signup'),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
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

  Widget _buildPageContent(OnboardingModel page, Size size) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: size.height * 0.25,
          child: Image.asset(
            page.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.broken_image_outlined,
                size: 100,
                color: theme.colorScheme.onSurface,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          page.title,
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
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDot(bool isActive) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color:
            isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow:
            isActive
                ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(76),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    final theme = Theme.of(context);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSecondary
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.primary,
        foregroundColor:
            isSecondary
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 3,
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
