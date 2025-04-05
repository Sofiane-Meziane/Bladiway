import 'package:flutter/material.dart';
// Importation de la page paramètres
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int totalTrips = 15;
  int proposedTrips = 5;
  int kilometersTraveled = 320;

  String userName = 'Massinissa';
  String userPhotoUrl = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Ajout de la navigation vers la page des paramètres
    if (index == 4) {
      // 4 est l'index de l'onglet Paramètres
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ParametresPage()),
      );
      // Rétablir l'index précédent après navigation pour éviter
      // que l'onglet Paramètres reste sélectionné après retour
      setState(() {
        _selectedIndex = 0; // Ou garder l'index précédent si vous préférez
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Stack(
            children: [
              ClipPath(
                clipper: HeaderClipper(),
                child: Container(
                  height: 270,
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
                top: 50,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  userPhotoUrl.isNotEmpty
                                      ? NetworkImage(userPhotoUrl)
                                      : null,
                              child:
                                  userPhotoUrl.isEmpty
                                      ? const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                        size: 24,
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Bienvenue à notre plateforme',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Bladiway',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bonjour, $userName',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ListView(
                children: [
                  buildCard(
                    title: 'Trouvez votre trajet idéal 🚗',
                    subtitle:
                        'Découvrez facilement les meilleurs trajets adaptés à vos besoins.',
                    buttonText: 'Réserver',
                    color1: const Color(0xFF1976D2),
                    color2: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(height: 16),
                  buildCard(
                    title: 'Proposez votre trajet 🛣️',
                    subtitle: 'Partagez votre route et faites des économies.',
                    buttonText: 'Ajouter un trajet',
                    color1: const Color(0xFF2E7D32),
                    color2: const Color(0xFF66BB6A),
                  ),
                  const SizedBox(height: 16),
                  buildStatisticsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Mes trajets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Réservations',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget buildCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos statistiques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildStatCard(
              'Trajets',
              totalTrips.toString(),
              Icons.route,
              Colors.deepPurple,
            ),
            buildStatCard(
              'Proposés',
              proposedTrips.toString(),
              Icons.add_circle,
              Colors.green,
            ),
            buildStatCard(
              'Km parcourus',
              kilometersTraveled.toString(),
              Icons.speed,
              Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
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
