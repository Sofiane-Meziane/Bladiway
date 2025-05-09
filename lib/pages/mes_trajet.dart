import 'dart:async'; // Import pour StreamController et StreamSubscription

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details_mes_trajets.dart'; // Assurez-vous que ce chemin est correct
import '../services/notification_service.dart'; // Assurez-vous que ce chemin est correct

// Constantes pour les noms de champs Firestore
const String FIELD_USER_ID = 'userId';
const String FIELD_STATUS = 'status';
const String FIELD_DEPART = 'départ';
const String FIELD_ARRIVEE = 'arrivée';
const String FIELD_DATE = 'date';
const String FIELD_HEURE = 'heure';
const String FIELD_PRIX = 'prix';
const String FIELD_CREATED_AT = 'createdAt';

// Constantes pour les valeurs de statut
const String STATUS_EN_ATTENTE = 'en attente';
const String STATUS_EN_ROUTE = 'en route';
const String STATUS_TERMINE = 'terminé';
const String STATUS_COMPLETE = 'completé';
const String STATUS_ANNULE = 'annulé';
const String STATUS_BLOQUE = 'bloqué';

class MesTrajetScreen extends StatefulWidget {
  const MesTrajetScreen({super.key});

  @override
  _MesTrajetScreenState createState() => _MesTrajetScreenState();
}

