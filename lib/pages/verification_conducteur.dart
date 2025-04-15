import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import de la page de vérification de licence
import 'scanner_permis.dart'; // Remplacez par le chemin correct

// Classe pour gérer l'état des documents et validations
class UserDocumentManager {
  static const String _licenseScannedKey = 'license_scanned';
  static const String _carAddedKey = 'car_added';
  static const String _validationStatusKey = 'validation_status';

  // Statuts possibles
  static const String PENDING_DOCUMENTS =
      'pending_documents'; // Manque documents
  static const String PENDING_VALIDATION =
      'pending_validation'; // Documents soumis mais pas validés
  static const String VALIDATED = 'validated'; // Validé par l'admin

  // Vérifier l'état de la licence
  static Future<bool> isLicenseScanned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_licenseScannedKey) ?? false;
  }

  // Vérifier si une voiture a été ajoutée
  static Future<bool> isCarAdded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_carAddedKey) ?? false;
  }

  // Obtenir le statut actuel de validation
  static Future<String> getValidationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_validationStatusKey) ?? PENDING_DOCUMENTS;
  }

  // Marquer le permis comme scanné
  static Future<void> setLicenseScanned(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_licenseScannedKey, value);
    await _updateValidationStatus();
  }

  // Marquer la voiture comme ajoutée
  static Future<void> setCarAdded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_carAddedKey, value);
    await _updateValidationStatus();
  }

  // Mettre à jour le statut de validation par l'admin
  static Future<void> setValidated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_validationStatusKey, VALIDATED);
  }

  // Mise à jour interne du statut de validation
  static Future<void> _updateValidationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLicense = await isLicenseScanned();
    final hasCar = await isCarAdded();

    // Si les deux documents sont présents, on passe en attente de validation
    if (hasLicense && hasCar) {
      final currentStatus = await getValidationStatus();
      // Ne pas changer le statut s'il est déjà validé
      if (currentStatus != VALIDATED) {
        await prefs.setString(_validationStatusKey, PENDING_VALIDATION);
      }
    } else {
      await prefs.setString(_validationStatusKey, PENDING_DOCUMENTS);
    }
  }

  // Vérifier si l'utilisateur peut ajouter un trajet
  static Future<bool> canAddTrip() async {
    final status = await getValidationStatus();
    return status == VALIDATED;
  }

  // Reset des données (pour tests)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_licenseScannedKey, false);
    await prefs.setBool(_carAddedKey, false);
    await prefs.setString(_validationStatusKey, PENDING_DOCUMENTS);
  }
}

class PermissionAddCarPage extends StatefulWidget {
  const PermissionAddCarPage({super.key});

  @override
  State<PermissionAddCarPage> createState() => _PermissionAddCarPageState();
}

class _PermissionAddCarPageState extends State<PermissionAddCarPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLicenseScanned = false;
  bool _isCarAdded = false;
  String _validationStatus = UserDocumentManager.PENDING_DOCUMENTS;
  bool _isLoading = true;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Complétez votre profil pour publier un trajet',
      'description':
          'Pour publier un trajet, vous devez scanner votre permis de conduire et ajouter au moins une voiture.',
      'image': 'assets/images/licenceVerification.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    final licenseScanned = await UserDocumentManager.isLicenseScanned();
    final carAdded = await UserDocumentManager.isCarAdded();
    final validationStatus = await UserDocumentManager.getValidationStatus();

    setState(() {
      _isLicenseScanned = licenseScanned;
      _isCarAdded = carAdded;
      _validationStatus = validationStatus;
      _isLoading = false;
    });
  }

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
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _scanLicense() async {
    // Navigation vers la page de scan du permis en utilisant MaterialPageRoute
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LicenseVerificationScreen()),
    );

    // Si le scan est réussi (result est true)
    if (result == true) {
      await UserDocumentManager.setLicenseScanned(true);
      await _loadUserStatus();

      // Si l'utilisateur a également ajouté une voiture, on le redirige vers l'accueil
      if (_isCarAdded) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  Future<void> _addCar() async {
    // Navigation vers la page d'ajout de voiture
    final result = await Navigator.pushNamed(context, '/add_car');

    // Si l'ajout est réussi (result est true)
    if (result == true) {
      await UserDocumentManager.setCarAdded(true);
      await _loadUserStatus();

      // Si l'utilisateur a également scanné son permis, on le redirige vers l'accueil
      if (_isLicenseScanned) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
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

              // Status indicator
              if (_validationStatus == UserDocumentManager.PENDING_VALIDATION)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Vos documents sont en attente de vérification".tr(),
                          style: TextStyle(color: Colors.amber[800]),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPageContent(_pages[index], size);
                  },
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

              // License Button
              _buildActionButton(
                label:
                    _isLicenseScanned
                        ? "Permis scanné ✓".tr()
                        : "Scanner le permis".tr(),
                icon: Icons.document_scanner,
                onPressed: _isLicenseScanned ? null : _scanLicense,
                isSuccess: _isLicenseScanned,
              ),

              const SizedBox(height: 12),

              // Car Button
              _buildActionButton(
                label:
                    _isCarAdded
                        ? "Voiture ajoutée ✓".tr()
                        : "Ajouter une voiture".tr(),
                icon: Icons.directions_car,
                onPressed: _isCarAdded ? null : _addCar,
                isSuccess: _isCarAdded,
                isSecondary: !_isCarAdded,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(Map<String, String> page, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: size.height * 0.25,
          child: Image.asset(
            page['image']!,
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
          page['title']!.tr(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            page['description']!.tr(),
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isSuccess = false,
    bool isSecondary = false,
  }) {
    // Déterminer la couleur en fonction de l'état
    Color backgroundColor;
    Color textColor;

    if (isSuccess) {
      // État complété/succès
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (isSecondary) {
      // Bouton secondaire
      backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
      textColor = Theme.of(context).colorScheme.onSecondaryContainer;
    } else {
      // Bouton principal
      backgroundColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimary;
    }

    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        disabledBackgroundColor: isSuccess ? backgroundColor : null,
        disabledForegroundColor: isSuccess ? textColor : null,
      ),
      onPressed: onPressed,
    );
  }
}
