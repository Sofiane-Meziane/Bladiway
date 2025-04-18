import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import pour StreamSubscription
import 'package:url_launcher/url_launcher.dart'; // Import pour launchUrl
import 'chat_screen.dart'; // Import de la page de chat

// Constantes pour les noms de champs Firestore
const String FIELD_USER_ID = 'userId';
const String FIELD_STATUS = 'status';
const String FIELD_DEPART = 'départ';
const String FIELD_ARRIVEE = 'arrivée';
const String FIELD_DATE = 'date';
const String FIELD_HEURE = 'heure';
const String FIELD_PRIX = 'prix';
const String FIELD_PLACES = 'nbrPlaces';
const String FIELD_PLACES_DISPONIBLES = 'placesDisponibles';
const String FIELD_PASSENGERS = 'passengers';
const String FIELD_DESCRIPTION = 'description';
const String FIELD_VEHICLE = 'vehiculeId';

// Constantes pour les valeurs de statut
const String STATUS_EN_ATTENTE = 'en attente';
const String STATUS_EN_ROUTE = 'en route';
const String STATUS_TERMINE = 'terminé';
const String STATUS_COMPLETE = 'completé';
const String STATUS_ANNULE = 'annulé';
const String STATUS_BLOQUE = 'bloqué';

class TrajetDetailsScreen extends StatefulWidget {
  final String tripId;

  const TrajetDetailsScreen({super.key, required this.tripId});

  @override
  _TrajetDetailsScreenState createState() => _TrajetDetailsScreenState();
}

