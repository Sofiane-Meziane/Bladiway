import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';

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

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 50,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Column(
                children: [
                  Row(
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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.white),
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
                          IconButton(
                            icon: const Icon(
                              Icons.message,
                              color: Colors.white,
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage:
                              conductorData['profileImageUrl'] != null
                                  ? NetworkImage(
                                    conductorData['profileImageUrl'],
                                  )
                                  : null,
                          child:
                              conductorData['profileImageUrl'] == null
                                  ? const Icon(Icons.person, size: 30)
                                  : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${conductorData['prenom']} ${conductorData['nom']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  Text(' 4.5', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        /*Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'compléter',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),*/
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTripInfo(
                    context,
                    tripData['départ'],
                    tripData['arrivée'],
                    tripData['date'],
                    tripData['heure'],
                  ),
                  const SizedBox(height: 20),
                  _buildCarInfo(context, tripData),
                  const SizedBox(height: 20),
                  _buildPriceBreakdown(
                    context,
                    seatsReserved,
                    price,
                    totalPrice,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.trip_origin, color: Colors.blue, size: 20),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.blue.withOpacity(0.5),
                    ),
                    const Icon(Icons.location_on, color: Colors.blue, size: 20),
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
                      const SizedBox(height: 20),
                      Text(
                        arrivee,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
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

  Widget _buildCarInfo(BuildContext context, Map<String, dynamic> tripData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: const DecorationImage(
                  image: AssetImage('assets/images/toyota.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toyota Corolla',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Climatisée',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                Text('$seatsReserved places'),
                Text('${(pricePerSeat * seatsReserved).toStringAsFixed(0)} DA'),
              ],
            ),
            const SizedBox(height: 8),
           
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'totale',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${totalPrice.toStringAsFixed(0)} DA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
