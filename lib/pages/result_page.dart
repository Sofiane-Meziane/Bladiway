import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'confirmationPage.dart';
import 'info_conducteur.dart';
import 'maps.dart';
import '../widgets/trip_widgets.dart';
import '../services/notification_service.dart';

final user = FirebaseAuth.instance.currentUser;

// Nouvelle classe TripMapPreview ajoutée
class TripMapPreview extends StatefulWidget {
  final String departure;
  final String arrival;

  const TripMapPreview({
    super.key,
    required this.departure,
    required this.arrival,
  });

  @override
  _TripMapPreviewState createState() => _TripMapPreviewState();
}

class _TripMapPreviewState extends State<TripMapPreview> {
  LatLng? _departureCoordinates;
  LatLng? _arrivalCoordinates;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    try {
      // Convertir l'adresse de départ en coordonnées
      List<Location> departureLocations = await locationFromAddress(
        "${widget.departure}, Algeria",
      );

      if (departureLocations.isNotEmpty) {
        _departureCoordinates = LatLng(
          departureLocations.first.latitude,
          departureLocations.first.longitude,
        );
      }

      // Convertir l'adresse d'arrivée en coordonnées
      List<Location> arrivalLocations = await locationFromAddress(
        "${widget.arrival}, Algeria",
      );

      if (arrivalLocations.isNotEmpty) {
        _arrivalCoordinates = LatLng(
          arrivalLocations.first.latitude,
          arrivalLocations.first.longitude,
        );
      }

      if (_departureCoordinates != null && _arrivalCoordinates != null) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print("Erreur lors de la conversion des adresses en coordonnées: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _showFullScreenMap() {
    if (_departureCoordinates == null || _arrivalCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d'afficher la carte. Coordonnées non disponibles.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MapsScreen(
              isForDeparture: true,
              onLocationSelected: (_) {},
              initialDeparture: _departureCoordinates,
              initialArrival: _arrivalCoordinates,
              showRoute: true,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError ||
        _departureCoordinates == null ||
        _arrivalCoordinates == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                "Carte non disponible",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showFullScreenMap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _departureCoordinates!,
                  zoom: 12,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('departure'),
                    position: _departureCoordinates!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                  Marker(
                    markerId: MarkerId('arrival'),
                    position: _arrivalCoordinates!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: PolylineId('route'),
                    color: Theme.of(context).colorScheme.primary,
                    width: 5,
                    points: [_departureCoordinates!, _arrivalCoordinates!],
                    patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                onMapCreated: (controller) {
                  // Ajuster la vue pour montrer les deux marqueurs
                  LatLngBounds bounds = LatLngBounds(
                    southwest: LatLng(
                      _departureCoordinates!.latitude <
                              _arrivalCoordinates!.latitude
                          ? _departureCoordinates!.latitude
                          : _arrivalCoordinates!.latitude,
                      _departureCoordinates!.longitude <
                              _arrivalCoordinates!.longitude
                          ? _departureCoordinates!.longitude
                          : _arrivalCoordinates!.longitude,
                    ),
                    northeast: LatLng(
                      _departureCoordinates!.latitude >
                              _arrivalCoordinates!.latitude
                          ? _departureCoordinates!.latitude
                          : _arrivalCoordinates!.latitude,
                      _departureCoordinates!.longitude >
                              _arrivalCoordinates!.longitude
                          ? _departureCoordinates!.longitude
                          : _arrivalCoordinates!.longitude,
                    ),
                  );
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 50),
                  );
                },
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Agrandir',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        title: Text(
          'Les trajets disponibles',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
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
                  // Safely extract trip data with null checks
                  final Map<String, dynamic> trip;
                  try {
                    trip = trips[index].data() as Map<String, dynamic>;
                  } catch (e) {
                    print("Error converting trip data: $e");
                    return SizedBox.shrink(); // Skip this item if data is invalid
                  }

                  // Check if trip is in the past
                  final String date = trip['date'] as String? ?? '';
                  final String heure = trip['heure'] as String? ?? '';
                  bool isPast = _isTripPast(date, heure);

                  // Skip past trips if we're not showing a specific date search
                  if (isPast && !_isSpecificDateSearch()) {
                    return SizedBox.shrink(); // Don't show past trips
                  }

                  // Safely extract placesDisponibles with proper null handling
                  int placesDisponibles = 0;
                  try {
                    if (trip['placesDisponibles'] != null) {
                      if (trip['placesDisponibles'] is int) {
                        placesDisponibles = trip['placesDisponibles'];
                      } else {
                        placesDisponibles =
                            int.tryParse(
                              trip['placesDisponibles'].toString(),
                            ) ??
                            0;
                      }
                    } else if (trip['nbrPlaces'] != null) {
                      if (trip['nbrPlaces'] is int) {
                        placesDisponibles = trip['nbrPlaces'];
                      } else {
                        placesDisponibles =
                            int.tryParse(trip['nbrPlaces'].toString()) ?? 0;
                      }
                    }
                  } catch (e) {
                    print("Error parsing placesDisponibles: $e");
                    // Default to 0 if there's an error
                  }

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
                            trip['userId'] as String? ?? '',
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
    if (driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID du conducteur non disponible")),
      );
      return;
    }

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

  bool _isSpecificDateSearch() {
    // Cette méthode détermine si l'utilisateur a spécifié une date dans sa recherche
    // Vous devrez adapter cette logique en fonction de la façon dont vous gérez les recherches
    // Par exemple, vous pourriez passer un paramètre supplémentaire au constructeur TripResultsPage

    // Pour l'instant, nous supposons qu'aucune date spécifique n'est recherchée
    // Modifiez cette logique selon votre implémentation de recherche
    return false;
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

    // Safely extract trip data with null checks
    final String depart = trip['départ'] as String? ?? 'Lieu inconnu';
    final String arrivee = trip['arrivée'] as String? ?? 'Lieu inconnu';
    final String date = trip['date'] as String? ?? 'Date inconnue';
    final String heure = trip['heure'] as String? ?? '00:00';
    final String userId = trip['userId'] as String? ?? '';
    final String typePassagers = trip['typePassagers'] as String? ?? 'Mixte';
    final String climatisation =
        trip['climatisation'] as String? ?? 'Non autorisé';
    final String bagage = trip['bagage'] as String? ?? 'Non autorisé';

    // Safely handle price
    dynamic prix = trip['prix'];
    String displayPrice = '0';
    if (prix != null) {
      if (prix is double) {
        displayPrice = prix.toStringAsFixed(0);
      } else if (prix is int) {
        displayPrice = prix.toString();
      } else {
        try {
          displayPrice = prix.toString();
        } catch (e) {
          print("Error converting price: $e");
        }
      }
    }

    bool isPast = _isTripPast(date, heure);

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
                      onTap: userId.isNotEmpty ? onDriverTap : null,
                      child: StreamBuilder<DocumentSnapshot>(
                        stream:
                            userId.isNotEmpty
                                ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .snapshots()
                                : null,
                        builder: (context, snapshot) {
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

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[200],
                              child: const CircularProgressIndicator(),
                            );
                          }

                          Map<String, dynamic>? userData;
                          try {
                            userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                          } catch (e) {
                            print("Error converting user data: $e");
                          }

                          final profileImageUrl = userData?['profileImageUrl'];
                          final isValidated =
                              userData?['isValidated'] as bool? ?? false;

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
                                  _extractCity(depart),
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
                                  _extractCity(arrivee),
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
                                '$date à $heure',
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
                              if (climatisation == 'Autorisé')
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.ac_unit,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),

                              // Bagages
                              if (bagage == 'Autorisé')
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.luggage,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),

