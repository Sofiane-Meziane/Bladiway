import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'maps.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Classe Car pour modéliser les voitures
class Car {
  final String id;
  final String marque;
  final String modele;
  final String plaque;
  final String imageUrl;

  Car({
    required this.id,
    required this.marque,
    required this.modele,
    required this.plaque,
    required this.imageUrl,
  });

  factory Car.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Car(
      id: doc.id,
      marque: data['marque'] ?? '',
      modele: data['model'] ?? '',
      plaque: data['plate'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

class InfoTrajet extends StatefulWidget {
  const InfoTrajet({super.key});

  @override
  _InfoTrajetState createState() => _InfoTrajetState();
}

class _InfoTrajetState extends State<InfoTrajet>
    with AutomaticKeepAliveClientMixin {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Contrôleurs pour les champs de texte
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  // Variables pour la sélection de véhicule
  List<Car> _userCars = [];
  Car? _selectedCar;
  bool _isLoadingCars = true;
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserCars();
  }

  // Valeurs des menus déroulants
  String _selectedLuggage = 'Non Autorisé';
  String _selectedSmoking = 'Non Autorisé';
  String _selectedAnimal = 'Non Autorisé';
  String _selectedAirConditioning = 'Non Autorisé';
  String _selectedPassengersType = 'Mixte';
  final String _selectedPaymentMethod = 'Espèces';

  // État d'expansion des sections
  bool _isOptionsExpanded = false;

  // Nombre de places disponibles
  int _seatCount = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Utiliser les couleurs du thème global
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final accentColor = colorScheme.secondary;
    final backgroundColor = colorScheme.surface;
    final surfaceColor = colorScheme.surface;

    // Méthode pour construire la section de sélection de véhicule
    Widget buildVehicleSelection(Color primaryColor, Color surfaceColor) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sélectionner un véhicule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingCars)
              const Center(child: CircularProgressIndicator())
            else if (_userCars.isEmpty)
              const Center(
                child: Text(
                  'Aucun véhicule disponible. Veuillez en ajouter un dans votre profil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Car>(
                        isExpanded: true,
                        value: _selectedCar,
                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        items:
                            _userCars.map<DropdownMenuItem<Car>>((Car car) {
                              return DropdownMenuItem<Car>(
                                value: car,
                                child: Text(
                                  '${car.marque} ${car.modele} - ${car.plaque}',
                                ),
                              );
                            }).toList(),
                        onChanged: (Car? newValue) {
                          setState(() {
                            _selectedCar = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedCar != null)
                    _buildSelectedCarCard(_selectedCar!, primaryColor),
                ],
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BladiWay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'Détails du trajet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),

              // Champs de départ et d'arrivée
              _buildTextField(
                'Saisir un point de départ',
                _departureController,
                Icons.location_on,
                isLocationField: true,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Saisir un point d\'arrivée',
                _arrivalController,
                Icons.location_on,
                isLocationField: true,
                primaryColor: primaryColor,
              ),

              const SizedBox(height: 24),

              // Section de date et heure
              Row(
                children: [
                  Expanded(child: _buildDateField(primaryColor)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeField(primaryColor)),
                ],
              ),
              const SizedBox(height: 16),

              // Prix et places
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Prix (DA)',
                      _priceController,
                      Icons.attach_money,
                      keyboardType: TextInputType.number,
                      primaryColor: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSeatSelector(primaryColor)),
                ],
              ),
              const SizedBox(height: 24),

              // Section de sélection de véhicule
              buildVehicleSelection(primaryColor, surfaceColor),
              const SizedBox(height: 24),

              // Description du trajet
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description du trajet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Décrivez votre trajet, les conditions, etc...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mode de paiement
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mode de paiement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.money, color: accentColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Espèces',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Options du trajet
              _buildExpandableSection(
                title: 'Options du trajet',
                icon: Icons.settings,
                isExpanded: _isOptionsExpanded,
                onTap:
                    () => setState(
                      () => _isOptionsExpanded = !_isOptionsExpanded,
                    ),
                primaryColor: primaryColor,
                accentColor: accentColor,
                surfaceColor: surfaceColor,
                child: Column(
                  children: [
                    _buildOptionRow(
                      'Bagage',
                      _selectedLuggage,
                      (newValue) =>
                          setState(() => _selectedLuggage = newValue!),
                      primaryColor: primaryColor,
                    ),
                    const Divider(height: 1),
                    _buildOptionRow(
                      'Fumer',
                      _selectedSmoking,
                      (newValue) =>
                          setState(() => _selectedSmoking = newValue!),
                      primaryColor: primaryColor,
                    ),
                    const Divider(height: 1),
                    _buildOptionRow(
                      'Animal',
                      _selectedAnimal,
                      (newValue) => setState(() => _selectedAnimal = newValue!),
                      primaryColor: primaryColor,
                    ),
                    const Divider(height: 1),
                    _buildOptionRow(
                      'Climatisation',
                      _selectedAirConditioning,
                      (newValue) =>
                          setState(() => _selectedAirConditioning = newValue!),
                      primaryColor: primaryColor,
                    ),
                    const Divider(height: 1),
                    _buildOptionRow(
                      'Type de passagers',
                      _selectedPassengersType,
                      (newValue) =>
                          setState(() => _selectedPassengersType = newValue!),
                      primaryColor: primaryColor,
                      options: ['Mixte', 'Femmes', 'Hommes'],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Boutons d'action
              ElevatedButton(
                onPressed: _saveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Partager',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red),
                  ),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget pour sélectionner le nombre de places
  Widget _buildSeatSelector(Color primaryColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Places',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap:
                      () => setState(() {
                        _seatCount =
                            _seatCount > 1 ? _seatCount - 1 : _seatCount;
                      }),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.remove_circle,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text(
                    '$_seatCount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap:
                      () => setState(() {
                        _seatCount =
                            _seatCount < 7 ? _seatCount + 1 : _seatCount;
                      }),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.add_circle,
                      color: colorScheme.primary,
                      size: 20,
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

  // Widget pour le champ de date
  Widget _buildDateField(Color primaryColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      style: TextStyle(color: colorScheme.onSurface),
      readOnly: true,
      onTap: () => _pickDate(primaryColor),
    );
  }

  // Widget pour le champ d'heure
  Widget _buildTimeField(Color primaryColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _timeController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Heure',
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.access_time, color: colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      style: TextStyle(color: colorScheme.onSurface),
      onTap: () => _pickTime(primaryColor),
    );
  }

  // Widget pour afficher la carte du véhicule sélectionné
  Widget _buildSelectedCarCard(Car car, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image du véhicule
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child:
                car.imageUrl.isNotEmpty
                    ? Image.network(
                      car.imageUrl,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.directions_car,
                            size: 60,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                    : Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
          ),
          // Informations du véhicule
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${car.marque} ${car.modele}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        car.plaque,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget d'expansion pour les sections
  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
    required Color primaryColor,
    required Color accentColor,
    required Color surfaceColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow:
            isExpanded
                ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ]
                : null,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, color: primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: child,
            ),
        ],
      ),
    );
  }

