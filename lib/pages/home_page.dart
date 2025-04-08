import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bladiway/methods/user_data_notifier.dart';
import 'settings_screen.dart';
// Import de la page de vérification

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Appel initial pour charger les données
  }

  /// Fonction pour récupérer les données de l'utilisateur depuis Firestore
  Future<void> _fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final name = userDoc['prenom'] ?? 'Utilisateur';
          final photoUrl = userDoc['profileImageUrl'] ?? '';
          // Mettre à jour le ValueNotifier avec les données initiales
          userDataNotifier.updateUserData(name, photoUrl);
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur : $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ParametresPage()),
      );
    }
  }

  /// Fonction pour vérifier si l'utilisateur peut ajouter un trajet
  Future<void> _checkAddTripPermission() async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour continuer'),
        ),
      );
      return;
    }

    try {
      // Récupérer le document de l'utilisateur
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non trouvé')),
        );
        return;
      }

      // Récupérer les données sous forme de Map pour vérifier les champs
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      // Vérifier si le permis est scanné (champs recto_permis et verso_permis existent et non nuls)
      bool hasLicense = userData != null &&
          userData.containsKey('recto_permis') &&
          userData.containsKey('verso_permis') &&
          userData['recto_permis'] != null &&
          userData['verso_permis'] != null;

      // Vérifier si l'utilisateur a ajouté au moins une voiture
      QuerySnapshot carsSnapshot = await _firestore
          .collection('cars')
          .where('id_proprietaire', isEqualTo: user.uid)
          .limit(1)
          .get();
      bool hasCar = carsSnapshot.docs.isNotEmpty;

      // Vérifier si l'administrateur a validé (champ isValidated existe et est true)
      bool isValidated = userData != null &&
          userData.containsKey('isValidated') &&
          userData['isValidated'] == true;

      if (hasLicense && hasCar) {
        if (isValidated) {
          // Toutes les conditions sont remplies, naviguer vers info_trajet
          Navigator.pushNamed(context, '/info_trajet');
        } else {
          // Informations saisies mais non validées
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vos informations sont en cours de validation'),
            ),
          );
        }
      } else {
        // Rediriger vers la page de vérification
        Navigator.pushNamed(context, '/verifier_Conducteur');
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la vérification')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              ClipPath(
                clipper: HeaderClipper(),
                child: Container(
                  height: 270,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        const Color(0xFF64B5F6),
                      ],
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
                child: ValueListenableBuilder<Map<String, String>>(
                  valueListenable: userDataNotifier,
                  builder: (context, userData, child) {
                    final name = userData['name'] ?? 'Utilisateur';
                    final photoUrl = userData['photoUrl'] ?? '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/profile');
                                  },
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white,
                                    backgroundImage: photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.blue,
                                            size: 24,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Bienvenue à notre plateforme',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.notifications_none,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Bladiway',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bonjour, $name',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    );
                  },
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
                    onPressed: () {}, // Laisser vide pour l'instant
                  ),
                  const SizedBox(height: 16),
                  buildCard(
                    title: 'Proposez votre trajet 🛣️',
                    subtitle: 'Partagez votre route et faites des économies.',
                    buttonText: 'Ajouter un trajet',
                    color1: const Color(0xFF2E7D32),
                    color2: const Color(0xFF66BB6A),
                    onPressed: _checkAddTripPermission, // Nouvelle fonction
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  /// Widget pour construire les cartes de trajets
  Widget buildCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required Color color1,
    required Color color2,
    required VoidCallback onPressed,
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
              onPressed: onPressed,
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

  /// Widget pour construire la section des statistiques
  Widget buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos statistiques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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

  /// Widget pour construire une carte de statistique
  Widget buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
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