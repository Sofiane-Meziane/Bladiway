import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'confirmationPage.dart';
import 'info_conducteur.dart';

final user = FirebaseAuth.instance.currentUser;

class TripResultsPage extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;
  final int requiredSeats;

  const TripResultsPage({
    Key? key,
    required this.trips,
    required this.requiredSeats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BladiWay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Les trajets disponibles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
      body:
          trips.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.search_off, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucun trajet disponible',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index].data() as Map<String, dynamic>;
                  return _buildTripCard(context, trip, trips[index].id);
                },
              ),
    );
  }

  bool _isTripPast(String tripDate, String tripTime) {
    try {
      final now = DateTime.now();
      final dateParts = tripDate.split('/');
      if (dateParts.length != 3) return false;

      final day = int.tryParse(dateParts[0]) ?? 1;
      final month = int.tryParse(dateParts[1]) ?? 1;
      final year = int.tryParse(dateParts[2]) ?? 2025;

      final timeParts = tripTime.split(':');
      if (timeParts.length != 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final tripDateTime = DateTime(year, month, day, hour, minute);
      return tripDateTime.isBefore(now);
    } catch (e) {
      print("Erreur lors de la vérification de la date: $e");
      return false;
    }
  }

  Widget _buildTripCard(
    BuildContext context,
    Map<String, dynamic> trip,
    String tripId,
  ) {
    bool isPast = _isTripPast(trip['date'], trip['heure']);

    return GestureDetector(
      onTap: () => _navigateToTripDetail(context, trip, tripId),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo du conducteur (cliquable)
              GestureDetector(
                onTap:
                    () => _navigateToInfoConducteur(
                      context,
                      trip['userId'],
                      tripId,
                    ),
                child: StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(trip['userId'])
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200],
                        child: const CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200],
                        child: const Icon(Icons.person, color: Colors.blue),
                      );
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final profileImageUrl = userData['profileImageUrl'];

                    return CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage:
                          profileImageUrl != null
                              ? NetworkImage(profileImageUrl)
                              : null,
                      child:
                          profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.blue)
                              : null,
                    );
                  },
                ),
              ),

              const SizedBox(width: 15),

              // Informations du trajet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Villes de départ et d'arrivée
                    Row(
                      children: [
                        // Ville de départ
                        Text(
                          _extractCity(trip['départ']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // Icône de direction
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),

                        // Ville d'arrivée
                        Text(
                          _extractCity(trip['arrivée']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Date et heure
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip['date']} à ${trip['heure']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Prix
                    Text(
                      'Prix: ${(trip['prix'] is double) ? trip['prix'].toStringAsFixed(0) : trip['prix']} DA',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Menu d'options (trois points)
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showTripOptions(context, trip, tripId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Méthode pour extraire juste le nom de la ville
  String _extractCity(String address) {
    if (address.contains(',')) {
      return address.split(',')[0].trim();
    }
    return address;
  }

  // Navigation vers la page détaillée du trajet
  void _navigateToTripDetail(
    BuildContext context,
    Map<String, dynamic> trip,
    String tripId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TripDetailPage(
              trip: trip,
              tripId: tripId,
              requiredSeats: requiredSeats,
            ),
      ),
    );
  }

  // Affiche les options pour le trajet (menu trois points)
  void _showTripOptions(
    BuildContext context,
    Map<String, dynamic> trip,
    String tripId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('Voir les détails'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToTripDetail(context, trip, tripId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: const Text('Informations conducteur'),
                onTap: () {
                  Navigator.pop(context);
                  _showDriverInfo(context, trip['userId'], tripId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDriverInfo(
    BuildContext context,
    String driverId,
    String reservationId,
  ) {
    _navigateToInfoConducteur(context, driverId, reservationId);
  }

  // Nouvelle méthode pour naviguer vers la page InfoConducteurPage
  void _navigateToInfoConducteur(
    BuildContext context,
    String driverId,
    String reservationId,
  ) async {
    // Afficher un loader pendant la récupération de l'ID de réservation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous devez être connecté pour voir les détails du conducteur",
            ),
          ),
        );
        return;
      }

      // On navigue vers la page InfoConducteurPage avec les paramètres requis
      Navigator.pop(context); // Fermer le loader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InfoConducteurPage(
                conductorId: driverId,
                reservationId:
                    reservationId, // Peut être vide si pas encore de réservation
                currentUserId: currentUser.uid,
              ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Fermer le loader en cas d'erreur
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }
}

// Page de détails d'un trajet
class TripDetailPage extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String tripId;
  final int requiredSeats;

  const TripDetailPage({
    Key? key,
    required this.trip,
    required this.tripId,
    required this.requiredSeats,
  }) : super(key: key);

  // Méthode pour naviguer vers la page InfoConducteurPage
  void _showDriverInfo(BuildContext context, String driverId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous devez être connecté pour voir les détails du conducteur",
            ),
          ),
        );
        return;
      }

      Navigator.pop(context); // Fermer le loader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InfoConducteurPage(
                conductorId: driverId,
                reservationId: tripId,
                currentUserId: currentUser.uid,
              ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Fermer le loader en cas d'erreur
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPast = _isTripPast(trip['date'], trip['heure']);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Fond d'en-tête avec dégradé
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                // En-tête avec titre et boutons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Bladiway',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.white),
                            onPressed: () async {
                              final userDoc =
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(trip['userId'])
                                      .get();
                              if (userDoc.exists) {
                                final userData =
                                    userDoc.data() as Map<String, dynamic>;
                                final phoneNumber =
                                    userData['phone'] as String?;
                                if (phoneNumber != null) {
                                  final url = 'tel:$phoneNumber';
                                  if (await canLaunch(url)) {
                                    await launch(url);
                                  }
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                            onPressed:
                                () => _showDriverInfo(context, trip['userId']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Carte du profil du conducteur
                FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(trip['userId'])
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text(
                          "Erreur: données du conducteur non disponibles",
                        ),
                      );
                    }

                    final conductorData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final isValidated =
                        conductorData['isValidated'] as bool? ?? false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => _showDriverInfo(context, trip['userId']),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  backgroundImage:
                                      conductorData['profileImageUrl'] != null
                                          ? NetworkImage(
                                            conductorData['profileImageUrl'],
                                          )
                                          : null,
                                  child:
                                      conductorData['profileImageUrl'] == null
                                          ? const Icon(Icons.person, size: 40)
                                          : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${conductorData['prenom']} ${conductorData['nom']}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      FutureBuilder<QuerySnapshot>(
                                        future:
                                            FirebaseFirestore.instance
                                                .collection('reviews')
                                                .where(
                                                  'ratedUserId',
                                                  isEqualTo: trip['userId'],
                                                )
                                                .get(),
                                        builder: (context, reviewsSnapshot) {
                                          if (reviewsSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.grey,
                                                  size: 18,
                                                ),
                                                Text(
                                                  ' Chargement...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                          double rating = 0;
                                          int reviewCount = 0;
                                          if (reviewsSnapshot.hasData &&
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
                                                in reviewsSnapshot.data!.docs) {
                                              final reviewData =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              totalRating +=
                                                  (reviewData['rating']
                                                              as num? ??
                                                          0)
                                                      .toDouble();
                                            }
                                            rating = totalRating / reviewCount;
                                          }
                                          return Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 18,
                                              ),
                                              Text(
                                                ' ${rating.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '($reviewCount avis)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      // Afficher le label "Vérifié" uniquement si isValidated est true
                                      if (isValidated)
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.verified,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Vérifié',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Contenu principal
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTripInfo(
                            context,
                            trip['départ'],
                            trip['arrivée'],
                            trip['date'],
                            trip['heure'],
                          ),
                          const SizedBox(height: 20),
                          _buildTripDetails(context, trip),
                          const SizedBox(height: 20),
                          _buildCarInfo(context, trip),
                          const SizedBox(height: 20),
                          _buildPriceBreakdown(
                            context,
                            requiredSeats,
                            trip['prix'] as num? ?? 0,
                            (trip['prix'] as num? ?? 0) * requiredSeats,
                          ),
                          const SizedBox(height: 24),
                          if (isPast)
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.red),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Ce trajet est déjà passé et ne peut pas être réservé',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('RÉSERVER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed:
                    isPast ? null : () => _showReservationDialog(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('ANNULER'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTripPast(String tripDate, String tripTime) {
    try {
      final now = DateTime.now();
      final dateParts = tripDate.split('/');
      if (dateParts.length != 3) return false;

      final day = int.tryParse(dateParts[0]) ?? 1;
      final month = int.tryParse(dateParts[1]) ?? 1;
      final year = int.tryParse(dateParts[2]) ?? 2025;

      final timeParts = tripTime.split(':');
      if (timeParts.length != 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final tripDateTime = DateTime(year, month, day, hour, minute);
      return tripDateTime.isBefore(now);
    } catch (e) {
      print("Erreur lors de la vérification de la date: $e");
      return false;
    }
  }

  void _showReservationDialog(BuildContext context) {
    // Récupérer les places disponibles
    final int availableSeats =
        trip['placesDisponibles'] is int
            ? trip['placesDisponibles']
            : int.tryParse(trip['placesDisponibles']?.toString() ?? '') ??
                (trip['nbrPlaces'] is int
                    ? trip['nbrPlaces']
                    : int.tryParse(trip['nbrPlaces']?.toString() ?? '') ?? 0);

    if (availableSeats < requiredSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Pas assez de places disponibles. Il reste $availableSeats place(s).",
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la réservation'),
            content: Text(
              'Voulez-vous réserver ce trajet pour $requiredSeats place(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Afficher un indicateur de chargement
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  // Vérifier la disponibilité et le statut du trajet en temps réel
                  final updatedTripSnapshot =
                      await FirebaseFirestore.instance
                          .collection('trips')
                          .doc(tripId)
                          .get();

                  Navigator.pop(context); // Fermer le loader
                  Navigator.pop(context);

                  final updatedTrip = updatedTripSnapshot.data();

                  if (updatedTrip != null &&
                      updatedTrip['status'] == 'en attente' &&
                      updatedTrip['placesDisponibles'] >= requiredSeats) {
                    _reserveTrip(context, updatedTrip);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Votre réservation a été refusée. Ce trajet n\'est plus disponible ou n\'a pas assez de places.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Confirmer'),
              ),
            ],
          ),
    );
  }

  void _reserveTrip(
    BuildContext context,
    Map<String, dynamic> updatedTrip,
  ) async {
    // Vérifier une dernière fois si le trajet est passé
    if (_isTripPast(updatedTrip['date'], updatedTrip['heure'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ce trajet est déjà passé et ne peut pas être réservé.",
          ),
        ),
      );
      return;
    }

    // Stocker une référence au BuildContext de navigation
    final NavigatorState navigator = Navigator.of(context);
    bool reservationSuccess = false;

    try {
      // Récupérer les places disponibles
      int availableSeats =
          updatedTrip['placesDisponibles'] is int
              ? updatedTrip['placesDisponibles']
              : int.tryParse(
                    updatedTrip['placesDisponibles']?.toString() ?? '',
                  ) ??
                  (updatedTrip['nbrPlaces'] is int
                      ? updatedTrip['nbrPlaces']
                      : int.tryParse(
                            updatedTrip['nbrPlaces']?.toString() ?? '',
                          ) ??
                          0);

      if (availableSeats >= requiredSeats) {
        // Vérifier que l'utilisateur est connecté
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vous devez être connecté pour réserver."),
            ),
          );
          return;
        }

        // Mettre à jour le document trip avec les places restantes
        await FirebaseFirestore.instance.collection('trips').doc(tripId).update(
          {'placesDisponibles': availableSeats - requiredSeats},
        );

        // Si après cette réservation, il ne reste plus de places disponibles, mettre à jour le statut
        if (availableSeats - requiredSeats == 0) {
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .update({'status': 'completé'});
        }

        // Créer une nouvelle réservation avec tous les champs requis
        await FirebaseFirestore.instance.collection('reservations').add({
          'tripId': tripId,
          'userId': currentUser.uid,
          'seatsReserved': requiredSeats,
          'date_reservation': Timestamp.now(),
        });

        // Marquer la réservation comme réussie
        reservationSuccess = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Pas assez de places disponibles. Il reste $availableSeats place(s).",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la réservation: $e")),
      );
    }

    // Naviguer vers la page de confirmation uniquement si la réservation a réussi
    if (reservationSuccess) {
      navigator.pop(context); // Fermer la boîte de dialogue
      navigator.push(
        MaterialPageRoute(builder: (context) => ConfirmationPage()),
      );
    }
  }

  void _showTripDetails(BuildContext context, String tripId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Récupérer les détails supplémentaires du trajet depuis Firestore
      final tripDoc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .get();

      Navigator.pop(context); // Fermer le loader

      if (!tripDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Les détails du trajet ne sont pas disponibles."),
          ),
        );
        return;
      }

      final tripData = tripDoc.data() as Map<String, dynamic>;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails supplémentaires',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Afficher les champs que vous avez dans l'image
                  _buildDetailRow(
                    Icons.pets,
                    'Animaux',
                    tripData['animal'] ?? 'Non spécifié',
                  ),

                  _buildDetailRow(
                    Icons.luggage,
                    'Bagages',
                    tripData['bagage'] ?? 'Non spécifié',
                  ),
                  _buildDetailRow(
                    Icons.air,
                    'Climatisation',
                    tripData['climatisation'] ?? 'Non spécifié',
                  ),
                  _buildDetailRow(
                    Icons.smoking_rooms,
                    'Fumer',
                    tripData['fumer'] ?? 'Non spécifié',
                  ),
                  _buildDetailRow(
                    Icons.payment,
                    'Méthode de paiement',
                    tripData['méthodePaiement'] ?? 'Non spécifié',
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      Navigator.pop(context); // Fermer le loader en cas d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la récupération des informations: $e"),
        ),
      );
    }
  }

  // Fonction d'aide pour formater les timestamps
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Non spécifié';

    try {
      if (timestamp is Timestamp) {
        final DateTime dateTime = timestamp.toDate();
        return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
      } else {
        return timestamp.toString();
      }
    } catch (e) {
      return 'Date invalide';
    }
  }

  // Fonction d'aide pour construire chaque ligne de détail
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
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
                    fontSize: 14,
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfo(
    BuildContext context,
    String depart,
    String arrivee,
    String date,
    String heure,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Détails du trajet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: Colors.blue.withOpacity(0.5),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        depart,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Point de départ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        arrivee,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Destination',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.calendar_today, date, 'Date'),
                _buildInfoItem(Icons.access_time, heure, 'Heure'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetails(
    BuildContext context,
    Map<String, dynamic> tripData,
  ) {
    final description =
        tripData['description'] as String? ?? 'Aucune description disponible';
    final bagage = tripData['bagage'] as String? ?? 'Non Autorisé';
    final climatisation =
        tripData['climatisation'] as String? ?? 'Non Autorisé';
    final fumer = tripData['fumer'] as String? ?? 'Non Autorisé';
    final animal = tripData['animal'] as String? ?? 'Non Autorisé';
    // Ajout du champ typePassagers
    final typePassagers = tripData['typePassagers'] as String? ?? 'Mixte';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations supplémentaires',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(description),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                ), // Limite la largeur maximale
                child: Wrap(
                  spacing: 30,
                  runSpacing: 16,
                  alignment:
                      WrapAlignment
                          .spaceEvenly, // Répartit l'espace uniformément
                  children: [
                    _buildFeatureItem(
                      icon: Icons.work_outline,
                      label: 'Bagage',
                      value: bagage,
                    ),
                    _buildFeatureItem(
                      icon: Icons.ac_unit,
                      label: 'Climatisation',
                      value: climatisation,
                    ),
                    _buildFeatureItem(
                      icon: Icons.smoking_rooms,
                      label: 'Fumeur',
                      value: fumer,
                    ),
                    _buildFeatureItem(
                      icon: Icons.pets,
                      label: 'Animal',
                      value: animal,
                    ),
                    // Ajout du typePassagers
                    _buildFeatureItem(
                      icon: Icons.people,
                      label: 'Passagers',
                      value: typePassagers,
                      isPassengerType: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String value,
    bool isPassengerType = false,
  }) {
    // Pour les éléments standards (bagage, climatisation, etc.)
    final isAuthorized = value == 'Autorisé';

    // Pour le type de passagers, on utilise une logique différente
    Color iconColor;
    Color textColor;
    Color bgColor;

    if (isPassengerType) {
      // Couleurs spécifiques pour le type de passagers
      switch (value) {
        case 'Femmes':
          iconColor = Colors.pink;
          textColor = Colors.pink;
          bgColor = Colors.pink.withOpacity(0.1);
          break;
        case 'Hommes':
          iconColor = Colors.blue;
          textColor = Colors.blue;
          bgColor = Colors.blue.withOpacity(0.1);
          break;
        case 'Mixte':
        default:
          iconColor = Colors.purple;
          textColor = Colors.purple;
          bgColor = Colors.purple.withOpacity(0.1);
          break;
      }

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Logique originale pour les autres attributs
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isAuthorized
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isAuthorized ? Colors.blue : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isAuthorized ? Colors.black87 : Colors.grey,
            ),
          ),
          Text(
            isAuthorized ? 'Autorisé' : 'Non Autorisé',
            style: TextStyle(
              fontSize: 12,
              color: isAuthorized ? Colors.green : Colors.red,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCarInfo(BuildContext context, Map<String, dynamic> tripData) {
    final vehicleId = tripData['vehiculeId'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Véhicule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<DocumentSnapshot>(
              future:
                  vehicleId != null
                      ? FirebaseFirestore.instance
                          .collection('cars')
                          .doc(vehicleId)
                          .get()
                      : Future.value(null),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return Row(
                    children: [
                      Container(
                        width: 100,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Erreur',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Impossible de charger les infos du véhicule',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final carData = snapshot.data!.data() as Map<String, dynamic>;
                final imageUrl = carData['imageUrl'] as String?;
                final model = carData['model'] as String? ?? 'Modèle inconnu';
                final make = carData['make'] as String? ?? 'Marque inconnue';
                final plate =
                    carData['plate'] as String? ?? 'Matricule inconnu';
                final color = carData['color'] as String? ?? 'Non spécifié';

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image:
                            imageUrl != null
                                ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          imageUrl == null
                              ? const Icon(
                                Icons.directions_car,
                                color: Colors.grey,
                                size: 60,
                              )
                              : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car_outlined,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$make $model',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.palette_outlined,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Couleur: $color',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.credit_card_outlined,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Matricule: $plate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown(
    BuildContext context,
    int seatsReserved,
    num pricePerSeat,
    num totalPrice,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Détails du prix',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.airline_seat_recline_normal,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$seatsReserved ${seatsReserved > 1 ? 'places' : 'place'}',
                    ),
                  ],
                ),
                Text(
                  '${(pricePerSeat * seatsReserved).toStringAsFixed(0)} DA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à payer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${totalPrice.toStringAsFixed(0)} DA',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
