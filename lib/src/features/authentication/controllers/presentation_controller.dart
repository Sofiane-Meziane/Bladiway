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

class PresentationController extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentPage = 0;

  int get currentPage => _currentPage;

  final List<OnboardingModel> pages = const [
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

  PresentationController() {
    pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    final newPage = pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      _currentPage = newPage;
      notifyListeners();
    }
  }

  void setCurrentPage(int page) {
    if (page != _currentPage) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void navigateToPage(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    pageController.removeListener(_handlePageChange);
    pageController.dispose();
    super.dispose();
  }
}
