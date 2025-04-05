import 'package:flutter/material.dart';

class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildSettingsList(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: HeaderClipper(),
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 20,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          context,
          title: 'Compte',
          icon: Icons.person,
          options: [
            _buildTile('Mon profil', Icons.edit, () {
              _showSnackBar(context, "Accéder au profil");
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          context,
          title: 'Préférences',
          icon: Icons.tune,
          options: [
            SwitchListTile(
              title: const Text('Notifications'),
              secondary: const Icon(Icons.notifications),
              value: true,
              onChanged: (val) {
                // Implémenter la logique pour les notifications
              },
            ),
            SwitchListTile(
              title: const Text('Mode sombre'),
              secondary: const Icon(Icons.dark_mode),
              value: false,
              onChanged: (val) {
                // Implémenter la logique pour le mode sombre
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          context,
          title: 'Langue',
          icon: Icons.language,
          options: [
            _buildTile('Choisir la langue', Icons.language, () {
              _showLanguageDialog(context);
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          context,
          title: 'Aide',
          icon: Icons.help,
          options: [
            _buildTile('Centre d\'aide', Icons.help_outline, () {
              _showSnackBar(context, "Accéder au centre d'aide");
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          context,
          title: 'Gestion du Compte',
          icon: Icons.account_circle,
          options: [
            _buildTile('Se déconnecter', Icons.logout, () {
              _showSnackBar(context, "Déconnexion réussie");
            }, textColor: Colors.red),
          ],
        ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Français'),
                onTap: () {
                  _showSnackBar(context, "Langue changée en Français");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Anglais'),
                onTap: () {
                  _showSnackBar(context, "Language changed to English");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> options,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options,
        ],
      ),
    );
  }

  Widget _buildTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color textColor = Colors.black,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
