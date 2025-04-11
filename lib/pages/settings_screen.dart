import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:bladiway/widgets/settings_widgets.dart';
import 'package:bladiway/methods/commun_methods.dart';
import 'package:bladiway/providers/theme_provider.dart';
import 'package:bladiway/pages/centre_aide_page.dart';

class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  Widget _buildSettingsList(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentLocale = context.locale;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsCard(
          title: tr('settings.account'),
          icon: Icons.person,
          children: [
            SettingsTile(
              title: tr('settings.my_profile'),
              icon: Icons.edit,
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: tr('settings.preferences'),
          icon: Icons.tune,
          children: [
            SettingsSwitch(
              title: tr('settings.notifications'),
              icon: Icons.notifications,
              value: true,
              onChanged: (bool newValue) {},
            ),
            SettingsSwitch(
              title: tr('settings.dark_mode'),
              icon: Icons.dark_mode,
              value: themeProvider.isDarkMode,
              onChanged: (bool newValue) {
                themeProvider.setDarkMode(newValue);
                CommunMethods().displaySnackBar(
                  newValue
                      ? tr('settings.dark_mode_enabled')
                      : tr('settings.dark_mode_disabled'),
                  context,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: tr('settings.language'),
          icon: Icons.language,
          children: [
            SettingsTile(
              title: tr('settings.select_language'),
              icon: Icons.language,
              onTap: () => _showLanguageDialog(context, currentLocale),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: tr('settings.help'),
          icon: Icons.help,
          children: [
            SettingsTile(
              title: tr('settings.help_center'),
              icon: Icons.help_outline,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CentreAidePage(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: tr('settings.account_management'),
          icon: Icons.account_circle,
          children: [
            SettingsTile(
              title: tr('settings.logout'),
              icon: Icons.logout,
              textColor: Theme.of(context).colorScheme.error,
              onTap: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context, Locale currentLocale) {
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
                  tr('settings.select_language'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildLanguageOption(
                  context,
                  'Français',
                  'FR',
                  const Locale('fr'),
                  currentLocale,
                  () {
                    context.setLocale(const Locale('fr'));
                    CommunMethods().displaySnackBar(
                      "Langue changée vers le français",
                      context,
                    );
                    Navigator.pop(context);
                  },
                ),
                _buildLanguageOption(
                  context,
                  'English',
                  'EN',
                  const Locale('en'),
                  currentLocale,
                  () {
                    context.setLocale(const Locale('en'));
                    CommunMethods().displaySnackBar(
                      "Language changed to English",
                      context,
                    );
                    Navigator.pop(context);
                  },
                ),
                _buildLanguageOption(
                  context,
                  'العربية',
                  'AR',
                  const Locale('ar'),
                  currentLocale,
                  () {
                    context.setLocale(const Locale('ar'));
                    CommunMethods().displaySnackBar(
                      "تم تغيير اللغة إلى العربية",
                      context,
                    );
                    Navigator.pop(context);
                  },
                ),
                _buildLanguageOption(
                  context,
                  'Tamazight',
                  'KAB',
                  const Locale('fr', 'DZ'),
                  currentLocale,
                  () {
                    context.setLocale(const Locale('fr', 'DZ'));
                    CommunMethods().displaySnackBar(
                      "Langue changée vers Tamazight",
                      context,
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String language,
    String code,
    Locale locale,
    Locale currentLocale,
    VoidCallback onTap,
  ) {
    final isSelected =
        locale.languageCode == currentLocale.languageCode &&
        (locale.countryCode == null ||
            locale.countryCode == currentLocale.countryCode);

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

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(tr('settings.logout')),
            content: Text(tr('settings.logout_confirmation')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('common.cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  tr('settings.logout'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
    if (result == true) {
      try {
        await FirebaseAuth.instance.signOut();
        CommunMethods().displaySnackBar(tr('settings.logout_success'), context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/presentation',
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        CommunMethods().displaySnackBar(
          "${tr('settings.logout_error')} : $e",
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: tr('settings.title')),
            Expanded(child: _buildSettingsList(context)),
          ],
        ),
      ),
    );
  }
}
