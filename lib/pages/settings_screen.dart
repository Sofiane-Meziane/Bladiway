import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Widgets externalisés dans le dossier "widgets"
import 'package:bladiway/widgets/settings_widgets.dart';
// Méthodes communes dans le dossier "methods"
import 'package:bladiway/methods/commun_methods.dart';
// Provider de thème
import 'package:bladiway/providers/theme_provider.dart';

/// Écran des paramètres optimisé et organisé
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  /// Construit la liste des sections de paramètres
  Widget _buildSettingsList(BuildContext context) {
    // Récupérer l'état actuel du thème
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // SECTION : Compte
        SettingsCard(
          title: 'Compte',
          icon: Icons.person,
          children: [
            SettingsTile(
              title: 'Mon profil',
              icon: Icons.edit,
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // SECTION : Préférences
        SettingsCard(
          title: 'Préférences',
          icon: Icons.tune,
          children: [
            SettingsSwitch(
              title: 'Notifications',
              icon: Icons.notifications,
              value: true,
              onChanged: (bool newValue) {
                // Implémentez ici la logique pour activer/désactiver les notifications
              },
            ),
            SettingsSwitch(
              title: 'Mode sombre',
              icon: Icons.dark_mode,
              value: themeProvider.isDarkMode, // Obtenir l'état actuel du thème
              onChanged: (bool newValue) {
                // Changer le thème via le provider
                themeProvider.setDarkMode(newValue);
                // Afficher une confirmation à l'utilisateur
                CommunMethods().displaySnackBar(
                  newValue ? "Mode sombre activé" : "Mode clair activé",
                  context,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // SECTION : Langue
        SettingsCard(
          title: 'Langue',
          icon: Icons.language,
          children: [
            SettingsTile(
              title: 'Choisir la langue',
              icon: Icons.language,
              onTap: () => _showLanguageDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // SECTION : Aide
        SettingsCard(
          title: 'Aide',
          icon: Icons.help,
          children: [
            SettingsTile(
              title: 'Centre d\'aide',
              icon: Icons.help_outline,
              onTap: () {
                CommunMethods().displaySnackBar(
                  "Accéder au centre d'aide",
                  context,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // SECTION : Gestion du Compte
        SettingsCard(
          title: 'Gestion du Compte',
          icon: Icons.account_circle,
          children: [
            SettingsTile(
              title: 'Se déconnecter',
              icon: Icons.logout,
              textColor: Theme.of(context).colorScheme.error,
              onTap: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Affiche la boîte de dialogue pour sélectionner la langue
  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sélectionnez votre langue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildLanguageOption(context, 'Français', 'FR', true, () {
                  CommunMethods().displaySnackBar(
                    "Langue changée en Français",
                    context,
                  );
                  Navigator.pop(context);
                }),
                _buildLanguageOption(context, 'Anglais', 'EN', false, () {
                  CommunMethods().displaySnackBar(
                    "Language changed to English",
                    context,
                  );
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
    );
  }

  /// Construit une option de langue pour le sélecteur
  Widget _buildLanguageOption(
    BuildContext context,
    String language,
    String code,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[200],
        radius: 16,
        child: Text(
          code,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(language),
      trailing:
          isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
      onTap: onTap,
    );
  }

  /// Affiche une confirmation avant de se déconnecter
  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Déconnexion'),
            content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white, // This ensures text is visible
                ),
                child: const Text(
                  'Déconnecter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, // Makes text more visible
                  ),
                ),
              ),
            ],
          ),
    );
    if (result == true) {
      try {
        await FirebaseAuth.instance.signOut();
        CommunMethods().displaySnackBar("Déconnexion réussie", context);
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        CommunMethods().displaySnackBar(
          "Erreur lors de la déconnexion : $e",
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Utilise la couleur de fond définie dans votre thème (depuis main.dart)
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête réutilisable externalisé dans widgets/settings_widgets.dart
            const SettingsHeader(title: 'Paramètres'),
            // Liste des paramètres
            Expanded(child: _buildSettingsList(context)),
          ],
        ),
      ),
    );
  }
}
