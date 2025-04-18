import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'maps.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result_page.dart';

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  _ReservationPageState createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  TextEditingController _seatsController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  final TimeOfDay _selectedTime = TimeOfDay.now();
  int _numberOfSeats = 1;

  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialiser les champs date et heure comme vides
    _dateController.text = '';
    _seatsController = TextEditingController(text: '1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BladiWay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réserver pour un voyage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 60),

            // Conteneur des champs de départ et d'arrivée
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildLocationField(
                    controller: _departureController,
                    hint: 'Départ',
                    icon: Icons.location_on_outlined,
                    isForDeparture: true,
                  ),

                  const Divider(height: 1, thickness: 1, color: Colors.blue),

                  _buildLocationField(
                    controller: _arrivalController,
                    hint: 'Arrivée',
                    icon: Icons.location_on,
                    isForDeparture: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Champ Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La Date(facultatif)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 5),
                _buildTextField(
                  controller: _dateController,
                  hint: 'Sélectionner la date',
                  readOnly: true,
                  suffixIcon: Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
              ],
            ),

            const SizedBox(height: 60),

            // Champ Nombre de places
            // Remplacez votre colonne actuelle par celle-ci
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nombre de places',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 5),
                // Nouveau widget de sélection de nombre de places
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bouton décrémentation
                      IconButton(
                        onPressed: () {
                          setState(() {
                            int seats =
                                int.tryParse(_seatsController.text) ?? 1;
                            if (seats > 1) {
                              _seatsController.text = (seats - 1).toString();
                            }
                          });
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(0),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      // Valeur actuelle
                      Text(
                        _seatsController.text,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Bouton incrémentation
                      IconButton(
                        onPressed: () {
                          setState(() {
                            int seats =
                                int.tryParse(_seatsController.text) ?? 1;
                            if (seats < 7) {
                              // Ajoutez votre limite supérieure ici
                              _seatsController.text = (seats + 1).toString();
                            }
                          });
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(0),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 116),

            // Bouton rechercher un trajet
            Center(
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[300]!, Colors.blue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _searchTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Chercher un trajet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isForDeparture,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => MapsScreen(
                  isForDeparture: isForDeparture,
                  onLocationSelected: (address) {
                    if (mounted) {
                      // Vérifiez si le widget est toujours dans l'arbre
                      setState(() {
                        controller.text = address;
                      });
                    } else {
                      // Mise à jour sans setState
                      controller.text = address;
                    }
                  },
                ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isForDeparture ? Colors.blue : Colors.red,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                controller.text.isEmpty ? hint : controller.text,
                style: TextStyle(
                  fontSize: 16,
                  color: controller.text.isEmpty ? Colors.grey : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  bool _areRequiredFieldsFilled() {
    return _departureController.text.isNotEmpty &&
        _arrivalController.text.isNotEmpty &&
        _seatsController.text.isNotEmpty;
  }

  void _showValidationErrors() {
    List<String> emptyFields = [];
    if (_departureController.text.isEmpty) emptyFields.add('Point de départ');
    if (_arrivalController.text.isEmpty) emptyFields.add('Point d\'arrivée');
    if (_seatsController.text.isEmpty) emptyFields.add('Nombre de places');

    String errorMessage =
        'Veuillez remplir les champs suivants: ${emptyFields.join(', ')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 1. Correction de la méthode _searchTrip()
  void _searchTrip() async {
    // Modification ici : si le champ est vide, définir _seatsController.text à "1"
    if (_seatsController.text.isEmpty) {
      setState(() {
        _seatsController.text = "1";
        _numberOfSeats = 1;
      });
    }

    if (!_departureController.text.isNotEmpty ||
        !_arrivalController.text.isNotEmpty) {
      _showValidationErrors();
      return;
    }

    // Afficher l'indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtenir l'ID de l'utilisateur actuel
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (currentUserId.isEmpty) {
        // Si l'utilisateur n'est pas connecté, afficher un message d'erreur
        Navigator.pop(context); // Fermer l'indicateur de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vous devez être connecté pour effectuer une recherche.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtenir les informations de l'utilisateur actuel pour connaître son genre
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (!userDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de récupérer les informations utilisateur.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // Récupérer le genre de l'utilisateur
      final userData = userDoc.data() as Map<String, dynamic>;
      final String userGender = userData['genre'] as String? ?? '';

      if (userGender.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le genre de l\'utilisateur n\'est pas défini.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Genre de l\'utilisateur actuel: $userGender');

      // Convertir les critères de date et de places en variables pour simplifier le code
      final String departureLocation = _departureController.text.trim();
      final String arrivalLocation = _arrivalController.text.trim();
      final String tripDate =
          _dateController.text.trim(); // Peut être vide maintenant
      final int requiredSeats = int.tryParse(_seatsController.text) ?? 1;

      // Extraire les wilayas des adresses
      final String departureWilaya = _extractWilaya(departureLocation);
      final String arrivalWilaya = _extractWilaya(arrivalLocation);

      // Simplifier les noms de wilaya (en minuscules et sans préfixes)
      final String simplifiedDepartureWilaya = departureWilaya
          .toLowerCase()
          .replaceAll("wilaya de ", "")
          .replaceAll("province de ", "")
          .replaceAll("wilaya d'", "")
          .replaceAll("province d'", "");

      final String simplifiedArrivalWilaya = arrivalWilaya
          .toLowerCase()
          .replaceAll("wilaya de ", "")
          .replaceAll("province de ", "")
          .replaceAll("wilaya d'", "")
          .replaceAll("province d'", "");

      print(
        'Recherche avec critères: Départ=$departureLocation (Wilaya=$simplifiedDepartureWilaya), Arrivée=$arrivalLocation (Wilaya=$simplifiedArrivalWilaya), Date=${tripDate.isEmpty ? "non spécifiée" : tripDate}, Places=$requiredSeats',
      );

      // Requête initiale sur les trajets
      Query query = _firestore.collection('trips');

      // Si une date est spécifiée, filtrer par cette date
      if (tripDate.isNotEmpty) {
        query = query.where('date', isEqualTo: tripDate);
      }

      // Exécuter la requête
      QuerySnapshot querySnapshot = await query.get();

      print('Nombre total de documents trouvés: ${querySnapshot.docs.length}');

      // Filtrer les résultats selon la wilaya et les places disponibles
      List<QueryDocumentSnapshot> filteredTrips =
          querySnapshot.docs.where((doc) {
            Map<String, dynamic> tripData = doc.data() as Map<String, dynamic>;
            // Vérifier si l'utilisateur actuel est le conducteur de ce trajet
            String userId = tripData['userId'] as String? ?? '';
            bool isUserTheDriver = userId == currentUserId;

            // Si l'utilisateur est le conducteur, exclure ce trajet
            if (isUserTheDriver) {
              print(
                'Doc ${doc.id} - Exclu car l\'utilisateur est le conducteur',
              );
              return false;
            }
            // Récupérer le type de passagers pour ce trajet
            String typePassagers =
                tripData['typePassagers'] as String? ?? 'Mixte';

            // Vérifier si le genre de l'utilisateur est compatible avec le type de passagers du trajet
            bool genderMatch = false;
            if (userGender.toLowerCase() == 'femme') {
              // Les femmes peuvent voir les trajets "Femmes" ou "Mixte"
              genderMatch =
                  typePassagers == 'Femmes' || typePassagers == 'Mixte';
            } else if (userGender.toLowerCase() == 'homme') {
              // Les hommes peuvent voir les trajets "Hommes" ou "Mixte"
              genderMatch =
                  typePassagers == 'Hommes' || typePassagers == 'Mixte';
            }

            // Si le genre ne correspond pas, exclure ce trajet
            if (!genderMatch) {
              print(
                'Doc ${doc.id} - Exclu car incompatible avec le genre de l\'utilisateur (Genre: $userGender, Type de passagers: $typePassagers)',
              );
              return false;
            }

            // Extraire les wilayas des trajets
            String tripDepartureWilaya = _extractWilaya(
              tripData['départ'] as String? ?? '',
            );
            String tripArrivalWilaya = _extractWilaya(
              tripData['arrivée'] as String? ?? '',
            );

            // Simplifier les noms de wilaya des trajets (en minuscules et sans préfixes)
            String simplifiedTripDepartureWilaya = tripDepartureWilaya
                .toLowerCase()
                .replaceAll("wilaya de ", "")
                .replaceAll("province de ", "")
                .replaceAll("wilaya d'", "")
                .replaceAll("province d'", "");

            String simplifiedTripArrivalWilaya = tripArrivalWilaya
                .toLowerCase()
                .replaceAll("wilaya de ", "")
                .replaceAll("province de ", "")
                .replaceAll("wilaya d'", "")
                .replaceAll("province d'", "");

            // Vérification de correspondance des wilayas
            bool departureMatch =
                simplifiedTripDepartureWilaya.contains(
                  simplifiedDepartureWilaya,
                ) ||
                simplifiedDepartureWilaya.contains(
                  simplifiedTripDepartureWilaya,
                );

            bool arrivalMatch =
                simplifiedTripArrivalWilaya.contains(simplifiedArrivalWilaya) ||
                simplifiedArrivalWilaya.contains(simplifiedTripArrivalWilaya);

            // Vérification du statut et des places disponibles
            String status = tripData['status'] as String? ?? '';
            int availableSeats =
                tripData['placesDisponibles'] is int
                    ? tripData['placesDisponibles']
                    : int.tryParse(
                          tripData['placesDisponibles']?.toString() ?? '',
                        ) ??
                        (tripData['nbrPlaces'] is int
                            ? tripData['nbrPlaces']
                            : int.tryParse(
                                  tripData['nbrPlaces']?.toString() ?? '',
                                ) ??
                                0);

            bool statusMatch = status == 'en attente';
            bool seatsMatch = availableSeats >= requiredSeats;

            print(
              'Doc ${doc.id} - Départ: ${tripData['départ']} (Wilaya: $simplifiedTripDepartureWilaya, Match: $departureMatch), Arrivée: ${tripData['arrivée']} (Wilaya: $simplifiedTripArrivalWilaya, Match: $arrivalMatch), Status: $statusMatch, Places: $seatsMatch',
            );

            // Retourner true seulement si toutes les conditions sont remplies
            return departureMatch && arrivalMatch && statusMatch && seatsMatch;
          }).toList();

      print('Nombre de trajets filtrés: ${filteredTrips.length}');

      // Fermer l'indicateur de chargement
      Navigator.pop(context);

      // Naviguer vers la page des résultats
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => TripResultsPage(
                trips: filteredTrips,
                requiredSeats: requiredSeats,
              ),
        ),
      );
    } catch (error) {
      print('Erreur lors de la recherche: $error');
      // Fermer l'indicateur de chargement en cas d'erreur
      Navigator.pop(context);

      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour extraire la wilaya d'une adresse
  String _extractWilaya(String address) {
    // Supposant que le format est "ville, wilaya, pays" ou "ville, wilaya"
    List<String> parts = address.split(',');

    if (parts.length >= 2) {
      // La wilaya est généralement la deuxième partie (index 1)
      return parts[1].trim();
    }

    // Si le format est différent, retourner l'adresse complète
    return address;
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _dateController.dispose();
    _seatsController.dispose();
    super.dispose();
  }
}
