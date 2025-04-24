import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bladiway/methods/user_data_notifier.dart';
import 'package:easy_localization/easy_localization.dart';

import 'settings_screen.dart';
import 'mes_voitures_page.dart';
import 'notifications_page.dart';
import '../services/notification_service.dart';

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
  bool _hasCar = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<DocumentSnapshot> _userStream;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null) {
      _userStream = _firestore.collection('users').doc(user.uid).snapshots();
      _setupUserListener();
    }
    _checkUserHasCar();
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
            _checkUserHasCar();
          }
        }
      },
      onError: (e) {
        print('Erreur lors de l\'écoute des données utilisateur : $e');
      },
    );
  }

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

        setState(() {
          _hasCar = carsSnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification des voitures : $e');
    }
  }

  void _onItemTapped(int index) {
    final homeIndex = 0;
    final reservationIndex = 1;
    final tripsIndex = 2;
    final settingsIndex = 3;

    if (index == homeIndex) {
      setState(() {
        _selectedIndex = homeIndex;
      });
      return;
    }

    if (index == reservationIndex) {
      Navigator.pushNamed(context, '/reservations');
      return;
    }

    if (index == tripsIndex) {
      Navigator.pushNamed(context, '/trips');
      return;
    }

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
      _checkUserHasCar();
    });
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
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
      // Récupérer le permis depuis la table piece_identite
      QuerySnapshot permisSnapshot =
          await _firestore
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .where('type_piece', isEqualTo: 'permis')
              .limit(1)
              .get();

      print('Permis doc trouvé: ${permisSnapshot.docs.isNotEmpty}');
      print(
        'Données du permis: ${permisSnapshot.docs.isNotEmpty ? permisSnapshot.docs.first.data() : "Aucune donnée"}',
      );

      bool hasVerifiedLicense = false;
      bool hasPendingOrNoLicense = true;

      if (permisSnapshot.docs.isNotEmpty) {
        var permisData =
            permisSnapshot.docs.first.data() as Map<String, dynamic>;
        String statut = permisData['statut'];
        String? dateExpirationStr = permisData['date_expiration'];

        DateTime? dateExpiration;
        if (dateExpirationStr != null) {
          try {
            dateExpiration = DateTime.parse(dateExpirationStr);
          } catch (e) {
            print('Erreur de parsing de la date d\'expiration: $e');
          }
        }

        bool isLicenseExpired =
            dateExpiration == null || dateExpiration.isBefore(DateTime.now());

        hasVerifiedLicense = statut == 'verifie' && !isLicenseExpired;
        hasPendingOrNoLicense =
            statut == 'en cours' || statut == 'refuse' || isLicenseExpired;
      }

      // Récupérer les voitures
      QuerySnapshot carsSnapshot =
          await _firestore
              .collection('cars')
              .where('id_proprietaire', isEqualTo: user.uid)
              .limit(1)
              .get();

      bool hasCar = carsSnapshot.docs.isNotEmpty;

      print('Nombre de voitures: ${carsSnapshot.docs.length}');
      print('hasVerifiedLicense: $hasVerifiedLicense');
      print('hasCar: $hasCar');
      print('hasPendingOrNoLicense: $hasPendingOrNoLicense');

      if (_hasCar != hasCar) {
        setState(() {
          _hasCar = hasCar;
        });
      }

      // Redirection
      if (hasVerifiedLicense && hasCar) {
        Navigator.pushNamed(context, '/info_trajet');
      } else {
        Navigator.pushNamed(context, '/verifier_Conducteur');
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la vérification'.tr())),
      );
    }
  }

  Future<void> _checkReservationPermission() async {
    User? user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté pour continuer'.tr())),
      );
      return;
    }

    try {
      QuerySnapshot piecesSnapshot =
          await _firestore
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .get();

      final pieces =
          piecesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

      bool hasVerifiedID = pieces.any((piece) => piece['statut'] == 'verifie');
      bool hasPendingOrRefusedID =
          pieces.isEmpty ||
          pieces.any(
            (piece) =>
                piece['statut'] == 'en cours' || piece['statut'] == 'refuse',
          );

      if (hasVerifiedID) {
        Navigator.pushNamed(context, '/reserver');
      } else if (hasPendingOrRefusedID) {
        Navigator.pushNamed(context, '/verifier_Passager');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous devez soumettre une pièce d\'identité pour réserver un trajet'
                  .tr(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
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
                            StreamBuilder<int>(
                              stream:
                                  _notificationService
                                      .getUnreadNotificationsCount(),
                              builder: (context, snapshot) {
                                int unreadCount = snapshot.data ?? 0;

                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.notifications_none,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        size: 28,
                                      ),
                                      onPressed: _navigateToNotifications,
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
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
                    onPressed: _checkReservationPermission,
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

                  // Ajouter la carte "Mes voitures" uniquement si l'utilisateur a au moins une voiture
                  if (_hasCar) ...[
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
          _buildReservationsIconWithBadge(context),
          _buildMessageIconWithBadge(context),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'Paramètres'.tr(),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildReservationsIconWithBadge(
    BuildContext context,
  ) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          const Icon(Icons.check_circle),
          StreamBuilder<int>(
            stream: _notificationService.getPassengerUnreadMessagesCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    snapshot.data! > 99 ? '99+' : '${snapshot.data}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      label: 'Réservations'.tr(),
    );
  }

  BottomNavigationBarItem _buildMessageIconWithBadge(BuildContext context) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          const Icon(Icons.directions_car),
          StreamBuilder<int>(
            stream: _notificationService.getUnreadMessagesCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    snapshot.data! > 99 ? '99+' : '${snapshot.data}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      label: 'Mes trajets'.tr(),
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
