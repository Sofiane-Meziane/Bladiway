import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details_mes_trajets.dart';
import '../services/notification_service.dart'; // Ajout de l'import pour le service de notification

// Constantes pour les noms de champs Firestore
const String FIELD_USER_ID = 'userId';
const String FIELD_STATUS = 'status';
const String FIELD_DEPART = 'départ';
const String FIELD_ARRIVEE = 'arrivée';
const String FIELD_DATE = 'date';
const String FIELD_HEURE = 'heure';
const String FIELD_PRIX = 'prix';

// Constantes pour les valeurs de statut
const String STATUS_EN_ATTENTE = 'en attente'; // Nouveau statut par défaut
const String STATUS_EN_ROUTE =
    'en route'; // Nouveau statut pour trajet commencé
const String STATUS_TERMINE = 'terminé';
const String STATUS_COMPLETE = 'completé';
const String STATUS_ANNULE = 'annulé';
const String STATUS_BLOQUE = 'bloqué'; // Nouveau statut

class MesTrajetScreen extends StatefulWidget {
  const MesTrajetScreen({super.key});

  @override
  _MesTrajetScreenState createState() => _MesTrajetScreenState();
}

class _MesTrajetScreenState extends State<MesTrajetScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService =
      NotificationService(); // Initialisation du service de notification
  Stream<QuerySnapshot>? _tripStream;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initTripStream();
  }

  void _initTripStream() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print("Initialisation du stream pour l'utilisateur: ${user.uid}");

        // Récupérer tous les trajets de l'utilisateur sans filtrer par status
        _tripStream =
            _firestore
                .collection('trips')
                .where(FIELD_USER_ID, isEqualTo: user.uid)
                .snapshots();

        // Ajouter un listener pour le débogage
        _tripStream?.listen(
          (snapshot) {
            print("Nombre de documents récupérés: ${snapshot.docs.length}");

            for (var doc in snapshot.docs) {
              print("Document ID: ${doc.id}");
              final data = doc.data() as Map<String, dynamic>;
              print("Document data: $data");
              print("Status: ${data[FIELD_STATUS] ?? STATUS_EN_ATTENTE}");
            }
          },
          onError: (error) {
            print("Erreur dans le stream: $error");
          },
        );
      } else {
        setState(() {
          _errorMessage = "Utilisateur non connecté";
          print("Aucun utilisateur connecté");
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur: ${e.toString()}";
        print("Erreur lors de l'initialisation du stream: $e");
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Méthode pour vérifier s'il y a des messages non lus pour un trajet
  Stream<int> _getUnreadMessagesCountForTrip(String tripId) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield 0;
      return;
    }

    try {
      // Récupérer toutes les réservations pour ce trajet
      final reservationSnapshot =
          await _firestore
              .collection('reservations')
              .where('tripId', isEqualTo: tripId)
              .get();

      if (reservationSnapshot.docs.isEmpty) {
        yield 0;
        return;
      }

      int unreadCount = 0;

      // Pour chaque réservation, vérifier s'il y a des messages non lus
      for (var reservationDoc in reservationSnapshot.docs) {
        final passengerId = reservationDoc.data()['userId'] as String?;

        if (passengerId != null) {
          final unreadStream = _notificationService
              .getUnreadMessagesCountFromPassenger(passengerId);
          await for (final count in unreadStream) {
            unreadCount += count;
            break; // On ne prend que la première valeur du stream
          }
        }
      }

      yield unreadCount;
    } catch (e) {
      print("Erreur lors de la vérification des messages non lus: $e");
      yield 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BladiWay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Section titre avec fond dégradé
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Text(
              'Mes trajets',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          // Section liste des trajets
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : _tripStream == null
                    ? const Center(
                      child: Text('Impossible de charger les données'),
                    )
                    : StreamBuilder<QuerySnapshot>(
                      stream: _tripStream,
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<QuerySnapshot> snapshot,
                      ) {
                        if (snapshot.hasError) {
                          print(
                            "Erreur dans le streamBuilder: ${snapshot.error}",
                          );
                          return Center(
                            child: Text('Erreur: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.data == null ||
                            snapshot.data!.docs.isEmpty) {
                          final currentUser = _auth.currentUser;
                          if (currentUser != null) {
                            print(
                              "ID de l'utilisateur actuel: ${currentUser.uid}",
                            );
                            print("Aucun trajet trouvé pour cet utilisateur");
                          }

                          return const Center(
                            child: Text('Aucun trajet disponible'),
                          );
                        }

                        print(
                          "Nombre de documents: ${snapshot.data!.docs.length}",
                        );

                        // On n'exclut plus les trajets annulés - on affiche tous les trajets
                        final allDocs = snapshot.data!.docs;

                        // Trier les trajets par date (décroissant)
                        allDocs.sort((a, b) {
                          try {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aDate = aData[FIELD_DATE] ?? '';
                            final bDate = bData[FIELD_DATE] ?? '';
                            return bDate.toString().compareTo(aDate.toString());
                          } catch (e) {
                            print("Erreur lors du tri: $e");
                            return 0; // Pas de changement en cas d'erreur
                          }
                        });

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ListView.builder(
                            itemCount: allDocs.length,
                            itemBuilder: (context, index) {
                              var trip = allDocs[index];
                              return _buildTripCard(trip);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(DocumentSnapshot document) {
    try {
      final tripData = document.data() as Map<String, dynamic>;
      print("Construction de la carte pour le trajet: ${document.id}");
      print("Données du trajet: $tripData");

      // Informations du trajet avec valeurs par défaut
      final String departure = tripData[FIELD_DEPART] ?? 'Inconnu';
      final String arrival = tripData[FIELD_ARRIVEE] ?? 'Inconnu';
      final String date = tripData[FIELD_DATE] ?? 'Date inconnue';
      final String time = tripData[FIELD_HEURE] ?? '';
      final dynamic price = tripData[FIELD_PRIX] ?? 0;
      final String status =
          tripData[FIELD_STATUS] ?? STATUS_EN_ATTENTE; // Par défaut en attente
      final Color statusColor = _getStatusColor(status);

      // Initiales des villes
      final String departureInitial =
          departure.isNotEmpty
              ? departure.split(',')[0].trim()[0].toUpperCase()
              : 'X';
      final String arrivalInitial =
          arrival.isNotEmpty
              ? arrival.split(',')[0].trim()[0].toUpperCase()
              : 'X';

      return StreamBuilder<int>(
        stream: _getUnreadMessagesCountForTrip(document.id),
        builder: (context, snapshot) {
          final unreadMessagesCount = snapshot.data ?? 0;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => TrajetDetailsScreen(tripId: document.id),
                ),
              ).then((_) {
                setState(() {}); // Refresh on return
              });
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 15),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Points de départ et arrivée avec ligne de connexion
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: Text(
                                departureInitial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(height: 30, width: 2, color: Colors.grey),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green,
                              child: Text(
                                arrivalInitial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Informations principales
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_formatLocation(departure)} - ${_formatLocation(arrival)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (time.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          time,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$price DA',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de notification pour nouveaux messages
                  if (unreadMessagesCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadMessagesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Erreur d\'affichage du trajet ${document.id}: $e');
      // Renvoyer une carte d'erreur au lieu d'un widget vide
      return Card(
        margin: const EdgeInsets.only(bottom: 15),
        color: Colors.red.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Erreur d\'affichage du trajet: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  String _formatLocation(String location) {
    return location.isNotEmpty ? location.split(',')[0].trim() : 'Inconnu';
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case STATUS_TERMINE:
        return 'terminé';
      case STATUS_COMPLETE:
        return 'completé';
      case STATUS_EN_ROUTE:
        return 'en route';
      case STATUS_ANNULE:
        return 'annulé';
      case STATUS_BLOQUE:
        return 'bloqué';
      case STATUS_EN_ATTENTE:
      default:
        return 'en attente';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case STATUS_TERMINE:
        return Colors.green;
      case STATUS_COMPLETE:
        return const Color.fromARGB(255, 15, 236, 225);
      case STATUS_EN_ROUTE:
        return Colors.blue;
      case STATUS_ANNULE:
        return Colors.red;
      case STATUS_BLOQUE:
        return Colors.grey;
      case STATUS_EN_ATTENTE:
      default:
        return Colors.amber;
    }
  }
}
