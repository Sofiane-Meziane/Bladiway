import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'mes_voitures_page.dart';

class CarRegistrationScreen extends StatefulWidget {
  const CarRegistrationScreen({super.key});

  @override
  CarRegistrationScreenState createState() => CarRegistrationScreenState();
}

class CarRegistrationScreenState extends State<CarRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  String? _selectedYear;
  String? _selectedColor;
  File? _carImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Expanded color options with modern names
  final List<String> _colors = [
    'Rouge',
    'Bleu',
    'Noir',
    'Blanc',
    'Gris',
    'Vert',
    'Jaune',
    'Orange',
    'Violet',
    'Rose',
    'Marron',
    'Argent',
    'Or',
    'Bronze',
    'Turquoise',
    'Beige',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  String? _validatePlate(String? value) {
    if (value!.isEmpty) return tr('validation.plate');
    return null;
  }

  String? _validateColor(String? value) {
    if (value == null) return tr('validation.color');
    return null;
  }

  String? _validateYear(String? value) {
    if (value == null) return tr('validation.year');
    return null;
  }

  Future<void> _pickCarImage() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedImage != null) {
      setState(() {
        _carImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _takeCarPhoto() async {
    final XFile? takenPhoto = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (takenPhoto != null) {
      setState(() {
        _carImage = File(takenPhoto.path);
      });
    }
  }

  Future<String?> _uploadCarImage(String userId) async {
    if (_carImage == null) return null;

    try {
      String fileName = '${userId}_${path.basename(_carImage!.path)}';
      Reference storageRef = _storage.ref().child('car_images/$fileName');

      UploadTask uploadTask = storageRef.putFile(_carImage!);
      await uploadTask.whenComplete(() => null);

      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Erreur lors du téléchargement de l\'image: $e');
      _showSnackBar(tr('error.image_upload'));
      return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> startCarRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if image is selected
    if (_carImage == null) {
      _showSnackBar(tr('validation.car_image'));
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      _showSnackBar(tr('error.not_logged_in'));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    String make = _makeController.text;
    String model = _modelController.text;
    String plate = _plateController.text;
    String vin = _vinController.text;
    String idProprietaire = user.uid;

    try {
      // Upload image
      String? imageUrl = await _uploadCarImage(idProprietaire);

      await saveCarRegistration(
        make,
        model,
        _selectedYear!,
        _selectedColor!,
        plate,
        vin,
        idProprietaire,
        imageUrl,
      );

      // Check and update validation status
      await _checkAndUpdateValidationStatus(user);

      _showSnackBar(tr('success.registration'));

      // Return to previous screen after successful registration
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => MesVoituresPage()),
);
    } catch (e) {
      _showSnackBar(tr('error.registration'));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  List<String> _generateYears() {
    int currentYear = DateTime.now().year;
    List<String> years = [];
    for (int i = currentYear; i >= 1950; i--) {
      years.add(i.toString());
    }
    return years;
  }

  Future<void> saveCarRegistration(
    String make,
    String model,
    String year,
    String color,
    String plate,
    String vin,
    String id,
    String? imageUrl,
  ) async {
    try {
      await _firestore.collection('cars').add({
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'plate': plate,
        'vin': vin,
        'id_proprietaire': id,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Erreur lors de l\'enregistrement de la voiture: $e');
      throw Exception('Failed to register car');
    }
  }

  /// Check if all information (license + car) is entered
  Future<void> _checkAndUpdateValidationStatus(User user) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      bool hasLicense =
          userDoc['recto_permis'] != null && userDoc['verso_permis'] != null;
      QuerySnapshot carsSnapshot =
          await _firestore
              .collection('cars')
              .where('id_proprietaire', isEqualTo: user.uid)
              .limit(1)
              .get();
      bool hasCar = carsSnapshot.docs.isNotEmpty;

      // Does not update isValidated here, as it requires admin validation
      if (hasLicense && hasCar) {
        print(
          'Toutes les informations sont saisies, en attente de validation admin.',
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut : $e');
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Custom input decoration with 3D-like effect
  InputDecoration _getInputDecoration(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      filled: true,
      fillColor:
          isDark ? Theme.of(context).colorScheme.surface : Colors.grey[50],
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 2.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[600],
      ),
    );
  }

  // Styling for dropdown
  InputDecoration _getDropdownDecoration(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      filled: true,
      fillColor:
          isDark ? Theme.of(context).colorScheme.surface : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          tr('appbar.add_car'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, primaryColor.withOpacity(0.7)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark
                    ? [Colors.grey[900]!, Colors.grey[850]!]
                    : [Colors.grey[100]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Car photo section
                      Card(
                        elevation: 4,
                        color: surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child:
                                _carImage != null
                                    ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Hero(
                                          tag: 'carImage',
                                          child: Image.file(
                                            _carImage!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black.withOpacity(0.7),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              tr('form.your_car'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.add_a_photo,
                                            size: 50,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        
                                      ],
                                    ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Photo selection buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library, size: 20),
                              label: Text(tr('gallery')),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor: secondaryColor.withOpacity(0.5),
                              ),
                              onPressed: _pickCarImage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt, size: 20),
                              label: Text(tr('button.camera')),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor: primaryColor.withOpacity(0.5),
                              ),
                              onPressed: _takeCarPhoto,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Form fields with enhanced styling
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('form.car_details'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Make field
                            TextFormField(
                              controller: _makeController,
                              decoration: _getInputDecoration(
                                tr('form.make'),
                                Icons.directions_car,
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? tr('validation.make')
                                          : null,
                            ),
                            const SizedBox(height: 16),

                            // Model field
                            TextFormField(
                              controller: _modelController,
                              decoration: _getInputDecoration(
                                tr('form.model'),
                                Icons.drive_eta,
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? tr('validation.model')
                                          : null,
                            ),
                            const SizedBox(height: 16),

                            // Year dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: _getDropdownDecoration(
                                tr('form.year'),
                                Icons.calendar_today,
                              ),
                              items:
                                  _generateYears().map((year) {
                                    return DropdownMenuItem<String>(
                                      value: year,
                                      child: Text(year),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value;
                                });
                              },
                              validator: _validateYear,
                              dropdownColor: surfaceColor,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: primaryColor,
                              ),
                              isExpanded: true,
                            ),
                            const SizedBox(height: 16),

                            // Color dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedColor,
                              decoration: _getDropdownDecoration(
                                tr('form.color'),
                                Icons.color_lens,
                              ),
                              items:
                                  _colors.map((color) {
                                    return DropdownMenuItem<String>(
                                      value: color,
                                      child: Text(color),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedColor = value;
                                });
                              },
                              validator: _validateColor,
                              dropdownColor: surfaceColor,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: primaryColor,
                              ),
                              isExpanded: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Registration details section
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('form.registration_details'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Plate field
                            TextFormField(
                              controller: _plateController,
                              decoration: _getInputDecoration(
                                tr('form.plate'),
                                Icons.confirmation_number,
                              ),
                              validator: _validatePlate,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 16),

                            // VIN field
                            TextFormField(
                              controller: _vinController,
                              decoration: _getInputDecoration(
                                tr('form.vin'),
                                Icons.vpn_key,
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? tr('validation.vin')
                                          : null,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Register button with 3D effect
                      Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          onPressed:
                              _isSubmitting ? null : startCarRegistration,
                          child:
                              _isSubmitting
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    tr('button.register_car'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Back button
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                        child: Text(
                          tr('button.back'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
