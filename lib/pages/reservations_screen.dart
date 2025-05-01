import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart'; // Import du service de notification
import 'chat_screen.dart'; // Import de la page de chat
import 'info_trajets.dart'; // Import de la page d'informations sur le conducteur

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  _ReservationsScreenState createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final int _selectedIndex =
      1; // Set to 1 since this is the reservations screen
  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      String route = '';
      switch (index) {
        case 0:
          route = '/home';
          break;
        case 1:
          route = '/reservations';
          break;
        case 2:
          route = '/trips';
          break;
        case 3:
          route = '/settings';
          break;
      }
      if (route.isNotEmpty) {
        Navigator.pushReplacementNamed(context, route);
      }
    }
  }

  void _showModifySeatsDialog(
    BuildContext context,
    String reservationId,
    int currentSeats,
    String tripId,
  ) async {
    final TextEditingController seatsController = TextEditingController(
      text: currentSeats.toString(),
    );

    DocumentSnapshot tripDoc =
        await FirebaseFirestore.instance.collection('trips').doc(tripId).get();

    if (!tripDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Impossible de trouver le trajet'),
        ),
      );
      return;
    }

    final tripData = tripDoc.data() as Map<String, dynamic>;
    final int placesDisponibles = tripData['nbrPlaces'] as int? ?? 0;
    final int placesDisponiblesTotal = placesDisponibles + currentSeats;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Modifier le nombre de places'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: seatsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de places',
                    hintText: 'Entrez le nouveau nombre de places',
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newSeats = int.tryParse(seatsController.text);
                  if (newSeats == null || newSeats <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Veuillez entrer un nombre valide de places (> 0)',
                        ),
                      ),
                    );
                  } else if (newSeats > placesDisponiblesTotal) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Le nombre de places que vous avez saisi est indisponible',
                        ),
                      ),
                    );
                  } else {
                    _updateSeatsReservation(
                      reservationId,
                      newSeats,
                      tripId,
                      currentSeats,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Confirmer'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateSeatsReservation(
    String reservationId,
    int newSeats,
    String tripId,
    int currentSeats,
  ) async {
    try {
      // Récupérer les informations du trajet et du passager pour la notification
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final tripDoc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .get();
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!tripDoc.exists || !userDoc.exists) {
        throw Exception('Données du trajet ou de l\'utilisateur non trouvées');
      }

      final tripData = tripDoc.data() as Map<String, dynamic>;
      final userData = userDoc.data() as Map<String, dynamic>;

      final driverId = tripData['userId'] as String?;
      final destination = tripData['arrivée'] as String? ?? 'destination';
      final date = tripData['date'] as String? ?? 'date non spécifiée';
      final passengerName =
          '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'.trim();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId);
        DocumentSnapshot tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) {
          throw Exception('Trajet non trouvé');
        }

        int diff = currentSeats - newSeats;
        Map<String, dynamic> tripData =
            tripSnapshot.data() as Map<String, dynamic>;

        int totalPlaces =
            tripData['nbrPlaces'] is int
                ? tripData['nbrPlaces']
                : int.tryParse(tripData['nbrPlaces'].toString()) ?? 0;

        int placesDisponibles =
            tripData['placesDisponibles'] is int
                ? tripData['placesDisponibles']
                : int.tryParse(tripData['placesDisponibles'].toString()) ??
                    totalPlaces;

        int newPlacesDisponibles = placesDisponibles + diff;

        if (newPlacesDisponibles < 0) {
          throw Exception('Pas assez de places disponibles');
        }

        DocumentReference reservationRef = FirebaseFirestore.instance
            .collection('reservations')
            .doc(reservationId);

        // Mettre à jour d'abord le nombre de places réservées et disponibles
        transaction.update(reservationRef, {'seatsReserved': newSeats});
        transaction.update(tripRef, {
          'placesDisponibles': newPlacesDisponibles,
        });

        // Ensuite, mettre à jour le statut en fonction du nombre de places disponibles
        if (newPlacesDisponibles == 0) {
          transaction.update(tripRef, {'status': 'completé'});
        } else if (tripData['status'] == 'completé' &&
            newPlacesDisponibles > 0) {
          transaction.update(tripRef, {'status': 'en attente'});
        }
      });

      // Envoyer une notification au conducteur
      if (driverId != null && driverId != currentUser.uid) {
        await NotificationService.createSeatsModificationNotification(
          driverId: driverId,
          passengerId: currentUser.uid,
          passengerName: passengerName,
          tripId: tripId,
          tripDestination: destination,
          tripDate: date,
          oldSeatsCount: currentSeats,
          newSeatsCount: newSeats,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre de places mis à jour avec succès'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              ClipPath(
                clipper: HeaderClipper(),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Mes Réservations',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Icon(
                      Icons.notifications_none,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('reservations')
                      .where('userId', isEqualTo: user?.uid)
                      .orderBy('date_reservation', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Une erreur s\'est produite',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 60,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune réservation pour l\'instant',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos réservations apparaîtront ici',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reservations = snapshot.data!.docs;

                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ListView.builder(
                    itemCount: reservations.length,
                    itemBuilder: (context, index) {
                      final reservationDoc = reservations[index];
                      final reservation =
                          reservationDoc.data() as Map<String, dynamic>;
                      final seatsReserved = reservation['seatsReserved'];
                      final tripId = reservation['tripId'] as String?;
                      final reservationId = reservationDoc.id;

                      if (tripId == null) {
                        return _buildErrorCard(
                          context,
                          'ID de trajet manquant',
                          theme,
                        );
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('trips')
                                .doc(tripId)
                                .get(),
                        builder: (context, tripSnapshot) {
                          if (tripSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingCard(context, theme);
                          }
                          if (tripSnapshot.hasError) {
                            return _buildErrorCard(
                              context,
                              'Erreur: ${tripSnapshot.error}',
                              theme,
                            );
                          }
                          if (!tripSnapshot.hasData ||
                              !tripSnapshot.data!.exists) {
                            return _buildErrorCard(
                              context,
                              'Trajet non trouvé',
                              theme,
                            );
                          }

                          final tripData =
                              tripSnapshot.data!.data() as Map<String, dynamic>;
                          final date =
                              tripData['date'] as String? ?? 'Non spécifié';
                          final time =
                              tripData['heure'] as String? ?? 'Non spécifié';
                          final price = tripData['prix'] as num? ?? 0;
                          final depart =
                              tripData['départ'] as String? ?? 'Non spécifié';
                          final arrivee =
                              tripData['arrivée'] as String? ?? 'Non spécifié';
                          final status =
                              tripData['status'] as String? ?? 'En attente';
                          final addedBy = tripData['userId'] as String?;
                          final nbrPlaces = tripData['nbrPlaces'] as int? ?? 0;
                          final placesDisponibles =
                              tripData['placesDisponibles'] as int? ??
                              nbrPlaces;

                          if (addedBy == null) {
                            return _buildErrorCard(
                              context,
                              'Informations utilisateur manquantes',
                              theme,
                            );
                          }

                          return FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(addedBy)
                                    .get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return _buildLoadingCard(context, theme);
                              }
                              if (userSnapshot.hasError) {
                                return _buildErrorCard(
                                  context,
                                  'Erreur: ${userSnapshot.error}',
                                  theme,
                                );
                              }
                              if (!userSnapshot.hasData ||
                                  !userSnapshot.data!.exists) {
                                return _buildErrorCard(
                                  context,
                                  'Utilisateur non trouvé',
                                  theme,
                                );
                              }

                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>;
                              final nom =
                                  userData['nom'] as String? ?? 'Inconnu';
                              final prenom =
                                  userData['prenom'] as String? ?? 'Inconnu';
                              final profileImageUrl =
                                  userData['profileImageUrl'] as String?;
                              final phoneNumber =
                                  userData['phone'] as String? ??
                                  'Non disponible';

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => InfoConducteur(
                                              reservation: reservationDoc,
                                              trip: tripSnapshot.data!,
                                              conductor: userSnapshot.data!,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              backgroundImage:
                                                  profileImageUrl != null
                                                      ? NetworkImage(
                                                        profileImageUrl,
                                                      )
                                                      : null,
                                              child:
                                                  profileImageUrl == null
                                                      ? Icon(
                                                        Icons.person,
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .primary,
                                                      )
                                                      : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$prenom $nom',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .onSurface,
                                                    ),
                                                  ),
                                                  FutureBuilder<QuerySnapshot>(
                                                    future:
                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'reviews',
                                                            )
                                                            .where(
                                                              'ratedUserId',
                                                              isEqualTo:
                                                                  addedBy,
                                                            )
                                                            .get(),
                                                    builder: (
                                                      context,
                                                      reviewsSnapshot,
                                                    ) {
                                                      if (reviewsSnapshot
                                                              .connectionState ==
                                                          ConnectionState
                                                              .waiting) {
                                                        return Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.star,
                                                              color:
                                                                  Colors.grey,
                                                              size: 16,
                                                            ),
                                                            Text(
                                                              ' Chargement...',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }
                                                      double rating = 0;
                                                      int reviewCount = 0;
                                                      if (reviewsSnapshot
                                                              .hasData &&
                                                          reviewsSnapshot
                                                              .data!
                                                              .docs
                                                              .isNotEmpty) {
                                                        reviewCount =
                                                            reviewsSnapshot
                                                                .data!
                                                                .docs
                                                                .length;
                                                        double totalRating = 0;
                                                        for (var doc
                                                            in reviewsSnapshot
                                                                .data!
                                                                .docs) {
                                                          final reviewData =
                                                              doc.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >;
                                                          totalRating +=
                                                              (reviewData['rating']
                                                                          as num? ??
                                                                      0)
                                                                  .toDouble();
                                                        }
                                                        rating =
                                                            totalRating /
                                                            reviewCount;
                                                      }
                                                      return Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.star,
                                                            color: Colors.amber,
                                                            size: 16,
                                                          ),
                                                          Text(
                                                            ' ${rating.toStringAsFixed(1)} ($reviewCount avis)',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                    0.7,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  status,
                                                  theme,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Column(
                                                  children: [
                                                    Icon(
                                                      Icons.trip_origin,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                      size: 20,
                                                    ),
                                                    Container(
                                                      width: 2,
                                                      height: 25,
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.5),
                                                    ),
                                                    Icon(
                                                      Icons.location_on,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        depart,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      Text(
                                                        arrivee,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildInfoItem(
                                                  context,
                                                  Icons.calendar_today,
                                                  date,
                                                  'Date',
                                                  theme,
                                                ),
                                                _buildInfoItem(
                                                  context,
                                                  Icons.access_time,
                                                  time,
                                                  'Heure',
                                                  theme,
                                                ),
                                                _buildInfoItem(
                                                  context,
                                                  Icons.attach_money,
                                                  '${price.toStringAsFixed(0)} DA',
                                                  'Prix',
                                                  theme,
                                                ),
                                                Row(
                                                  children: [
                                                    _buildInfoItem(
                                                      context,
                                                      Icons.event_seat,
                                                      seatsReserved.toString(),
                                                      'Places',
                                                      theme,
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.edit,
                                                        color:
                                                            (status ==
                                                                        'terminé' ||
                                                                    status ==
                                                                        'annulé')
                                                                ? Colors.grey
                                                                : theme
                                                                    .colorScheme
                                                                    .primary,
                                                      ),
                                                      onPressed:
                                                          (status ==
                                                                      'terminé' ||
                                                                  status ==
                                                                      'annulé')
                                                              ? null
                                                              : () {
                                                                _showModifySeatsDialog(
                                                                  context,
                                                                  reservationId,
                                                                  seatsReserved,
                                                                  tripId,
                                                                );
                                                              },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child:
                                                  (status == 'terminé' ||
                                                          status == 'annulé')
                                                      ? Container() // Ne pas afficher les places disponibles si le trajet est terminé ou annulé
                                                      : Text(
                                                        'Places encore disponibles: $placesDisponibles',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .primary,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildActionButton(
                                              context,
                                              Icons.message,
                                              'Contacter',
                                              theme.colorScheme.primary,
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) => ChatPage(
                                                          reservationId:
                                                              reservationId,
                                                          otherUserId: addedBy,
                                                        ),
                                                  ),
                                                );
                                              },
                                              isContactButton: true,
                                              driverId: addedBy,
                                              reservationId: reservationId,
                                            ),
                                            _buildActionButton(
                                              context,
                                              Icons.phone,
                                              'Appeler',
                                              Colors.green,
                                              () async {
                                                if (phoneNumber !=
                                                    'Non disponible') {
                                                  final url =
                                                      'tel:$phoneNumber';
                                                  if (await canLaunch(url)) {
                                                    await launch(url);
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Impossible d\'ouvrir l\'application téléphonique',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Numéro de téléphone non disponible',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            status == 'terminé'
                                                ? Container() // Ne pas afficher le bouton d'annulation si le trajet est terminé
                                                : status == 'annulé'
                                                ? Container() // Ne pas afficher le bouton d'annulation si le trajet est annulé
                                                : _buildActionButton(
                                                  context,
                                                  Icons.cancel,
                                                  'Annuler',
                                                  Colors.red,
                                                  () {
                                                    _showCancelConfirmationDialog(
                                                      context,
                                                      reservationId,
                                                      tripId,
                                                      seatsReserved,
                                                    );
                                                  },
                                                ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Réservations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Mes trajets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    String message,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed, {
    bool isContactButton = false,
    String? driverId,
    String? reservationId,
  }) {
    if (isContactButton && driverId != null && reservationId != null) {
      final NotificationService notificationService = NotificationService();
      return Expanded(
        child: StreamBuilder<int>(
          stream: notificationService
              .getUnreadMessagesCountFromDriverForReservation(
                driverId,
                reservationId,
              ),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: color.withOpacity(0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 18),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color)),
                ],
              ),
            );
          },
        ),
      );
    }

    // Version standard sans badge
    return Expanded(
      child: TextButton.icon(
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color)),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'confirmé':
      case 'confirmée':
      case 'confirmé(e)':
      case 'confirmed':
        return Colors.green;
      case 'en attente':
      case 'pending':
        return Colors.orange;
      case 'annulé':
      case 'annulée':
      case 'annulé(e)':
      case 'cancelled':
        return Colors.red;
      case 'terminé':
      case 'terminée':
      case 'terminé(e)':
      case 'completed':
        return const Color.fromARGB(255, 8, 157, 18);
      default:
        return theme.colorScheme.primary;
    }
  }

  void _showCancelConfirmationDialog(
    BuildContext context,
    String reservationId,
    String tripId,
    dynamic seatsReserved,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer l\'annulation'),
          content: const Text(
            'Êtes-vous sûr de vouloir annuler cette réservation ?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Non',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Fermer le dialogue

                try {
                  // Récupération des informations pour la notification avant de supprimer la réservation
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;

                  // Récupérer les infos du trajet
                  final tripDoc =
                      await FirebaseFirestore.instance
                          .collection('trips')
                          .doc(tripId)
                          .get();

                  if (!tripDoc.exists) {
                    throw Exception('Trajet non trouvé');
                  }

                  final tripData = tripDoc.data() as Map<String, dynamic>;
                  final driverId = tripData['userId'] as String?;
                  final destination =
                      tripData['arrivée'] as String? ?? 'destination';
                  final date =
                      tripData['date'] as String? ?? 'date non spécifiée';

                  // Récupérer le nom du passager courant
                  final userDoc =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .get();

                  final userData = userDoc.data();
                  final passengerName =
                      userData != null
                          ? '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'
                          : 'Un passager';

                  await FirebaseFirestore.instance.runTransaction((
                    transaction,
                  ) async {
                    DocumentReference tripRef = FirebaseFirestore.instance
                        .collection('trips')
                        .doc(tripId);
                    DocumentSnapshot tripSnapshot = await transaction.get(
                      tripRef,
                    );

                    if (!tripSnapshot.exists) {
                      throw Exception('Trajet non trouvé');
                    }

                    Map<String, dynamic> tripData =
                        tripSnapshot.data() as Map<String, dynamic>;

                    int totalPlaces =
                        tripData['nbrPlaces'] is int
                            ? tripData['nbrPlaces']
                            : int.tryParse(tripData['nbrPlaces'].toString()) ??
                                0;

                    int placesDisponibles =
                        tripData['placesDisponibles'] is int
                            ? tripData['placesDisponibles']
                            : int.tryParse(
                                  tripData['placesDisponibles'].toString(),
                                ) ??
                                totalPlaces;

                    // Assurez-vous que seatsReserved est un int
                    int seats =
                        seatsReserved is int
                            ? seatsReserved
                            : (seatsReserved is num
                                ? seatsReserved.toInt()
                                : int.tryParse(seatsReserved.toString()) ?? 1);

                    int newPlacesDisponibles = placesDisponibles + seats;

                    // Mettre à jour d'abord le nombre de places disponibles
                    transaction.update(tripRef, {
                      'placesDisponibles': newPlacesDisponibles,
                    });

                    // Ensuite, mettre à jour le statut en fonction du nombre de places disponibles
                    if (newPlacesDisponibles == 0) {
                      transaction.update(tripRef, {'status': 'completé'});
                    } else if (tripData['status'] == 'completé' &&
                        newPlacesDisponibles > 0) {
                      transaction.update(tripRef, {'status': 'en attente'});
                    }

                    DocumentReference reservationRef = FirebaseFirestore
                        .instance
                        .collection('reservations')
                        .doc(reservationId);
                    transaction.delete(reservationRef);
                  });

                  // Après la transaction réussie, envoyer la notification au conducteur
                  if (driverId != null) {
                    await NotificationService.createCancellationNotification(
                      driverId: driverId,
                      passengerId: currentUser.uid,
                      passengerName: passengerName.trim(),
                      tripId: tripId,
                      tripDestination: destination,
                      tripDate: date,
                      seatsReserved:
                          seatsReserved is int
                              ? seatsReserved
                              : (seatsReserved is num
                                  ? seatsReserved.toInt()
                                  : int.tryParse(seatsReserved.toString()) ??
                                      1),
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Réservation annulée avec succès'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors de l\'annulation: $e')),
                  );
                }
              },
              child: const Text('Oui, annuler'),
            ),
          ],
        );
      },
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