                              // Type de passagers
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  typePassagers == 'Femmes'
                                      ? Icons.female
                                      : typePassagers == 'Hommes'
                                      ? Icons.male
                                      : Icons.people,
                                  size: 16,
                                  color:
                                      typePassagers == 'Femmes'
                                          ? Colors.pink
                                          : typePassagers == 'Hommes'
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
                      '$displayPrice DA',
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
    if (driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID du conducteur non disponible")),
      );
      return;
    }

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
    // Safely extract trip data with null checks
    final String depart = trip['départ'] as String? ?? 'Lieu inconnu';
    final String arrivee = trip['arrivée'] as String? ?? 'Lieu inconnu';
    final String date = trip['date'] as String? ?? 'Date inconnue';
    final String heure = trip['heure'] as String? ?? '00:00';
    final String userId = trip['userId'] as String? ?? '';

    // Safely handle price
    dynamic prix = trip['prix'];
    num priceValue = 0;
    if (prix != null) {
      if (prix is num) {
        priceValue = prix;
      } else {
        try {
          priceValue = num.tryParse(prix.toString()) ?? 0;
        } catch (e) {
          print("Error converting price: $e");
        }
      }
    }

    bool isPast = _isTripPast(date, heure);
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
                              if (userId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "ID du conducteur non disponible",
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                final userDoc =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userId)
                                        .get();

                                if (userDoc.exists) {
                                  final userData = userDoc.data();
                                  final phoneNumber =
                                      userData?['phone'] as String?;

                                  if (phoneNumber != null &&
                                      phoneNumber.isNotEmpty) {
                                    final url = 'tel:$phoneNumber';
                                    if (await canLaunch(url)) {
                                      await launch(url);
                                    } else {
                                      throw 'Could not launch $url';
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Numéro de téléphone non disponible",
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Utilisateur non trouvé"),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur: $e")),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                            onPressed: () => _showDriverInfo(context, userId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Carte du profil du conducteur
                FutureBuilder<DocumentSnapshot>(
                  future:
                      userId.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get()
                          : null,
                  builder: (context, snapshot) {
                    if (userId.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                "Informations du conducteur non disponibles",
                              ),
                            ),
                          ),
                        ),
                      );
                    }

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

                    Map<String, dynamic>? conductorData;
                    try {
                      conductorData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                    } catch (e) {
                      print("Error converting conductor data: $e");
                      return const Center(
                        child: Text(
                          "Erreur lors de la récupération des données",
                        ),
                      );
                    }

                    if (conductorData == null) {
                      return const Center(
                        child: Text("Données du conducteur non disponibles"),
                      );
                    }

                    final isValidated =
                        conductorData['isValidated'] as bool? ?? false;
                    final prenom = conductorData['prenom'] as String? ?? '';
                    final nom = conductorData['nom'] as String? ?? '';
                    final profileImageUrl =
                        conductorData['profileImageUrl'] as String?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => _showDriverInfo(context, userId),
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
                                      profileImageUrl != null
                                          ? NetworkImage(profileImageUrl)
                                          : null,
                                  child:
                                      profileImageUrl == null
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
                                        '$prenom $nom',
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
                                                  isEqualTo: userId,
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
                                              try {
                                                final reviewData =
                                                    doc.data()
                                                        as Map<
                                                          String,
                                                          dynamic
                                                        >?;
                                                if (reviewData != null) {
                                                  totalRating +=
                                                      (reviewData['rating']
                                                                  as num? ??
                                                              0)
                                                          .toDouble();
                                                }
                                              } catch (e) {
                                                print(
                                                  "Error processing review: $e",
                                                );
                                              }
                                            }
                                            rating =
                                                reviewCount > 0
                                                    ? totalRating / reviewCount
                                                    : 0;
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
                            depart: depart,
                            arrivee: arrivee,
                            date: date,
                            heure: heure,
                          ),
                          const SizedBox(height: 20),
                          // Ajout de la carte ici
                          Text(
                            'Itinéraire',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TripMapPreview(departure: depart, arrival: arrivee),
                          const SizedBox(height: 20),
                          TripDetailsCard(tripData: trip),
                          const SizedBox(height: 20),
                          CarInfoCard(tripData: trip),
                          const SizedBox(height: 20),
                          PriceBreakdownCard(
                            seatsReserved: requiredSeats,
                            pricePerSeat: priceValue,
                            totalPrice: priceValue * requiredSeats,
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
              .map((doc) {
                try {
                  return doc.data() as Map<String, dynamic>;
                } catch (e) {
                  print("Error converting piece data: $e");
                  return <String, dynamic>{};
                }
              })
              .where((piece) => piece.isNotEmpty)
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
        SnackBar(content: Text('Erreur lors de la vérification: $e')),
      );
    }
  }

  void _showReservationDialog(BuildContext context) async {
    // Récupérer les places disponibles de manière sécurisée
    int availableSeats = 0;
    try {
      if (trip['placesDisponibles'] != null) {
        if (trip['placesDisponibles'] is int) {
          availableSeats = trip['placesDisponibles'];
        } else {
          availableSeats =
              int.tryParse(trip['placesDisponibles'].toString()) ?? 0;
        }
      } else if (trip['nbrPlaces'] != null) {
        if (trip['nbrPlaces'] is int) {
          availableSeats = trip['nbrPlaces'];
        } else {
          availableSeats = int.tryParse(trip['nbrPlaces'].toString()) ?? 0;
        }
      }
    } catch (e) {
      print("Error parsing available seats: $e");
    }

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
                  try {
                    final updatedTripSnapshot =
                        await FirebaseFirestore.instance
                            .collection('trips')
                            .doc(tripId)
                            .get();

                    Navigator.pop(context); // Fermer le loader
                    Navigator.pop(
                      context,
                    ); // Fermer le dialogue de confirmation

                    if (!updatedTripSnapshot.exists) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ce trajet n\'existe plus.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    Map<String, dynamic>? updatedTrip;
                    try {
                      updatedTrip = updatedTripSnapshot.data();
                    } catch (e) {
                      print("Error converting updated trip data: $e");
                    }

                    if (updatedTrip == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Erreur lors de la récupération des données du trajet.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    // Vérifier le statut et les places disponibles
                    final String status =
                        updatedTrip['status'] as String? ?? '';
                    int updatedAvailableSeats = 0;

                    try {
                      if (updatedTrip['placesDisponibles'] != null) {
                        if (updatedTrip['placesDisponibles'] is int) {
                          updatedAvailableSeats =
                              updatedTrip['placesDisponibles'];
                        } else {
                          updatedAvailableSeats =
                              int.tryParse(
                                updatedTrip['placesDisponibles'].toString(),
                              ) ??
                              0;
                        }
                      } else if (updatedTrip['nbrPlaces'] != null) {
                        if (updatedTrip['nbrPlaces'] is int) {
                          updatedAvailableSeats = updatedTrip['nbrPlaces'];
                        } else {
                          updatedAvailableSeats =
                              int.tryParse(
                                updatedTrip['nbrPlaces'].toString(),
                              ) ??
                              0;
                        }
                      }
                    } catch (e) {
                      print("Error parsing updated available seats: $e");
                    }

                    if (status == 'en attente' &&
                        updatedAvailableSeats >= requiredSeats) {
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
                  } catch (e) {
                    Navigator.pop(context); // Fermer le loader en cas d'erreur
                    Navigator.pop(
                      context,
                    ); // Fermer le dialogue de confirmation

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Erreur lors de la vérification du trajet: $e',
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
    final String date = updatedTrip['date'] as String? ?? '';
    final String heure = updatedTrip['heure'] as String? ?? '';

    if (_isTripPast(date, heure)) {
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
      int availableSeats = 0;
      try {
        if (updatedTrip['placesDisponibles'] != null) {
          if (updatedTrip['placesDisponibles'] is int) {
            availableSeats = updatedTrip['placesDisponibles'];
          } else {
            availableSeats =
                int.tryParse(updatedTrip['placesDisponibles'].toString()) ?? 0;
          }
        } else if (updatedTrip['nbrPlaces'] != null) {
          if (updatedTrip['nbrPlaces'] is int) {
            availableSeats = updatedTrip['nbrPlaces'];
          } else {
            availableSeats =
                int.tryParse(updatedTrip['nbrPlaces'].toString()) ?? 0;
          }
        }
      } catch (e) {
        print("Error parsing available seats: $e");
      }

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

        // Vérifier si l'utilisateur a déjà réservé ce trajet
        QuerySnapshot existingReservations =
            await FirebaseFirestore.instance
                .collection('reservations')
                .where('tripId', isEqualTo: tripId)
                .where('userId', isEqualTo: currentUser.uid)
                .get();

        if (existingReservations.docs.isNotEmpty) {
          // L'utilisateur a déjà une réservation pour ce trajet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Vous avez déjà réservé ce trajet. Vous pouvez modifier le nombre de places dans la page 'Mes réservations'.",
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
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

        String passengerName = 'Un passager';
        if (passengerDoc.exists) {
          try {
            final passengerData = passengerDoc.data();
            if (passengerData != null) {
              final prenom = passengerData['prenom'] as String? ?? '';
              final nom = passengerData['nom'] as String? ?? '';
              if (prenom.isNotEmpty || nom.isNotEmpty) {
                passengerName = '$prenom $nom'.trim();
              }
            }
          } catch (e) {
            print("Error extracting passenger data: $e");
          }
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

        // Créer une nouvelle réservation dans la collection 'reservations' avec les attributs demandés
        await FirebaseFirestore.instance.collection('reservations').add({
          'date_reservation': FieldValue.serverTimestamp(),
          'seatsReserved': requiredSeats,
          'tripId': tripId,
          'userId': currentUser.uid,
        });

        // Envoyer une notification au conducteur avec des détails supplémentaires
        final driverId = updatedTrip['userId'] as String? ?? '';
        if (driverId.isNotEmpty) {
          await NotificationService.createReservationNotification(
            driverId: driverId,
            passengerId: currentUser.uid,
            passengerName: passengerName,
            tripId: tripId,
            tripDestination: updatedTrip['arrivée'] as String? ?? 'destination',
            tripDate: updatedTrip['date'] as String? ?? 'date prévue',
            seatsReserved: requiredSeats,
          );
        }

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
      navigator.push(
        MaterialPageRoute(builder: (context) => ConfirmationPage()),
      );
    }
  }
}