class _TrajetDetailsScreenState extends State<TrajetDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _tripData;
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _passengers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  StreamSubscription<DocumentSnapshot>? _tripSubscription;
  StreamSubscription<QuerySnapshot>? _passengersSubscription;
  bool _listenerSetupComplete = false;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _passengersSubscription?.cancel();
    super.dispose();
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadTripDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = "Vous devez être connecté pour accéder à cette page.";
          _isLoading = false;
        });
        return;
      }

      final tripDoc =
          await _firestore.collection('trips').doc(widget.tripId).get();

      if (!tripDoc.exists) {
        setState(() {
          _errorMessage = "Ce trajet n'existe pas ou a été supprimé.";
          _isLoading = false;
        });
        return;
      }
      final tripData = tripDoc.data() as Map<String, dynamic>;

      if (tripData.containsKey(FIELD_VEHICLE)) {
        String vehicleId = tripData[FIELD_VEHICLE];
        await _loadVehicleData(vehicleId);
      }

      if (tripData[FIELD_USER_ID] != currentUser.uid) {
        setState(() {
          _errorMessage = "Vous n'êtes pas autorisé à consulter ce trajet.";
          _isLoading = false;
        });
        return;
      }

      if (!tripData.containsKey(FIELD_STATUS)) {
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_EN_ATTENTE,
        });
        tripData[FIELD_STATUS] = STATUS_EN_ATTENTE;
      }

      await _checkAndUpdateTripStatus(tripData);
      _setupRealtimeListeners();
      await _loadPassengersFromReservations(tripData);

      setState(() {
        _tripData = tripData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            "Erreur lors du chargement des détails: ${e.toString()}";
        _isLoading = false;
      });
      print("Erreur lors du chargement des détails du trajet: $e");
    }
  }

  Future<void> _loadVehicleData(String vehicleId) async {
    try {
      final vehicleDoc =
          await _firestore.collection('cars').doc(vehicleId).get();

      if (vehicleDoc.exists) {
        setState(() {
          _vehicleData = vehicleDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des données du véhicule: $e");
    }
  }

  Widget _buildVehicleWidget() {
    if (_vehicleData == null) {
      return _infoRow(
        Icons.directions_car,
        'Véhicule',
        _tripData![FIELD_VEHICLE] ?? 'Non spécifié',
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child:
                _vehicleData!['imageUrl'] != null &&
                        _vehicleData!['imageUrl'].isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _vehicleData!['imageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.directions_car,
                            size: 30,
                            color: Colors.grey[600],
                          );
                        },
                      ),
                    )
                    : Icon(
                      Icons.directions_car,
                      size: 30,
                      color: Colors.grey[600],
                    ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_vehicleData!['marque'] ?? ''} ${_vehicleData!['model'] ?? ''}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Couleur: ${_vehicleData!['color'] ?? 'Non spécifiée'}',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  'Plaque: ${_vehicleData!['plate'] ?? 'Non spécifiée'}',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPassengersFromReservations(
    Map<String, dynamic> tripData,
  ) async {
    try {
      print("Chargement des passagers pour le trajet: ${widget.tripId}");

      final reservationsSnapshot =
          await _firestore
              .collection('reservations')
              .where('tripId', isEqualTo: widget.tripId)
              .get();

      print(
        "Nombre de réservations trouvées: ${reservationsSnapshot.docs.length}",
      );

      Map<String, int> userReservedPlaces = {};
      int placesReserveesTotal = 0;

      for (var doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        int seatsReserved = data['seatsReserved'] ?? 1;

        if (userId != null) {
          userReservedPlaces[userId] = seatsReserved;
        }
        placesReserveesTotal += seatsReserved;
      }

      // Récupérer le nombre total de places du trajet
      int totalPlaces =
          tripData[FIELD_PLACES] != null
              ? (tripData[FIELD_PLACES] is int
                  ? tripData[FIELD_PLACES]
                  : int.tryParse(tripData[FIELD_PLACES].toString()) ?? 0)
              : 0;

      // Calculer les places restantes
      int placesDisponibles = totalPlaces - placesReserveesTotal;
      if (placesDisponibles < 0) placesDisponibles = 0;

      // Mettre à jour les données du trajet avec les places disponibles
      tripData[FIELD_PLACES_DISPONIBLES] = placesDisponibles;

      // Mettre à jour le document trip avec le nombre de places disponibles uniquement si nécessaire
      await _firestore.collection('trips').doc(widget.tripId).update({
        FIELD_PLACES_DISPONIBLES: placesDisponibles,
      });

      // Vérifier si le trajet doit être marqué comme complet
      await _checkAndUpdateTripStatusBasedOnSeats(tripData);

      if (userReservedPlaces.isEmpty) {
        setState(() {
          _passengers = [];
          _tripData = tripData;
        });
        return;
      }

      List<Map<String, dynamic>> allPassengers = [];
      List<String> userIds = userReservedPlaces.keys.toList();

      print("Utilisateurs à charger: $userIds");

      for (int i = 0; i < userIds.length; i += 10) {
        int endIdx = (i + 10 < userIds.length) ? i + 10 : userIds.length;
        List<String> batch = userIds.sublist(i, endIdx);

        final usersSnapshot =
            await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

        print(
          "Utilisateurs trouvés dans ce batch: ${usersSnapshot.docs.length}",
        );

        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          print("Données utilisateur trouvées pour: ${userDoc.id}");
          allPassengers.add({
            'id': userDoc.id,
            'nom': userData['nom'] ?? 'Inconnu',
            'prenom': userData['prenom'] ?? 'Inconnu',
            'phone': userData['phone'] ?? 'Non disponible',
            'email': userData['email'] ?? 'Non disponible',
            'profileImageUrl': userData['profileImageUrl'] ?? '',
            'placesReservees': userReservedPlaces[userDoc.id] ?? 1,
          });
        }
      }

      print("Nombre total de passagers chargés: ${allPassengers.length}");

      setState(() {
        _passengers = allPassengers;
        _tripData = tripData;
      });
    } catch (e) {
      print("Erreur lors du chargement des informations des passagers: $e");
    }
  }

  void _setupRealtimeListeners() {
    if (_listenerSetupComplete) return;

    try {
      _tripSubscription = _firestore
          .collection('trips')
          .doc(widget.tripId)
          .snapshots()
          .listen(
            (DocumentSnapshot snapshot) async {
              if (!snapshot.exists) {
                setState(() {
                  _errorMessage = "Ce trajet n'existe plus ou a été supprimé.";
                });
                return;
              }

              final updatedTripData = snapshot.data() as Map<String, dynamic>;

              await _checkAndUpdateTripStatus(updatedTripData);
              if (updatedTripData.containsKey(FIELD_VEHICLE) &&
                  (_tripData == null ||
                      _tripData![FIELD_VEHICLE] !=
                          updatedTripData[FIELD_VEHICLE])) {
                await _loadVehicleData(updatedTripData[FIELD_VEHICLE]);
              }
              setState(() {
                _tripData = updatedTripData;
                _isLoading = false;
              });

              await _loadPassengersFromReservations(updatedTripData);
            },
            onError: (error) {
              print(
                "Erreur lors de l'écoute des modifications du trajet: $error",
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Erreur de connexion. Les mises à jour en temps réel sont suspendues.',
                    ),
                    backgroundColor: Colors.red,
                    action: SnackBarAction(
                      label: 'Réessayer',
                      onPressed: () {
                        _setupRealtimeListeners();
                      },
                    ),
                  ),
                );
              }
            },
          );

      if (_tripData != null && _tripData!.containsKey(FIELD_PASSENGERS)) {
        _listenForPassengersChanges();
      }

      setState(() {
        _listenerSetupComplete = true;
      });
    } catch (e) {
      print("Erreur lors de la configuration des listeners en temps réel: $e");
    }
  }

  void _listenForPassengersChanges() {
    try {
      _passengersSubscription?.cancel();

      List<String> passengerIds = [];

      if (_tripData != null && _tripData!.containsKey(FIELD_PASSENGERS)) {
        final passengersList = _tripData![FIELD_PASSENGERS];
        if (passengersList is List && passengersList.isNotEmpty) {
          passengerIds = List<String>.from(
            passengersList.map((item) => item.toString()),
          );
        }
      }

      if (passengerIds.isEmpty) {
        setState(() {
          _passengers = [];
        });
        return;
      }

      if (passengerIds.length <= 10) {
        _passengersSubscription = _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: passengerIds)
            .snapshots()
            .listen((QuerySnapshot snapshot) {
              _updatePassengersFromSnapshot(snapshot);
            });
      } else {
        _loadPassengersFromReservations(_tripData!);
      }
    } catch (e) {
      print("Erreur lors de l'écoute des changements des passagers: $e");
    }
  }

  void _updatePassengersFromSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;

    List<Map<String, dynamic>> updatedPassengers = [];

    for (var userDoc in snapshot.docs) {
      final userData = userDoc.data() as Map<String, dynamic>;
      updatedPassengers.add({
        'id': userDoc.id,
        'nom': userData['nom'] ?? 'Inconnu',
        'prenom': userData['prenom'] ?? 'Inconnu',
        'phone': userData['phone'] ?? 'Non disponible',
        'email': userData['email'] ?? 'Non disponible',
        'profileImageUrl': userData['profileImageUrl'] ?? '',
      });
    }

    setState(() {
      _passengers = updatedPassengers;
    });
  }

  Widget _buildPassengersList() {
    if (_passengers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Pas de passagers pour ce trajet.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Passagers (${_passengers.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _passengers.length,
          itemBuilder: (context, index) {
            final passenger = _passengers[index];
            final placesReservees = passenger['placesReservees'] ?? 1;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            passenger['profileImageUrl'] != null &&
                                    passenger['profileImageUrl'].isNotEmpty
                                ? NetworkImage(passenger['profileImageUrl'])
                                : const AssetImage(
                                      'assets/images/default_avatar.png',
                                    )
                                    as ImageProvider,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${passenger['prenom']} ${passenger['nom']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$placesReservees ${placesReservees > 1 ? 'places' : 'place'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        passenger['phone'] ?? 'Téléphone non disponible',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => _callPhoneNumber(passenger['phone']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          onPressed:
                              () => _navigateToMessaging(passenger['id']),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _checkAndUpdateTripStatusBasedOnSeats(
    Map<String, dynamic> tripData,
  ) async {
    try {
      String currentStatus = tripData[FIELD_STATUS] ?? STATUS_EN_ATTENTE;
      if ([
        STATUS_TERMINE,
        STATUS_COMPLETE,
        STATUS_ANNULE,
        STATUS_EN_ROUTE,
      ].contains(currentStatus)) {
        return;
      }

      // Récupérer les places totales et disponibles
      int totalPlaces =
          tripData[FIELD_PLACES] != null
              ? (tripData[FIELD_PLACES] is int
                  ? tripData[FIELD_PLACES]
                  : int.tryParse(tripData[FIELD_PLACES].toString()) ?? 0)
              : 0;

      int availablePlaces =
          tripData[FIELD_PLACES_DISPONIBLES] != null
              ? (tripData[FIELD_PLACES_DISPONIBLES] is int
                  ? tripData[FIELD_PLACES_DISPONIBLES]
                  : int.tryParse(
                        tripData[FIELD_PLACES_DISPONIBLES].toString(),
                      ) ??
                      totalPlaces)
              : totalPlaces;

      print(
        "Vérification des places: $availablePlaces disponibles sur $totalPlaces",
      );

      // Si toutes les places sont prises et le trajet est en attente ou bloqué,
      // passer en statut completé
      if (availablePlaces == 0 &&
          totalPlaces > 0 &&
          [STATUS_EN_ATTENTE, STATUS_BLOQUE].contains(currentStatus)) {
        print("Mise à jour du statut: $currentStatus → $STATUS_COMPLETE");
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_COMPLETE,
        });
        print("Statut du trajet mis à jour automatiquement à 'Completé'");
      }
    } catch (e) {
      print("Erreur lors de la vérification du statut basé sur les places: $e");
    }
  }

  // Nouvelle méthode pour récupérer l'ID de la réservation
  Future<String?> _getReservationIdForPassenger(String passengerId) async {
    try {
      final reservationSnapshot =
          await _firestore
              .collection('reservations')
              .where('tripId', isEqualTo: widget.tripId)
              .where('userId', isEqualTo: passengerId)
              .get();

      if (reservationSnapshot.docs.isNotEmpty) {
        return reservationSnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print("Erreur lors de la récupération de la réservation: $e");
      return null;
    }
  }

  // Méthode modifiée pour utiliser l'ID de la réservation
  void _navigateToMessaging(String receiverId) async {
    String? reservationId = await _getReservationIdForPassenger(receiverId);
    if (reservationId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => ChatPage(
                reservationId: reservationId, // Passer l'ID de la réservation
                otherUserId: receiverId,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de trouver la réservation pour ce passager.',
          ),
        ),
      );
    }
  }

  Future<void> _checkAndUpdateTripStatus(Map<String, dynamic> tripData) async {
    try {
      await _checkAndUpdateTripStatusBasedOnSeats(tripData);
      String currentStatus = tripData[FIELD_STATUS] ?? STATUS_EN_ATTENTE;
      if ([
        STATUS_TERMINE,
        STATUS_ANNULE,
        STATUS_COMPLETE,
        STATUS_EN_ROUTE,
      ].contains(currentStatus)) {
        return;
      }

      int totalPlaces = tripData[FIELD_PLACES] ?? 0;
      int availablePlaces = tripData[FIELD_PLACES_DISPONIBLES] ?? totalPlaces;
      print(
        "Vérification des places: $availablePlaces disponibles sur $totalPlaces",
      );
      if (availablePlaces == 0 &&
          totalPlaces > 0 &&
          [STATUS_EN_ATTENTE, STATUS_BLOQUE].contains(currentStatus)) {
        print("Mise à jour du statut: $currentStatus → $STATUS_COMPLETE");
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_COMPLETE,
        });
        print("Statut du trajet mis à jour automatiquement à 'Completé'");
      }

      String tripDateStr = tripData[FIELD_DATE] ?? '';
      String tripTimeStr = tripData[FIELD_HEURE] ?? '00:00';

      if (tripDateStr.isEmpty) return;

      List<String> dateParts = tripDateStr.split('/');
      if (dateParts.length != 3) return;

      DateTime? tripDateTime;
      try {
        int day = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int year = int.parse(dateParts[2]);

        List<String> timeParts = tripTimeStr.split(':');
        int hour = 0, minute = 0;
        if (timeParts.length == 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        }

        tripDateTime = DateTime(year, month, day, hour, minute);
      } catch (e) {
        print("Erreur lors du parsing de la date: $e");
        return;
      }

      DateTime now = DateTime.now();

      if (now.isAfter(tripDateTime) &&
          [
            STATUS_EN_ATTENTE,
            STATUS_EN_ROUTE,
            STATUS_BLOQUE,
            STATUS_COMPLETE,
          ].contains(currentStatus)) {
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_TERMINE,
        });
        print("Statut du trajet mis à jour automatiquement à 'Terminé'");
      }
    } catch (e) {
      print("Erreur lors de la vérification du statut du trajet: $e");
    }
  }

  Future<void> _updateTripStatus(String newStatus) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _firestore.collection('trips').doc(widget.tripId).update({
        FIELD_STATUS: newStatus,
      });

      // Si le statut passe à "terminé", créer des notifications d'évaluation pour tous les passagers
      if (newStatus == STATUS_TERMINE && _passengers.isNotEmpty) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Récupérer toutes les réservations pour ce trajet
          final reservationsSnapshot =
              await _firestore
                  .collection('reservations')
                  .where('tripId', isEqualTo: widget.tripId)
                  .get();

          for (var reservationDoc in reservationsSnapshot.docs) {
            final reservationData = reservationDoc.data();
            final passengerId = reservationData['userId'] as String?;

            // S'assurer que ce n'est pas le conducteur lui-même
            if (passengerId != null && passengerId != currentUser.uid) {
              // Créer une entrée dans la collection 'evaluations_pending'
              await _firestore.collection('evaluations_pending').add({
                'tripId': widget.tripId,
                'driverId': currentUser.uid,
                'passengerId': passengerId,
                'reservationId': reservationDoc.id,
                'createdAt': FieldValue.serverTimestamp(),
                'isCompleted': false,
                'skipped': false,
              });
            }
          }
        }
      }

      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut du trajet mis à jour: $newStatus')),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _updateTripStatusWithReason(
    String newStatus,
    String reason,
  ) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _firestore.collection('trips').doc(widget.tripId).update({
        FIELD_STATUS: newStatus,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trajet annulé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  void _showConfirmationDialog(String action, String newStatus) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(action),
          content: Text('Êtes-vous sûr de vouloir $action ce trajet ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateTripStatus(newStatus);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  void _showCancellationDialog() {
    final TextEditingController reasonController = TextEditingController();
    bool isReasonValid = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red[700]),
                  const SizedBox(width: 10),
                  const Text('Annuler le trajet'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Veuillez indiquer la raison de l\'annulation:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Raison de l\'annulation...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        isReasonValid = value.trim().length >= 10;
                      });
                    },
                  ),
                  if (!isReasonValid && reasonController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'La raison doit contenir au moins 10 caractères',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Retour'),
                ),
                ElevatedButton(
                  onPressed:
                      isReasonValid
                          ? () {
                            Navigator.of(context).pop();
                            _updateTripStatusWithReason(
                              STATUS_ANNULE,
                              reasonController.text,
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withOpacity(0.5),
                  ),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _callPhoneNumber(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro de téléphone non disponible')),
        );
      }
      return;
    }

    String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');

    try {
      final Uri launchUri = Uri.parse('tel:$cleanPhoneNumber');
      print("Tentative d'appel: $launchUri");
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print("Erreur lors de l'appel: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Widget _buildActionButtons() {
    if (_tripData == null) return Container();

    final String currentStatus = _tripData![FIELD_STATUS] ?? STATUS_EN_ATTENTE;

    if ([STATUS_TERMINE, STATUS_ANNULE].contains(currentStatus)) {
      return Container();
    }

    return Column(
      children: [
        const Divider(height: 32),
        Text(
          'Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (currentStatus == STATUS_COMPLETE ||
                currentStatus == STATUS_BLOQUE)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Commencer le trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    _isProcessing
                        ? null
                        : () => _showConfirmationDialog(
                          'Commencer',
                          STATUS_EN_ROUTE,
                        ),
              ),
            if (currentStatus == STATUS_EN_ROUTE)
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Terminer le trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    _isProcessing
                        ? null
                        : () =>
                            _showConfirmationDialog('Terminer', STATUS_TERMINE),
              ),
            if (currentStatus == STATUS_EN_ATTENTE &&
                currentStatus != STATUS_BLOQUE)
              ElevatedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Bloquer le trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 14, 13, 13),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    _isProcessing
                        ? null
                        : () =>
                            _showConfirmationDialog('Bloquer', STATUS_BLOQUE),
              ),
            if (![
              STATUS_ANNULE,
              STATUS_TERMINE,
              STATUS_EN_ROUTE,
            ].contains(currentStatus))
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('Annuler le trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    _isProcessing ? null : () => _showCancellationDialog(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case STATUS_TERMINE:
        statusColor = Colors.green;
        break;
      case STATUS_COMPLETE:
        statusColor = const Color.fromARGB(255, 15, 236, 225);
        break;
      case STATUS_EN_ROUTE:
        statusColor = Colors.blue;
        break;
      case STATUS_ANNULE:
        statusColor = Colors.red;
        break;
      case STATUS_BLOQUE:
        statusColor = const Color.fromARGB(255, 12, 12, 12);
        break;
      case STATUS_EN_ATTENTE:
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlacesInfo() {
    if (_tripData == null) return Container();

    // Récupérer les places totales
    int totalPlaces =
        _tripData![FIELD_PLACES] != null
            ? (_tripData![FIELD_PLACES] is int
                ? _tripData![FIELD_PLACES]
                : int.tryParse(_tripData![FIELD_PLACES].toString()) ?? 0)
            : 0;

    // Récupérer les places disponibles
    int placesDisponibles =
        _tripData![FIELD_PLACES_DISPONIBLES] != null
            ? (_tripData![FIELD_PLACES_DISPONIBLES] is int
                ? _tripData![FIELD_PLACES_DISPONIBLES]
                : int.tryParse(
                      _tripData![FIELD_PLACES_DISPONIBLES].toString(),
                    ) ??
                    totalPlaces)
            : totalPlaces;

    // Calculer les places réservées
    int reservedPlaces = totalPlaces - placesDisponibles;
    if (reservedPlaces < 0) reservedPlaces = 0;

    return _infoRow(
      Icons.airline_seat_recline_normal,
      'Places',
      "$reservedPlaces / $totalPlaces réservées",
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails du trajet')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails du trajet')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tripData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails du trajet')),
        body: const Center(child: Text('Aucune donnée disponible')),
      );
    }

    final String depart = _tripData![FIELD_DEPART] ?? 'Non spécifié';
    final String arrivee = _tripData![FIELD_ARRIVEE] ?? 'Non spécifié';
    final String date = _tripData![FIELD_DATE] ?? 'Non spécifié';
    final String heure = _tripData![FIELD_HEURE] ?? 'Non spécifié';
    final String prix =
        '${_tripData![FIELD_PRIX]?.toString() ?? 'Non spécifié'} DA';
    final String description =
        _tripData![FIELD_DESCRIPTION] ?? 'Aucune description';
    final String status = _tripData![FIELD_STATUS] ?? STATUS_EN_ATTENTE;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du trajet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTripDetails,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Informations du trajet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 24),
              _infoRow(Icons.location_on, 'Départ', depart),
              const SizedBox(height: 16),
              _infoRow(Icons.location_on_outlined, 'Arrivée', arrivee),
              const SizedBox(height: 16),
              _infoRow(Icons.calendar_today, 'Date', date),
              const SizedBox(height: 16),
              _infoRow(Icons.access_time, 'Heure', heure),
              const SizedBox(height: 16),
              _infoRow(Icons.attach_money, 'Prix', prix),
              const SizedBox(height: 16),
              _buildPlacesInfo(),
              if (status == STATUS_ANNULE &&
                  _tripData!.containsKey('cancellationReason'))
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _infoRow(
                    Icons.info_outline,
                    'Raison d\'annulation',
                    _tripData!['cancellationReason'],
                  ),
                ),
              const SizedBox(height: 16),
              if (description.isNotEmpty)
                _infoRow(Icons.description, 'Description', description),
              if (description.isNotEmpty) const SizedBox(height: 16),
              const SizedBox(height: 16),
              _buildVehicleWidget(),
              const SizedBox(height: 24),
              _buildPassengersList(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
