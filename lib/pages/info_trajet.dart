import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'maps.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InfoTrajet extends StatefulWidget {
  const InfoTrajet({super.key});

  @override
  _InfoTrajetState createState() => _InfoTrajetState();
}

class _InfoTrajetState extends State<InfoTrajet>
    with AutomaticKeepAliveClientMixin {
  // Contrôleurs pour les champs de texte
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  // Nouveaux contrôleurs pour les informations d'itinéraire
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _wayPointsController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  TimeOfDay _selectedTime = TimeOfDay.now();

  // Valeurs des menus déroulants
  String _selectedLuggage = 'Non Autorisé';
  String _selectedSmoking = 'Non Autorisé';
  String _selectedAnimal = 'Non Autorisé';
  String _selectedAirConditioning = 'Non Autorisé';
  final String _selectedPaymentMethod = 'Espèces';

  // Nouveau menu déroulant pour le type de route
  String _selectedRouteType = 'Autoroute';
  final List<String> _routeTypes = [
    'Autoroute',
    'Route nationale',
    'Route secondaire',
    'Itinéraire mixte',
  ];

  // Option pour les arrêts
  bool _hasPlannedStops = false;

  // Nombre de places disponibles
  int _seatCount = 1;

  // État d'expansion des sections
  bool _isRouteDetailsExpanded = false;
  bool _isOptionsExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BladiWay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              'Saisir un point de départ',
              _departureController,
              Icons.location_on,
              isLocationField: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Saisir un point d\'arrivée',
              _arrivalController,
              Icons.location_on,
              isLocationField: true,
            ),
            const SizedBox(height: 12),

            // Champ date
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
              ),
              readOnly: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),

            // Champ heure
            TextField(
              controller: _timeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Heure',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.access_time),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 12),

            // Champ de prix
            _buildTextField(
              'Prix (DA)',
              _priceController,
              Icons.attach_money,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Mode de paiement
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paiement'),
                  Row(
                    children: [
                      const Icon(Icons.money, color: Colors.green, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Espèces',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sélecteur de places
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Places'),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:
                            () => setState(() {
                              _seatCount =
                                  _seatCount > 1 ? _seatCount - 1 : _seatCount;
                            }),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_seatCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:
                            () => setState(() {
                              _seatCount =
                                  _seatCount < 7 ? _seatCount + 1 : _seatCount;
                            }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section d'information sur l'itinéraire avec expansion
            _buildExpandableSection(
              title: 'Détails de l\'itinéraire',
              icon: Icons.route,
              isExpanded: _isRouteDetailsExpanded,
              onTap:
                  () => setState(
                    () => _isRouteDetailsExpanded = !_isRouteDetailsExpanded,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type de route - dropdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRouteType,
                        hint: const Text('Type de route'),
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        items:
                            _routeTypes
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() => _selectedRouteType = newValue);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Points de passage
                  TextField(
                    controller: _wayPointsController,
                    decoration: InputDecoration(
                      labelText: 'Points de passage',
                      hintText: 'Ex: Blida, Médéa...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.signpost),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Distance
                  TextField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Distance (km)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.straighten),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Durée
                  TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: 'Durée (h:min)',
                      hintText: 'Ex: 1:30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.timer),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option pour arrêts prévus
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SwitchListTile(
                      title: const Text('Arrêts prévus'),
                      value: _hasPlannedStops,
                      activeColor: Theme.of(context).colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      onChanged: (bool value) {
                        setState(() {
                          _hasPlannedStops = value;
                        });
                      },
                    ),
                  ),

                  // Description complète
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description détaillée',
                      hintText:
                          'Informations supplémentaires sur votre itinéraire...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Options de trajet avec expansion
            _buildExpandableSection(
              title: 'Options du trajet',
              icon: Icons.settings,
              isExpanded: _isOptionsExpanded,
              onTap:
                  () =>
                      setState(() => _isOptionsExpanded = !_isOptionsExpanded),
              child: Column(
                children: [
                  _buildSimpleDropdownRow(
                    'Bagage',
                    _selectedLuggage,
                    (newValue) => setState(() => _selectedLuggage = newValue!),
                  ),
                  const Divider(height: 1),
                  _buildSimpleDropdownRow(
                    'Fumer',
                    _selectedSmoking,
                    (newValue) => setState(() => _selectedSmoking = newValue!),
                  ),
                  const Divider(height: 1),
                  _buildSimpleDropdownRow(
                    'Animal',
                    _selectedAnimal,
                    (newValue) => setState(() => _selectedAnimal = newValue!),
                  ),
                  const Divider(height: 1),
                  _buildSimpleDropdownRow(
                    'Climatisation',
                    _selectedAirConditioning,
                    (newValue) =>
                        setState(() => _selectedAirConditioning = newValue!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Bouton Partager
            ElevatedButton(
              onPressed: _saveTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Partager'),
            ),

            const SizedBox(height: 12),

            // Bouton Annuler
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Annuler'),
            ),
          ],
        ),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(padding: const EdgeInsets.all(12.0), child: child),
        ],
      ),
    );
  }

  // Dropdown simplifié pour éviter l'overflow
  Widget _buildSimpleDropdownRow(
    String label,
    String currentValue,
    void Function(String?) onChanged,
  ) {
    final List<String> dropdownOptions = ['Autorisé', 'Non Autorisé'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          DropdownButton<String>(
            value: currentValue,
            isDense: true,
            underline: Container(),
            items:
                dropdownOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Méthode pour sélectionner une date
  DateTime _selectedDate = DateTime.now();
  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
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
  Future<void> _pickTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text(
              'Vous ne pouvez pas sélectionner une heure passée aujourd’hui',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onError,
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon),
        suffixIcon:
            isLocationField
                ? IconButton(
                  icon: Icon(
                    Icons.map_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
          vertical: 10,
          horizontal: 10,
        ),
      ),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Méthode pour sauvegarder le trajet
  Future<void> _saveTrip() async {
    if (!_areRequiredFieldsFilled()) {
      _showValidationErrors();
      return;
    }
    showConfirmationDialog();
  }

  // Dialogue de confirmation
  void showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Attention !',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  'Avant de publier votre trajet, assurez-vous que toutes les informations saisies sont exactes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Messages d'avertissement
                _buildWarningRow(
                  'Une fois publié, vous ne pourrez pas modifier votre annonce.',
                ),
                const SizedBox(height: 8),
                _buildWarningRow(
                  'Si une erreur est détectée, vous devrez recommencer la saisie.',
                ),
                const SizedBox(height: 8),
                _buildWarningRow(
                  'Vérifiez bien votre lieu de départ, destination, date et heure.',
                ),
                const SizedBox(height: 20),

                // Boutons du dialogue
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveToFirestore();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Confirmer'),
                ),

                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Retourner'),
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
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user!.uid, // Ajouter l'ID de l'utilisateur
        'départ': _departureController.text,
        'arrivée': _arrivalController.text,
        'date': _dateController.text,
        'heure': _timeController.text,
        'prix': double.tryParse(_priceController.text) ?? 0,
        'méthodePaiement': _selectedPaymentMethod,
        'nbrPlaces': _seatCount,
        'bagage': _selectedLuggage,
        'fumer': _selectedSmoking,
        'animal': _selectedAnimal,
        'climatisation': _selectedAirConditioning,
        'typeRoute': _selectedRouteType,
        'pointsDePassage': _wayPointsController.text,
        'distance': _distanceController.text,
        'durée': _durationController.text,
        'arrêtsPrévus': _hasPlannedStops,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout du trajet: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
    _wayPointsController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
