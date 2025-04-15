import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import pour StreamSubscription
import 'package:url_launcher/url_launcher.dart'; // Import pour canLaunchUrl

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

// Déplacer la classe MessagesScreen en dehors de _TrajetDetailsScreenState
class MessagesScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const MessagesScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _sendMessage() {
    // À implémenter
    if (_messageController.text.trim().isEmpty) return;

    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à implémenter')),
    );
  }

  // Ajouter la méthode build manquante
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Messages avec ${widget.receiverName}')),
      body: Column(
        children: [
          Expanded(
            child: Center(child: Text("Historique des messages à implémenter")),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Écrire un message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  // Ajouter cette variable pour stocker les données du véhicule
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _passengers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  // Variables pour les listeners en temps réel
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
    // Annuler les abonnements aux streams quand on quitte l'écran
    _tripSubscription?.cancel();
    _passengersSubscription?.cancel();
    super.dispose();
  }

  // Méthode pour créer une ligne d'information
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

      // Vérifier si l'utilisateur est connecté
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = "Vous devez être connecté pour accéder à cette page.";
          _isLoading = false;
        });
        return;
      }

      // Récupérer les détails du trajet (première fois seulement)
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
      // Après avoir chargé les données du trajet, charger les données du véhicule
      if (tripData.containsKey(FIELD_VEHICLE)) {
        String vehicleId = tripData[FIELD_VEHICLE];
        await _loadVehicleData(vehicleId);
      }

      // Vérifier que l'utilisateur actuel est bien le propriétaire du trajet
      if (tripData[FIELD_USER_ID] != currentUser.uid) {
        setState(() {
          _errorMessage = "Vous n'êtes pas autorisé à consulter ce trajet.";
          _isLoading = false;
        });
        return;
      }

      // Si le statut n'est pas défini, définir par défaut à En attente
      if (!tripData.containsKey(FIELD_STATUS)) {
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_EN_ATTENTE,
        });
        tripData[FIELD_STATUS] = STATUS_EN_ATTENTE;
      }

      // Vérifier automatiquement si la date du trajet est passée et mettre à jour si nécessaire
      await _checkAndUpdateTripStatus(tripData);

      // Configurer l'écoute en temps réel des modifications de trajet
      _setupRealtimeListeners();

      // Charger les informations des passagers
      await _loadPassengersFromReservations(tripData);

      // On charge les données initiales
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

  // Ajouter cette nouvelle méthode pour charger les données du véhicule
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

  // Ajouter cette méthode pour construire le widget de véhicule
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
          // Photo du véhicule (comme icône)
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
          // Informations du véhicule
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

  // Méthode pour charger les informations des passagers
  Future<void> _loadPassengersFromReservations(
    Map<String, dynamic> tripData,
  ) async {
    try {
      // Debug pour voir l'ID du trajet
      print("Chargement des passagers pour le trajet: ${widget.tripId}");

      // Récupérer toutes les réservations pour ce trajet
      final reservationsSnapshot =
          await _firestore
              .collection('reservations')
              .where('tripId', isEqualTo: widget.tripId)
              .get();

      print(
        "Nombre de réservations trouvées: ${reservationsSnapshot.docs.length}",
      );

      // Créer un map pour stocker les IDs d'utilisateurs et leurs places réservées
      Map<String, int> userReservedPlaces = {};

      // Calculer le nombre de places réservées total à partir des réservations
      int placesReserveesTotal = 0;

      // Parcourir toutes les réservations pour ce trajet
      for (var doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        int seatsReserved = data['seatsReserved'] ?? 1;

        // Ajouter l'utilisateur à notre map avec ses places réservées
        if (userId != null) {
          userReservedPlaces[userId] = seatsReserved;
        }

        // Calculer le total des places réservées
        placesReserveesTotal += seatsReserved;
      }

      // Mettre à jour les données du trajet avec le nombre correct de places disponibles
      int totalPlaces = tripData['nbrPlaces'] ?? 0;
      int placesDisponibles = totalPlaces - placesReserveesTotal;

      // S'assurer que les places disponibles ne sont pas négatives
      if (placesDisponibles < 0) placesDisponibles = 0;

      // Mettre à jour les données du trajet localement
      tripData['placesDisponibles'] = placesDisponibles;
      await _checkAndUpdateTripStatusBasedOnSeats(tripData);
      // Si la liste des passagers est vide, pas besoin de continuer
      if (userReservedPlaces.isEmpty) {
        setState(() {
          _passengers = [];
          _tripData = tripData;
        });
        return;
      }

      // Charger les détails des utilisateurs
      List<Map<String, dynamic>> allPassengers = [];
      List<String> userIds = userReservedPlaces.keys.toList();

      print("Utilisateurs à charger: $userIds");

      // Traiter les utilisateurs par lots de 10 (limite Firestore pour whereIn)
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
      // 1. Écouter les modifications du document trajet en temps réel
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

              // Vérifier et mettre à jour le statut si nécessaire
              await _checkAndUpdateTripStatus(updatedTripData);
              // Charger les données du véhicule si l'ID du véhicule a changé
              if (updatedTripData.containsKey(FIELD_VEHICLE) &&
                  (_tripData == null ||
                      _tripData![FIELD_VEHICLE] !=
                          updatedTripData[FIELD_VEHICLE])) {
                await _loadVehicleData(updatedTripData[FIELD_VEHICLE]);
              }
              // Mettre à jour les données locales
              setState(() {
                _tripData = updatedTripData;
                _isLoading = false;
              });

              // Charger les informations mises à jour des passagers
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

      // 2. Configurer le listener pour les passagers si nécessaire
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
      // Nettoyer l'ancien abonnement s'il existe
      _passengersSubscription?.cancel();

      // Initialiser une liste vide pour stocker les IDs des passagers
      List<String> passengerIds = [];

      // Si le trajet a des passagers, récupérer leurs IDs
      if (_tripData != null && _tripData!.containsKey(FIELD_PASSENGERS)) {
        final passengersList = _tripData![FIELD_PASSENGERS];
        if (passengersList is List && passengersList.isNotEmpty) {
          passengerIds = List<String>.from(
            passengersList.map((item) => item.toString()),
          );
        }
      }

      // Si la liste des passagers est vide, pas besoin d'écouter les changements
      if (passengerIds.isEmpty) {
        setState(() {
          _passengers = [];
        });
        return;
      }

      // Éviter l'erreur "A value of type 'List<dynamic>' can't be assigned to a variable of type 'List<String>'"
      // Créer un batch de requêtes si nous avons plus de 10 passagers à cause de la limitation whereIn
      if (passengerIds.length <= 10) {
        // Écouter les changements dans la collection users pour ces passagers
        _passengersSubscription = _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: passengerIds)
            .snapshots()
            .listen((QuerySnapshot snapshot) {
              _updatePassengersFromSnapshot(snapshot);
            });
      } else {
        // Si plus de 10 passagers, faire une requête individuelle pour chaque passager
        // Note: Ceci est une approche simplifiée, idéalement on diviserait en batchs de 10
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
            // Récupérer le nombre de places réservées
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
                          // Afficher le badge avec le nombre de places réservées
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
                    // Boutons séparés du ListTile pour éviter le débordement
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
                              () => _navigateToMessaging(
                                passenger['id'],
                                '${passenger['prenom']} ${passenger['nom']}',
                              ),
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
      // Vérifier si le statut est déjà Terminé, Completé ou Annulé
      String currentStatus = tripData[FIELD_STATUS] ?? STATUS_EN_ATTENTE;
      if ([
        STATUS_TERMINE,
        STATUS_COMPLETE,
        STATUS_ANNULE,
        STATUS_EN_ROUTE,
      ].contains(currentStatus)) {
        return; // Ne pas modifier ces statuts
      }

      // Vérifier si toutes les places sont réservées
      int totalPlaces = tripData[FIELD_PLACES] ?? 0;
      int availablePlaces = tripData[FIELD_PLACES_DISPONIBLES] ?? totalPlaces;

      print(
        "Vérification des places: $availablePlaces disponibles sur $totalPlaces",
      );

      // Si toutes les places sont réservées et le statut est en attente ou bloqué
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

  // Méthode pour naviguer vers l'écran de messagerie
  void _navigateToMessaging(String receiverId, String receiverName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => MessagesScreen(
              receiverId: receiverId,
              receiverName: receiverName,
            ),
      ),
    );
  }

  Future<void> _checkAndUpdateTripStatus(Map<String, dynamic> tripData) async {
    try {
      await _checkAndUpdateTripStatusBasedOnSeats(tripData);
      // Vérifier si le statut est déjà Terminé, Completé ou Annulé
      String currentStatus = tripData[FIELD_STATUS] ?? STATUS_EN_ATTENTE;
      if ([
        STATUS_TERMINE,
        STATUS_ANNULE,
        STATUS_COMPLETE,
        STATUS_EN_ROUTE,
      ].contains(currentStatus)) {
        return; // Ne pas modifier les statuts finaux, sauf COMPLETE qui peut passer à EN_ROUTE
      }

      // Vérifier si toutes les places sont réservées
      int totalPlaces = tripData[FIELD_PLACES] ?? 0;
      int availablePlaces = tripData[FIELD_PLACES_DISPONIBLES] ?? totalPlaces;
      print(
        "Vérification des places: $availablePlaces disponibles sur $totalPlaces",
      );
      // Si toutes les places sont réservées et le statut n'est pas déjà COMPLETE
      if (availablePlaces == 0 &&
          totalPlaces > 0 &&
          [STATUS_EN_ATTENTE, STATUS_BLOQUE].contains(currentStatus)) {
        print("Mise à jour du statut: $currentStatus → $STATUS_COMPLETE");
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_COMPLETE,
        });

        // La mise à jour sera automatiquement captée par le listener
        print("Statut du trajet mis à jour automatiquement à 'Completé'");
      }

      // Vérifier si la date du trajet est passée
      String tripDateStr = tripData[FIELD_DATE] ?? '';
      String tripTimeStr = tripData[FIELD_HEURE] ?? '00:00';

      if (tripDateStr.isEmpty) return;

      // Parser la date au format français (DD/MM/YYYY)
      List<String> dateParts = tripDateStr.split('/');
      if (dateParts.length != 3) return;

      DateTime? tripDateTime;
      try {
        int day = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int year = int.parse(dateParts[2]);

        // Parser l'heure (HH:MM)
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

      // Si la date et l'heure du trajet sont passées et le statut est toujours
      // 'En attente', 'En route', 'Bloqué' ou 'Completé'
      // Modification ici: on vérifie maintenant si la date actuelle est simplement après la date du trajet
      if (now.isAfter(tripDateTime) &&
          [
            STATUS_EN_ATTENTE,
            STATUS_EN_ROUTE,
            STATUS_BLOQUE,
            STATUS_COMPLETE,
          ].contains(currentStatus)) {
        // Mettre à jour automatiquement le statut à 'Terminé'
        await _firestore.collection('trips').doc(widget.tripId).update({
          FIELD_STATUS: STATUS_TERMINE,
        });

        // La mise à jour sera automatiquement captée par le listener
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

      // La mise à jour sera automatiquement captée par le listener
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
      // Mettre à jour avec la raison d'annulation
      await _firestore.collection('trips').doc(widget.tripId).update({
        FIELD_STATUS: newStatus,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // La mise à jour sera automatiquement captée par le listener
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

  void _navigateToPassengerInfo(Map<String, dynamic> passenger) {
    // Cette fonction sera implémentée ultérieurement
    print("Navigation vers les détails du passager: ${passenger['id']}");

    // Afficher un message temporaire
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Détails du passager: ${passenger['prenom']} ${passenger['nom']}',
          ),
        ),
      );
    }
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

    // Nettoyer le numéro de téléphone (enlever les espaces et caractères spéciaux)
    String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');

    try {
      // Construire l'URI avec le préfixe tel:
      final Uri launchUri = Uri.parse('tel:$cleanPhoneNumber');

      print("Tentative d'appel: $launchUri"); // Pour déboguer

      // Lancer l'URI directement, sans vérification préalable
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

    // Ne pas afficher de boutons si le trajet est déjà terminé ou annulé
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
            // Afficher le bouton "Commencer" pour les trajets complets ou bloqués
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

            // Afficher le bouton "Terminer" uniquement si le trajet est en route
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

            // N'afficher le bouton "Bloquer" que pour les trajets en attente (mais pas pour les trajets completés)
            // Ne pas l'afficher si le trajet est déjà bloqué
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

            // Le bouton "Annuler" est disponible sauf si déjà annulé/terminé§en route
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

    // Return a badge widget
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

    var totalPlaces = _tripData![FIELD_PLACES] ?? 0;
    var placesDisponibles = _tripData![FIELD_PLACES_DISPONIBLES] ?? totalPlaces;

    // Calculer les places réservées
    var reservedPlaces = totalPlaces - placesDisponibles;
    // S'assurer que les valeurs ne sont pas négatives
    if (reservedPlaces < 0) reservedPlaces = 0;

    return _infoRow(
      Icons.airline_seat_recline_normal,
      'Places',
      "$reservedPlaces / $totalPlaces réservées",
    );
  }

  Widget _buildRefreshButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Actualiser les données'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            // Recharger manuellement les données
            _loadTripDetails();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Actualisation des données...')),
              );
            }
          },
        ),
      ),
    );
  }

  // Widget pour afficher l'état de la connexion en temps réel
  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            _listenerSetupComplete
                ? Colors.green.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _listenerSetupComplete ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _listenerSetupComplete ? Icons.sync : Icons.sync_disabled,
            size: 16,
            color: _listenerSetupComplete ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            _listenerSetupComplete ? "Synchronisé" : "Mode hors ligne",
            style: TextStyle(
              fontSize: 12,
              color: _listenerSetupComplete ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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

    // Variables pour les données du trajet
    final String depart = _tripData![FIELD_DEPART] ?? 'Non spécifié';
    final String arrivee = _tripData![FIELD_ARRIVEE] ?? 'Non spécifié';
    final String date = _tripData![FIELD_DATE] ?? 'Non spécifié';
    final String heure = _tripData![FIELD_HEURE] ?? 'Non spécifié';
    final String prix =
        '${_tripData![FIELD_PRIX]?.toString() ?? 'Non spécifié'} DA';
    final int placesTotal = _tripData![FIELD_PLACES] ?? 0;
    final int placesDispo = _tripData![FIELD_PLACES_DISPONIBLES] ?? placesTotal;
    final String description =
        _tripData![FIELD_DESCRIPTION] ?? 'Aucune description';
    final String vehicle = _tripData![FIELD_VEHICLE] ?? 'Non spécifié';
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
              // En-tête avec statut
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

              // Informations principales du trajet
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

              // Information sur l'annulation si le trajet est annulé
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

              // Description et véhicule
              if (description.isNotEmpty)
                _infoRow(Icons.description, 'Description', description),
              if (description.isNotEmpty) const SizedBox(height: 16),

              // Par celle-ci
              const SizedBox(height: 16),
              _buildVehicleWidget(),

              // Liste des passagers
              const SizedBox(height: 24),
              _buildPassengersList(),

              // Boutons d'action
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
