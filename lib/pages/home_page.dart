import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bladiway/methods/user_data_notifier.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen.dart';
import 'mes_voitures_page.dart'; // Import de la nouvelle page

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
  bool _hasCar = false; // Pour vérifier si l'utilisateur a une voiture
  bool _isValidated = false; // Pour vérifier si l'utilisateur est validé
  bool _validationMessageShown =
      false; // Pour suivre si le message de validation a été affiché

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    // Charger l'état du message depuis SharedPreferences
    _loadMessageState();

    // Initialiser le stream pour écouter les modifications des données utilisateur
    User? user = _auth.currentUser;
    if (user != null) {
      _userStream = _firestore.collection('users').doc(user.uid).snapshots();
      // S'abonner au stream pour les mises à jour en temps réel
      _setupUserListener();
    }
    _checkUserHasCar(); // Vérifier initialement si l'utilisateur a une voiture
  }

  // Nouvelle méthode pour charger l'état du message
  Future<void> _loadMessageState() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          _validationMessageShown =
              prefs.getBool('validation_message_shown_${user.uid}') ?? false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'état du message : $e');
    }
  }

  void _setupUserListener() {
    _userStream.listen(
      (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            final name = data['prenom'] ?? 'Utilisateur'.tr();
            final photoUrl = data['profileImageUrl'] ?? '';
            userDataNotifier.updateUserData(name, photoUrl);

            // Vérifier si l'utilisateur vient d'être validé
            bool wasValidated = _isValidated;
            setState(() {
              _isValidated = data['isValidated'] == true;
            });

            // Afficher le message uniquement si l'utilisateur vient d'être validé
            if (_isValidated &&
                !wasValidated &&
                _hasCar &&
                !_validationMessageShown) {
              _showValidationMessage();
            }

            // Vérifier si l'utilisateur a une voiture chaque fois que les données sont mises à jour
            _checkUserHasCar();
          }
        }
      },
      onError: (e) {
        print('Erreur lors de l\'écoute des données utilisateur : $e');
      },
    );
  }

  // Méthode modifiée pour enregistrer l'état du message
  Future<void> _showValidationMessage() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Marquer le message comme affiché localement
        setState(() {
          _validationMessageShown = true;
        });

        // Enregistrer l'état dans SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('validation_message_shown_${user.uid}', true);

        // Afficher le SnackBar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Votre compte a été validé! Vous pouvez maintenant gérer vos voitures.'
                    .tr(),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    } catch (e) {
      print('Erreur lors de l\'enregistrement de l\'état du message : $e');
    }
  }

  // Méthode pour vérifier si l'utilisateur a enregistré une voiture
  Future<void> _checkUserHasCar() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot carsSnapshot =
            await _firestore
                .collection('cars')
                .where('id_proprietaire', isEqualTo: user.uid)
                .limit(1)
                .get();

        bool hadCar = _hasCar;
        setState(() {
          _hasCar = carsSnapshot.docs.isNotEmpty;
        });

        // Si l'utilisateur vient d'ajouter une voiture et qu'il est déjà validé
        if (_hasCar && !hadCar && _isValidated && !_validationMessageShown) {
          _showValidationMessage();
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des voitures : $e');
    }
  }

  void _onItemTapped(int index) {
    // Définir les index pour chaque élément du menu
    final homeIndex = 0;
    final reservationIndex = 1;
    final tripsIndex = 2;
    final settingsIndex = 3;

    // Redirection vers la page d'accueil
    if (index == homeIndex) {
      setState(() {
        _selectedIndex = homeIndex;
      });
      return;
    }

    // Redirection vers la page de réservation
    if (index == reservationIndex) {
      // Remplacer par la navigation vers la page de réservation
      Navigator.pushNamed(context, '/reservations');
      return;
    }

    // Redirection vers la page des trajets
    if (index == tripsIndex) {
      // Remplacer par la navigation vers la page des trajets
      Navigator.pushNamed(context, '/trips');
      return;
    }

    // Redirection vers la page des paramètres
    if (index == settingsIndex) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ParametresPage()),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToMesVoitures() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MesVoituresPage()),
    ).then((_) {
      // Après retour de la page Mes Voitures, vérifier à nouveau si l'utilisateur a toujours une voiture
      _checkUserHasCar();
    });
  }

  Future<void> _checkAddTripPermission() async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté pour continuer'.tr())),
      );
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Utilisateur non trouvé'.tr())));
        return;
      }

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      bool hasLicense =
          userData != null &&
          userData.containsKey('recto_permis') &&
          userData.containsKey('verso_permis') &&
          userData['recto_permis'] != null &&
          userData['verso_permis'] != null;

      QuerySnapshot carsSnapshot =
          await _firestore
              .collection('cars')
              .where('id_proprietaire', isEqualTo: user.uid)
              .limit(1)
              .get();
      bool hasCar = carsSnapshot.docs.isNotEmpty;

      // Mettre à jour l'état _hasCar si nécessaire
      if (_hasCar != hasCar) {
        setState(() {
          _hasCar = hasCar;
        });
      }

      bool isValidated =
          userData != null &&
          userData.containsKey('isValidated') &&
          userData['isValidated'] == true;

      // Mettre à jour l'état _isValidated si nécessaire
      if (_isValidated != isValidated) {
        setState(() {
          _isValidated = isValidated;
        });
      }

      if (hasLicense && hasCar) {
        if (isValidated) {
          Navigator.pushNamed(context, '/info_trajet');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vos informations sont en cours de validation'.tr(),
              ),
            ),
          );
        }
      } else {
        // Si l'utilisateur n'a pas de permis ou de voiture, le rediriger directement
        if (!hasLicense || !hasCar) {
          // Naviguer directement vers la page de vérification du conducteur
          Navigator.pushNamed(context, '/verifier_Conducteur');
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la vérification'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pas de SnackBar dans build() pour éviter l'affichage répété

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
                    final name = userData['name'];
                    final photoUrl = userData['photoUrl'];

                    if (name == null || photoUrl == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

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
                                    backgroundImage:
                                        photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                    child:
                                        photoUrl.isEmpty
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
                                  'Bienvenue à notre plateforme'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.7),
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
                          tr('Bonjour, {}', args: [name]),
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7),
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
                    title: 'Trouvez votre trajet idéal 🚗'.tr(),
                    subtitle:
                        'Découvrez facilement les meilleurs trajets adaptés à vos besoins.'
                            .tr(),
                    buttonText: 'Réserver'.tr(),
                    color1: const Color(0xFF1976D2),
                    color2: const Color(0xFF42A5F5),
                    onPressed: () {
                      // Naviguer vers la page de réservation
                      Navigator.pushNamed(context, '/reservation');
                    },
                  ),
                  const SizedBox(height: 16),
                  buildCard(
                    title: 'Proposez votre trajet 🛣️'.tr(),
                    subtitle:
                        'Partagez votre route et faites des économies.'.tr(),
                    buttonText: 'Ajouter un trajet'.tr(),
                    color1: const Color(0xFF2E7D32),
                    color2: const Color(0xFF66BB6A),
                    onPressed: _checkAddTripPermission,
                  ),

                  // Ajouter la carte "Mes voitures" uniquement si l'utilisateur est validé
                  if (_hasCar && _isValidated) ...[
                    const SizedBox(height: 16),
                    buildCard(
                      title: 'Gérez vos voitures 🚘'.tr(),
                      subtitle:
                          'Consultez et modifiez les informations de vos véhicules.'
                              .tr(),
                      buttonText: 'Voir mes voitures'.tr(),
                      color1: const Color(0xFFE64A19),
                      color2: const Color(0xFFFF7043),
                      onPressed: _navigateToMesVoitures,
                    ),
                  ],

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
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.5),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'Accueil'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.check_circle),
            label: 'Réservation'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.directions_car),
            label: 'Mes trajets'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'Paramètres'.tr(),
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

  Widget buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos statistiques'.tr(),
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
              'Trajets'.tr(),
              totalTrips.toString(),
              Icons.route,
              Colors.deepPurple,
            ),
            buildStatCard(
              'Proposés'.tr(),
              proposedTrips.toString(),
              Icons.add_circle,
              Colors.green,
            ),
            buildStatCard(
              'Km parcourus'.tr(),
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

  @override
  void dispose() {
    // Nettoyer les ressources si nécessaire
    super.dispose();
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