  // Méthode pour charger les voitures de l'utilisateur actuel
  Future<void> _loadUserCars() async {
    setState(() {
      _isLoadingCars = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final carsSnapshot =
            await FirebaseFirestore.instance
                .collection('cars')
                .where('id_proprietaire', isEqualTo: user.uid)
                .get();

        final cars =
            carsSnapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();

        setState(() {
          _userCars = cars;
          if (cars.isNotEmpty) {
            _selectedCar = cars.first;
          }
          _isLoadingCars = false;
        });
      } else {
        setState(() {
          _isLoadingCars = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des voitures: $e');
      setState(() {
        _isLoadingCars = false;
      });
    }
  }

  // Widget pour les options
  Widget _buildOptionRow(
    String label,
    String currentValue,
    void Function(String?) onChanged, {
    required Color primaryColor,
    List<String>? options,
  }) {
    final List<String> dropdownOptions =
        options ?? ['Autorisé', 'Non Autorisé'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                items:
                    dropdownOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Méthode pour sélectionner une date
  Future<void> _pickDate(Color primaryColor) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
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

  // Méthode pour sélectionner une heure
  Future<void> _pickTime(Color primaryColor) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      final now = TimeOfDay.now();
      bool isToday =
          _selectedDate.day == DateTime.now().day &&
          _selectedDate.month == DateTime.now().month &&
          _selectedDate.year == DateTime.now().year;

      if (!isToday ||
          pickedTime.hour > now.hour ||
          (pickedTime.hour == now.hour && pickedTime.minute >= now.minute)) {
        setState(() {
          _selectedTime = pickedTime;
          _timeController.text = pickedTime.format(context);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Vous ne pouvez pas sélectionner une heure passée aujourd\'hui',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  // Méthode pour construire un champ de texte
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isLocationField = false,
    required Color primaryColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon, color: colorScheme.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        suffixIcon:
            isLocationField
                ? IconButton(
                  icon: Icon(Icons.map_outlined, color: colorScheme.primary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => MapsScreen(
                              isForDeparture: label.contains('départ'),
                              onLocationSelected: (address) {
                                controller.text = address;
                              },
                            ),
                      ),
                    );
                  },
                )
                : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      style: TextStyle(color: colorScheme.onSurface),
      readOnly: isLocationField,
    );
  }

  // Méthode pour vérifier si tous les champs obligatoires sont remplis
  bool _areRequiredFieldsFilled() {
    return _departureController.text.isNotEmpty &&
        _arrivalController.text.isNotEmpty &&
        _dateController.text.isNotEmpty &&
        _timeController.text.isNotEmpty &&
        _priceController.text.isNotEmpty;
  }

  // Méthode pour afficher les erreurs de validation
  void _showValidationErrors() {
    List<String> emptyFields = [];

    if (_departureController.text.isEmpty) emptyFields.add('Point de départ');
    if (_arrivalController.text.isEmpty) emptyFields.add('Point d\'arrivée');
    if (_dateController.text.isEmpty) emptyFields.add('Date');
    if (_timeController.text.isEmpty) emptyFields.add('Heure');
    if (_priceController.text.isEmpty) emptyFields.add('Prix');

    String errorMessage =
        'Veuillez remplir les champs suivants: ${emptyFields.join(', ')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

 // Méthode pour sauvegarder le trajet
Future<void> _saveTrip() async {
  // Vérifie d'abord si l'utilisateur a les permissions nécessaires
  bool hasPermission = await _checkAddTripPermission();
  if (!hasPermission) {
    return; // Le message d'erreur est déjà affiché dans _checkAddTripPermission()
  }

  // Ensuite, on vérifie que tous les champs requis sont remplis
  if (!_areRequiredFieldsFilled()) {
    _showValidationErrors();
    return;
  }

  // Si tout est bon, on montre la boîte de confirmation
  showConfirmationDialog();
}



  // fonction pour la verification de conducteur 
Future<bool> _checkAddTripPermission() async {
  User? user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vous devez être connecté pour continuer')),
    );
    return false;
  }

  try {
    // Récupérer le permis depuis la table piece_identite
    QuerySnapshot permisSnapshot = await _firestore
        .collection('piece_identite')
        .where('id_proprietaire', isEqualTo: user.uid)
        .where('type_piece', isEqualTo: 'permis')
        .limit(1)
        .get();

    bool hasVerifiedLicense = false;
    bool hasPendingOrNoLicense = true;

    if (permisSnapshot.docs.isNotEmpty) {
      var permisData = permisSnapshot.docs.first.data() as Map<String, dynamic>;
      String statut = permisData['statut'] ?? '';
      String? dateExpirationStr = permisData['date_expiration'];

      DateTime? dateExpiration;
      if (dateExpirationStr != null) {
        try {
          dateExpiration = DateTime.parse(dateExpirationStr);
        } catch (e) {
          print('Erreur de parsing de la date d\'expiration: $e');
        }
      }

      bool isLicenseExpired = dateExpiration == null || dateExpiration.isBefore(DateTime.now());

      hasVerifiedLicense = statut == 'verifie' && !isLicenseExpired;
      hasPendingOrNoLicense = statut == 'en cours' || statut == 'refuse' || isLicenseExpired;
    }

    // Si l'utilisateur n'a pas de permis vérifié ou si son permis a expiré
    if (!hasVerifiedLicense || hasPendingOrNoLicense) {
      // Afficher un message approprié
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez avoir un permis de conduire valide pour partager un trajet'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      
      // Rediriger vers la page de vérification du conducteur
      Navigator.pushNamed(context, '/verifier_Conducteur');
      return false;
    }

    // Vérifier si l'utilisateur a déjà chargé ses voitures
    if (_userCars.isEmpty && !_isLoadingCars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez ajouter au moins une voiture pour partager un trajet'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      
      // Rediriger vers la page de vérification du conducteur
      Navigator.pushNamed(context, '/verifier_Conducteur');
      return false;
    }

    return true;

  } catch (e) {
    print('Erreur lors de la vérification des conditions : $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erreur lors de la vérification')),
    );
    return false;
  }
}





  // Dialogue de confirmation
  void showConfirmationDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 5,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Confirmer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Avant de publier votre trajet, assurez-vous que toutes les informations saisies sont exactes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                const SizedBox(height: 16),

                // Messages d'avertissement
                _buildWarningRow(
                  'Une fois publié, vous ne pourrez pas modifier votre annonce.',
                ),
                const SizedBox(height: 10),
                _buildWarningRow(
                  'Si une erreur est détectée, vous devrez recommencer la saisie.',
                ),
                const SizedBox(height: 10),
                _buildWarningRow(
                  'Vérifiez bien votre lieu de départ, destination, date et heure.',
                ),
                const SizedBox(height: 24),

                // Boutons du dialogue
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: const Text('Retour'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _saveToFirestore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Ligne d'avertissement pour le dialogue
  Widget _buildWarningRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Colors.amber, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // Méthode pour sauvegarder dans Firestore
  Future<void> _saveToFirestore() async {
    try {
      // Vérifier que l'utilisateur est connecté
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez être connecté pour ajouter un trajet'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text("Publication en cours..."),
                ],
              ),
            ),
          );
        },
      );

      // Sauvegarder uniquement l'ID du véhicule dans la collection trips
      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user!.uid,
        'départ': _departureController.text,
        'arrivée': _arrivalController.text,
        'date': _dateController.text,
        'heure': _timeController.text,
        'prix': double.tryParse(_priceController.text) ?? 0,
        'méthodePaiement': _selectedPaymentMethod,
        'nbrPlaces': _seatCount,
        'placesDisponibles': _seatCount,
        'bagage': _selectedLuggage,
        'fumer': _selectedSmoking,
        'animal': _selectedAnimal,
        'climatisation': _selectedAirConditioning,
        'typePassagers': _selectedPassengersType,
        'description': _descriptionController.text,
        'status': 'en attente',
        'createdAt': FieldValue.serverTimestamp(),
        'vehiculeId': _selectedCar?.id ?? '',
      });

      // Fermer le dialogue de chargement
      Navigator.of(context).pop();

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Trajet ajouté avec succès',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Retourner à l'écran précédent
      Navigator.pop(context);
    } catch (e) {
      // Fermer le dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();

      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la publication: $e',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
