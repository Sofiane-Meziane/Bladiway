import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'maps.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InfoTrajet extends StatefulWidget {
  const InfoTrajet({Key? key}) : super(key: key);

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
  final TextEditingController _descriptionController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();

  // Valeurs des menus déroulants
  String _selectedLuggage = 'Non Autorisé';
  String _selectedSmoking = 'Non Autorisé';
  String _selectedAnimal = 'Non Autorisé';
  String _selectedAirConditioning = 'Non Autorisé';
  String _selectedPaymentMethod = 'Espèces';

  // État d'expansion des sections
  bool _isOptionsExpanded = false;

  // Nombre de places disponibles
  int _seatCount = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Définir les couleurs personnalisées
    final primaryColor = const Color(0xFF42A5F5); // Nouveau bleu principal
    final accentColor = const Color(0xFF2E7D32); // Nouveau vert pour l'accent
    final backgroundColor = Colors.white;
    final surfaceColor = const Color(0xFFF5F7FA);

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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        filled: true,
                        fillColor: Colors.white,
                      ),
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

  // Widget pour sélectionner le nombre de places - CORRIGÉ
  Widget _buildSeatSelector(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Places', style: TextStyle(fontSize: 16)),
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
                      color: primaryColor,
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
                      color: primaryColor,
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
                      color: primaryColor,
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
    return TextField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.calendar_today),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      readOnly: true,
      onTap: () => _pickDate(primaryColor),
    );
  }

  // Widget pour le champ d'heure
  Widget _buildTimeField(Color primaryColor) {
    return TextField(
      controller: _timeController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Heure',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.access_time),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      onTap: () => _pickTime(primaryColor),
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

  // Widget pour les options
  Widget _buildOptionRow(
    String label,
    String currentValue,
    void Function(String?) onChanged, {
    required Color primaryColor,
  }) {
    final List<String> dropdownOptions = ['Autorisé', 'Non Autorisé'];
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon, color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        suffixIcon:
            isLocationField
                ? IconButton(
                  icon: Icon(Icons.map_outlined, color: primaryColor),
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
        fillColor: Colors.white,
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
    if (!_areRequiredFieldsFilled()) {
      _showValidationErrors();
      return;
    }
    showConfirmationDialog();
  }

  // Dialogue de confirmation
  void showConfirmationDialog() {
    final primaryColor = const Color(0xFF42A5F5); // Nouveau bleu

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
                      const Color(0xFF42A5F5),
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

      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user!.uid,
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
        'description': _descriptionController.text,
        'status': 'en attente',
        'createdAt': FieldValue.serverTimestamp(),
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
          backgroundColor: const Color(0xFF2E7D32),
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
