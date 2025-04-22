import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Widget pour la carte d'un trajet (utilisé dans la liste des résultats)
class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String tripId;
  final void Function()? onTap;
  final void Function()? onDriverTap;

  const TripCard({
    super.key,
    required this.trip,
    required this.tripId,
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _extractCity(trip['départ']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
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
              // ... Menu d'options à gérer dans la page principale ...
            ],
          ),
        ),
      ),
    );
  }
}

// Widget pour une ligne de détail
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
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
}

// Widget pour les infos principales du trajet
class TripInfoCard extends StatelessWidget {
  final String depart;
  final String arrivee;
  final String date;
  final String heure;
  const TripInfoCard({
    super.key,
    required this.depart,
    required this.arrivee,
    required this.date,
    required this.heure,
  });
  @override
  Widget build(BuildContext context) {
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
                InfoItem(
                  icon: Icons.calendar_today,
                  value: date,
                  label: 'Date',
                ),
                InfoItem(icon: Icons.access_time, value: heure, label: 'Heure'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour les infos supplémentaires du trajet
class TripDetailsCard extends StatelessWidget {
  final Map<String, dynamic> tripData;
  const TripDetailsCard({super.key, required this.tripData});
  @override
  Widget build(BuildContext context) {
    final description =
        tripData['description'] as String? ?? 'Aucune description disponible';
    final bagage = tripData['bagage'] as String? ?? 'Non Autorisé';
    final climatisation =
        tripData['climatisation'] as String? ?? 'Non Autorisé';
    final fumer = tripData['fumer'] as String? ?? 'Non Autorisé';
    final animal = tripData['animal'] as String? ?? 'Non Autorisé';
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
                constraints: const BoxConstraints(maxWidth: 400),
                child: Wrap(
                  spacing: 30,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    FeatureItem(
                      icon: Icons.work_outline,
                      label: 'Bagage',
                      value: bagage,
                    ),
                    FeatureItem(
                      icon: Icons.ac_unit,
                      label: 'Climatisation',
                      value: climatisation,
                    ),
                    FeatureItem(
                      icon: Icons.smoking_rooms,
                      label: 'Fumeur',
                      value: fumer,
                    ),
                    FeatureItem(
                      icon: Icons.pets,
                      label: 'Animal',
                      value: animal,
                    ),
                    FeatureItem(
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
}

// Widget pour un attribut (bagage, clim, etc.)
class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPassengerType;
  const FeatureItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isPassengerType = false,
  });
  @override
  Widget build(BuildContext context) {
    final isAuthorized = value == 'Autorisé';
    Color iconColor;
    Color textColor;
    Color bgColor;
    if (isPassengerType) {
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
}

// Widget pour les infos véhicule
class CarInfoCard extends StatelessWidget {
  final Map<String, dynamic> tripData;
  const CarInfoCard({super.key, required this.tripData});
  @override
  Widget build(BuildContext context) {
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
                      : Future.value(
                        FirebaseFirestore.instance.doc('cars/dummy').get(),
                      ),
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
}

// Widget pour le détail du prix
class PriceBreakdownCard extends StatelessWidget {
  final int seatsReserved;
  final num pricePerSeat;
  final num totalPrice;
  const PriceBreakdownCard({
    super.key,
    required this.seatsReserved,
    required this.pricePerSeat,
    required this.totalPrice,
  });
  @override
  Widget build(BuildContext context) {
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
}

// Widget pour une info simple (date, heure)
class InfoItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const InfoItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
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
