import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'info_conducteur.dart'; // Import the new screen

class InfoConducteur extends StatelessWidget {
  final DocumentSnapshot reservation;
  final DocumentSnapshot trip;
  final DocumentSnapshot conductor;

  const InfoConducteur({
    super.key,
    required this.reservation,
    required this.trip,
    required this.conductor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reservationData = reservation.data() as Map<String, dynamic>;
    final tripData = trip.data() as Map<String, dynamic>;
    final conductorData = conductor.data() as Map<String, dynamic>;

    final seatsReserved = reservationData['seatsReserved'];
    final price = tripData['prix'] as num? ?? 0;
    final totalPrice = (price * seatsReserved);

    // Récupérer la valeur de isValidated avec une valeur par défaut à false si null
    final isValidated = conductorData['isValidated'] as bool? ?? false;

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
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Infos sur le trajet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Carte du profil du conducteur - Rendue cliquable pour naviguer vers info_conducteur.dart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () {
                      // Navigation vers info_conducteur.dart quand on clique sur la carte du conducteur
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => InfoConducteurPage(
                                conductorId: conductor.id,
                                reservationId: reservation.id,
                                currentUserId: reservationData['userId'],
                              ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'conductor-${conductor.id}',
                              child: CircleAvatar(
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
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                              isEqualTo: conductor.id,
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
                                            reviewsSnapshot.data!.docs.length;
                                        double totalRating = 0;
                                        for (var doc
                                            in reviewsSnapshot.data!.docs) {
                                          final reviewData =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          totalRating +=
                                              (reviewData['rating'] as num? ??
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                            tripData['départ'],
                            tripData['arrivée'],
                            tripData['date'],
                            tripData['heure'],
                          ),
                          const SizedBox(height: 20),
                          _buildTripDetails(context, tripData),
                          const SizedBox(height: 20),
                          _buildCarInfo(context, tripData),
                          const SizedBox(height: 20),
                          _buildPriceBreakdown(
                            context,
                            seatsReserved,
                            price,
                            totalPrice,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.message,
                                    color: Colors.white,
                                  ),
                                  label: const Text('CONTACTER'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ChatPage(
                                              reservationId: reservation.id,
                                              otherUserId: conductor.id,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.phone_outlined),
                                  label: const Text('APPELER'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    side: BorderSide(
                                      color: theme.colorScheme.primary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final phoneNumber =
                                        conductorData['phone'] as String?;
                                    if (phoneNumber != null) {
                                      final url = 'tel:$phoneNumber';
                                      if (await canLaunch(url)) {
                                        await launch(url);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
    // Ajout du nouveau champ typePassagers
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
                    // Ajout du nouveau typePassagers
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
                      // ignore: null_argument_to_non_null_type
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
