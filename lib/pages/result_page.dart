import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'confirmationPage.dart';
import 'info_conducteur.dart';
import '../widgets/trip_widgets.dart';
import '../services/notification_service.dart';

final user = FirebaseAuth.instance.currentUser;

class TripResultsPage extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;
  final int requiredSeats;

  const TripResultsPage({
    super.key,
    required this.trips,
    required this.requiredSeats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Les trajets disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index].data() as Map<String, dynamic>;

                  // Récupérer le nombre de places disponibles
                  final placesDisponibles =
                      trip['placesDisponibles'] is int
                          ? trip['placesDisponibles']
                          : int.tryParse(
                                trip['placesDisponibles']?.toString() ?? '',
                              ) ??
                              (trip['nbrPlaces'] is int
                                  ? trip['nbrPlaces']
                                  : int.tryParse(
                                        trip['nbrPlaces']?.toString() ?? '',
                                      ) ??
                                      0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ModifiedTripCard(
                      trip: trip,
                      tripId: trips[index].id,
                      placesDisponibles: placesDisponibles,
                      onTap:
                          () => _navigateToTripDetail(
                            context,
                            trip,
                            trips[index].id,
                          ),
                      onDriverTap:
                          () => _navigateToInfoConducteur(
                            context,
                            trip['userId'],
                            trips[index].id,
                          ),
                    ),
                  );
                },
              ),
    );
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

// Nouveau widget pour afficher les trajets avec le nombre de places disponibles
class ModifiedTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String tripId;
  final int placesDisponibles;
  final void Function()? onTap;
  final void Function()? onDriverTap;

  const ModifiedTripCard({
    super.key,
    required this.trip,
    required this.tripId,
    required this.placesDisponibles,
    this.onTap,
    this.onDriverTap,
  });

  String _extractCity(String address) {
    if (address.contains(',')) {
      return address.split(',')[0].trim();
    }
    return address;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isPast = _isTripPast(trip['date'], trip['heure']);

    return GestureDetector(
      onTap: isPast ? null : onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isPast
                    ? Border.all(color: Colors.red.withOpacity(0.5), width: 1.5)
                    : null,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onDriverTap,
                      child: StreamBuilder(
                        stream:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(trip['userId'])
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[200],
                              child: const CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[200],
                              child: const Icon(
                                Icons.person,
                                color: Colors.blue,
                                size: 32,
                              ),
                            );
                          }
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final profileImageUrl = userData['profileImageUrl'];

                          // Vérifier si le conducteur est validé
                          final isValidated =
                              userData['isValidated'] as bool? ?? false;

                          return Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.1),
                                backgroundImage:
                                    profileImageUrl != null
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                child:
                                    profileImageUrl == null
                                        ? const Icon(
                                          Icons.person,
                                          color: Colors.blue,
                                          size: 32,
                                        )
                                        : null,
                              ),
                              if (isValidated)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Itinéraire
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _extractCity(trip['départ']),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _extractCity(trip['arrivée']),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
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

                          const SizedBox(height: 6),

                          // Caractéristiques du trajet
                          Row(
                            children: [
                              // Climatisation
                              if (trip['climatisation'] == 'Autorisé')
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.ac_unit,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),

                              // Bagages
                              if (trip['bagage'] == 'Autorisé')
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.luggage,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),

                              // Type de passagers
                              if (trip['typePassagers'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    trip['typePassagers'] == 'Femmes'
                                        ? Icons.female
                                        : trip['typePassagers'] == 'Hommes'
                                        ? Icons.male
                                        : Icons.people,
                                    size: 16,
                                    color:
                                        trip['typePassagers'] == 'Femmes'
                                            ? Colors.pink
                                            : trip['typePassagers'] == 'Hommes'
                                            ? Colors.blue
                                            : Colors.purple,
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

              // Section inférieure avec prix et places disponibles
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Prix
                    Text(
                      '${(trip['prix'] is double) ? trip['prix'].toStringAsFixed(0) : trip['prix']} DA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    // Places disponibles
                    Row(
                      children: [
                        const Icon(
                          Icons.airline_seat_recline_normal,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$placesDisponibles ${placesDisponibles > 1 ? 'places disponibles' : 'place disponible'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                placesDisponibles > 0
                                    ? Colors.black87
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Afficher un indicateur si le trajet est passé
              if (isPast)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'Ce trajet est déjà passé',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
}

// Page de détails d'un trajet
class TripDetailPage extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String tripId;
  final int requiredSeats;

  const TripDetailPage({
    super.key,
    required this.trip,
    required this.tripId,
    required this.requiredSeats,
  });

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
                          TripInfoCard(
                            depart: trip['départ'],
                            arrivee: trip['arrivée'],
                            date: trip['date'],
                            heure: trip['heure'],
                          ),
                          const SizedBox(height: 20),
                          TripDetailsCard(tripData: trip),
                          const SizedBox(height: 20),
                          CarInfoCard(tripData: trip),
                          const SizedBox(height: 20),
                          PriceBreakdownCard(
                            seatsReserved: requiredSeats,
                            pricePerSeat: trip['prix'] as num? ?? 0,
                            totalPrice:
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
                    isPast ? null : () => _checkReservationPermission(context),
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

  Future<void> _checkReservationPermission(BuildContext context) async {
    // Récupérer l'instance de FirebaseAuth
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    User? user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour continuer'),
        ),
      );
      return;
    }

    try {
      QuerySnapshot piecesSnapshot =
          await firestore
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .get();

      final pieces =
          piecesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

      bool hasVerifiedID = pieces.any((piece) => piece['statut'] == 'verifie');

      if (hasVerifiedID) {
        // Si l'utilisateur a une pièce vérifiée, on peut afficher le dialogue de réservation
        _showReservationDialog(context);
      } else {
        // Si l'utilisateur n'a pas de pièce vérifiée, on le redirige vers la page verifier_passager
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vous devez faire vérifier votre pièce d\'identité avant de pouvoir réserver',
            ),
            duration: Duration(seconds: 3),
          ),
        );

        // Naviguer vers la page verifier_passager
        Navigator.pushNamed(context, '/verifier_Passager');
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la vérification')),
      );
    }
  }

  void _showReservationDialog(BuildContext context) async {
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

        // Obtenir les informations du passager pour la notification
        final passengerDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        final passengerData = passengerDoc.data();
        final passengerName =
            passengerData != null
                ? '${passengerData['prenom']} ${passengerData['nom']}'
                : 'Un passager';

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


        // Envoyer une notification au conducteur avec des détails supplémentaires
        final driverId = updatedTrip['userId'];
        await NotificationService.createReservationNotification(
          driverId: driverId,
          passengerId: currentUser.uid,
          passengerName: passengerName,
          tripId: tripId,
          tripDestination:
              updatedTrip['arrivée'] is String
                  ? updatedTrip['arrivée']
                  : 'destination',
          tripDate:
              updatedTrip['date'] is String
                  ? updatedTrip['date']
                  : 'date prévue',
          seatsReserved: requiredSeats,
        );

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
}