class _MesTrajetScreenState extends State<MesTrajetScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  Stream<QuerySnapshot>? _tripStream;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _statusUpdateTimer;

  final int _selectedIndex = 2; // Index pour "Mes trajets"

  // Map pour garder en cache les streams des compteurs de messages non lus
  final Map<String, Stream<int>> _unreadMessagesStreamsCache = {};

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    String route = '';
    switch (index) {
      case 0:
        route = '/home';
        break;
      case 1:
        route = '/reservations';
        break;
      case 2:
        // Déjà sur cette page
        return;
      case 3:
        route = '/settings';
        break;
    }
    if (route.isNotEmpty) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  void initState() {
    super.initState();
    _initTripStream();

    // Vérifier les trajets passés immédiatement au démarrage
    _checkAndUpdatePastTrips();

    // Configurer un timer pour vérifier périodiquement les trajets passés
    // Vérification toutes les heures
    _statusUpdateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndUpdatePastTrips();
    });
  }

  @override
  void dispose() {
    // Annuler le timer lors de la destruction du widget
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  // Méthode pour vérifier et mettre à jour les trajets passés
  Future<void> _checkAndUpdatePastTrips() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Récupérer tous les trajets qui ne sont pas terminés ou annulés
      final tripsSnapshot =
          await _firestore
              .collection('trips')
              .where(FIELD_USER_ID, isEqualTo: user.uid)
              .where(
                FIELD_STATUS,
                whereIn: [STATUS_EN_ATTENTE, STATUS_EN_ROUTE],
              )
              .get();

      if (tripsSnapshot.docs.isEmpty) return;

      // Date actuelle
      final now = DateTime.now();

      // Parcourir tous les trajets et vérifier leur date
      for (var tripDoc in tripsSnapshot.docs) {
        final tripData = tripDoc.data();

        // Récupérer et parser la date et l'heure du trajet
        final String dateStr = tripData[FIELD_DATE] ?? '';
        final String timeStr = tripData[FIELD_HEURE] ?? '';

        if (dateStr.isEmpty) continue;

        try {
          // Convertir la date du format "dd/MM/yyyy" au format DateTime
          final dateParts = dateStr.split('/');
          if (dateParts.length != 3) continue;

          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);

          // Convertir l'heure (peut être au format "HH:mm" ou "HH:mm AM/PM")
          int hour = 0;
          int minute = 0;

          if (timeStr.isNotEmpty) {
            // Gérer différents formats d'heure possibles
            if (timeStr.contains(':')) {
              final timeParts = timeStr.split(':');
              hour = int.parse(timeParts[0]);

              // Extraire les minutes (peut contenir AM/PM)
              String minuteStr = timeParts[1];
              if (minuteStr.contains(' ')) {
                final minuteParts = minuteStr.split(' ');
                minuteStr = minuteParts[0];

                // Ajuster l'heure pour AM/PM si nécessaire
                if (minuteParts.length > 1) {
                  final ampm = minuteParts[1].toLowerCase();
                  if (ampm == 'pm' && hour < 12) hour += 12;
                  if (ampm == 'am' && hour == 12) hour = 0;
                }
              }

              minute = int.parse(minuteStr);
            }
          }

          final tripDateTime = DateTime(year, month, day, hour, minute);

          // Calculer la différence entre maintenant et la date du trajet
          final difference = now.difference(tripDateTime);

          // Si la date est passée de plus de 24h, mettre à jour le statut
          if (difference.inHours >= 24) {
            await _firestore.collection('trips').doc(tripDoc.id).update({
              FIELD_STATUS: STATUS_TERMINE,
            });
            print(
              'Trajet ${tripDoc.id} automatiquement marqué comme terminé après 24h',
            );
          }
        } catch (e) {
          print(
            'Erreur lors du traitement de la date du trajet ${tripDoc.id}: $e',
          );
          continue;
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des trajets passés: $e');
    }
  }

  void _initTripStream() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _unreadMessagesStreamsCache.clear();
    });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _tripStream =
            _firestore
                .collection('trips')
                .where(FIELD_USER_ID, isEqualTo: user.uid)
                .orderBy(FIELD_CREATED_AT, descending: true)
                .snapshots();

        _tripStream?.first
            .then((_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                // Vérifier les trajets passés après le chargement initial
                _checkAndUpdatePastTrips();
              }
            })
            .catchError((error) {
              if (mounted) {
                setState(() {
                  _errorMessage = "Erreur de chargement des trajets initiaux.";
                  _isLoading = false;
                });
              }
            });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Utilisateur non connecté.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur d'initialisation: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Stream<int> _getUnreadMessagesCountForTrip(String tripId) {
    if (_unreadMessagesStreamsCache.containsKey(tripId)) {
      return _unreadMessagesStreamsCache[tripId]!;
    }

    final controller = StreamController<int>.broadcast();
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      controller.add(0);
      _unreadMessagesStreamsCache[tripId] = controller.stream;
      return controller.stream;
    }

    List<StreamSubscription> subscriptions = [];
    Map<String, int> unreadCountsPerPassenger = {};

    void updateTotal() {
      int totalUnreadCount = unreadCountsPerPassenger.values.fold(
        0,
        (sum, el) => sum + el,
      );
      if (!controller.isClosed) {
        controller.add(totalUnreadCount);
      }
    }

    _firestore
        .collection('reservations')
        .where('tripId', isEqualTo: tripId)
        .get()
        .then((reservationSnapshot) {
          if (controller.isClosed) return;

          if (reservationSnapshot.docs.isEmpty) {
            controller.add(0);
            return;
          }

          List<String> passengerIds =
              reservationSnapshot.docs
                  .map((doc) {
                    var data = doc.data();
                    return data.containsKey('userId')
                        ? data['userId'] as String?
                        : null;
                  })
                  .where((id) => id != null && id != currentUser.uid)
                  .toSet()
                  .toList()
                  .cast<String>();

          if (passengerIds.isEmpty) {
            controller.add(0);
            return;
          }

          for (String passengerId in passengerIds) {
            unreadCountsPerPassenger[passengerId] = 0;
          }
          updateTotal();

          for (String passengerId in passengerIds) {
            if (controller.isClosed) break;
            final streamSub = _notificationService
                .getUnreadMessagesCountFromPassenger(passengerId, tripId)
                .listen(
                  (count) {
                    if (controller.isClosed) return;
                    unreadCountsPerPassenger[passengerId] = count;
                    updateTotal();
                  },
                  onError: (error) {
                    if (controller.isClosed) return;
                    print(
                      "Erreur stream messages non lus pour passager $passengerId, trajet $tripId: $error",
                    );
                    unreadCountsPerPassenger[passengerId] = 0;
                    updateTotal();
                  },
                );
            subscriptions.add(streamSub);
          }
        })
        .catchError((error) {
          if (controller.isClosed) return;
          print(
            "Erreur récupération réservations pour messages non lus (trajet $tripId): $error",
          );
          controller.add(0);
        });

    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
      _unreadMessagesStreamsCache.remove(tripId);
      if (!controller.isClosed) {
        controller.close();
      }
      print(
        "Stream des messages non lus pour le trajet $tripId annulé et fermé.",
      );
    };

    _unreadMessagesStreamsCache[tripId] = controller.stream;
    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [_buildHeader(theme), Expanded(child: _buildBody(theme))],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Réservations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Mes trajets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    // Alignement sur le header de reservations_screen.dart
    return Stack(
      children: [
        ClipPath(
          clipper: HeaderClipper(),
          child: Container(
            height: 200, // Hauteur similaire à reservations_screen.dart
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  // Utilisation d'une couleur secondaire ou d'une nuance de la couleur primaire
                  // pour correspondre à reservations_screen.dart si elle est différente.
                  // Si reservations_screen utilise theme.colorScheme.primaryContainer.withOpacity(0.8)
                  // alors on peut garder ça, sinon ajuster.
                  // Pour l'exemple de reservations_screen.dart fourni, c'était Color(0xFF64B5F6)
                  // qui est un bleu clair. Si votre thème primaire est différent, ajustez.
                  const Color(
                    0xFF64B5F6,
                  ), // Couleur du gradient de reservations_screen.dart
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top:
              MediaQuery.of(context).padding.top +
              30, // Ajustement pour le SafeArea
          left: 16, // Marge gauche comme dans reservations_screen.dart
          right: 100, // Marge droite comme dans reservations_screen.dart
          child: SizedBox(
            height: 48, // hauteur suffisante pour l'alignement
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color:
                          theme
                              .colorScheme
                              .onPrimary, // Couleur de l'icône sur fond primaire
                      size: 28, // Taille de l'icône
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                  ),
                ),
                Center(
                  child: Text(
                    'Mes Trajets',
                    style: TextStyle(
                      fontSize:
                          24, // Taille de police de reservations_screen.dart
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                      letterSpacing:
                          0, // Espacement des lettres comme reservations_screen.dart
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, _errorMessage!);
    }

    if (_tripStream == null) {
      return _buildErrorState(
        theme,
        "Impossible de charger les données des trajets.",
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _tripStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          print("Erreur dans StreamBuilder (MesTrajets): ${snapshot.error}");
          return _buildErrorState(
            theme,
            'Une erreur est survenue lors du chargement des trajets.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(theme);
        }

        final allDocs = snapshot.data!.docs;
        if (_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isLoading = false);
          });
        }

        return RefreshIndicator(
          onRefresh: () async {
            _initTripStream();
            // Vérifier les trajets passés lors du rafraîchissement manuel
            await _checkAndUpdatePastTrips();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: allDocs.length,
            itemBuilder: (context, index) {
              var trip = allDocs[index];
              return _buildTripCard(trip, theme);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun trajet pour le moment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vos trajets créés apparaîtront ici.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
            const SizedBox(height: 24),
            Text(
              'Oops ! Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: _initTripStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(DocumentSnapshot document, ThemeData theme) {
    try {
      final tripData = document.data() as Map<String, dynamic>;
      final String tripId = document.id;

      final String departure = tripData[FIELD_DEPART] as String? ?? 'N/A';
      final String arrival = tripData[FIELD_ARRIVEE] as String? ?? 'N/A';
      final String date = tripData[FIELD_DATE] as String? ?? 'N/A';
      final String time = tripData[FIELD_HEURE] as String? ?? '';
      final String price =
          (tripData[FIELD_PRIX] != null) ? '${tripData[FIELD_PRIX]} DA' : 'N/A';
      final String status =
          tripData[FIELD_STATUS] as String? ?? STATUS_EN_ATTENTE;

      final Color statusColor = _getStatusColor(status, theme);
      final String statusText = _getStatusText(status);

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrajetDetailsScreen(tripId: tripId),
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatLocation(departure)} → ${_formatLocation(arrival)}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(
                                theme,
                                Icons.calendar_today_outlined,
                                date,
                              ),
                              const SizedBox(width: 12),
                              if (time.isNotEmpty)
                                _buildInfoChip(
                                  theme,
                                  Icons.access_time_outlined,
                                  time,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        StreamBuilder<int>(
                          stream: _getUnreadMessagesCountForTrip(tripId),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            if (unreadCount > 0) {
                              return Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox(height: 18);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Erreur d\'affichage du trajet ${document.id}: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: theme.colorScheme.errorContainer.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Erreur d\'affichage de ce trajet.',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ),
      );
    }
  }

  Widget _buildInfoChip(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatLocation(String location) {
    if (location == 'N/A') return location;
    return location.split(',')[0].trim();
  }

  String _getStatusText(String status) {
    String s = status.toLowerCase();
    switch (s) {
      case STATUS_TERMINE:
        return 'Terminé';
      case STATUS_COMPLETE:
        return 'Complet';
      case STATUS_EN_ROUTE:
        return 'En route';
      case STATUS_ANNULE:
        return 'Annulé';
      case STATUS_BLOQUE:
        return 'Bloqué';
      case STATUS_EN_ATTENTE:
      default:
        return 'En attente';
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case STATUS_TERMINE:
        return Colors.green.shade700;
      case STATUS_COMPLETE:
        return Colors.blue.shade700;
      case STATUS_EN_ROUTE:
        return theme.colorScheme.primary;
      case STATUS_ANNULE:
        return theme.colorScheme.error;
      case STATUS_BLOQUE:
        return Colors.purpleAccent;
      case STATUS_EN_ATTENTE:
      default:
        return Colors.orange.shade700;
    }
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(
      0,
      size.height - 40,
    ); // Ajusté pour correspondre à reservations_screen.dart
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20, // Ajusté pour correspondre à reservations_screen.dart
      size.width,
      size.height - 40, // Ajusté pour correspondre à reservations_screen.dart
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
