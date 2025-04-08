import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

class LicenseVerificationScreen extends StatefulWidget {
  const LicenseVerificationScreen({super.key});

  @override
  _LicenseVerificationScreenState createState() =>
      _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState extends State<LicenseVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _expirationDateController = TextEditingController();

  XFile? _frontImage;
  XFile? _backImage;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _validateLicenseNumber(String? value) {
    if (value!.isEmpty) return 'Veuillez entrer le numéro de permis';
    return null;
  }

  String? _validateExpirationDate(String? value) {
    if (value!.isEmpty) return 'Veuillez entrer la date d\'expiration';
    return null;
  }

  Future<void> _selectImage(ImageSource source, bool isFront) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        if (isFront) {
          _frontImage = pickedFile;
        } else {
          _backImage = pickedFile;
        }
      });
    }
  }

  Future<String> _uploadImage(XFile image, String fileName) async {
    try {
      final storageRef = _storage.ref().child('license_images/$fileName');
      final bytes = await image.readAsBytes();
      final uploadTask = storageRef.putData(Uint8List.fromList(bytes));
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Erreur lors du téléchargement de l\'image : $e');
      throw Exception('Erreur lors du téléchargement de l\'image');
    }
  }

  Future<void> updateLicenseInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner les deux images (recto et verso)',
          ),
        ),
      );
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour continuer'),
        ),
      );
      return;
    }

    String frontImageUrl = await _uploadImage(
      _frontImage!,
      '${user.uid}_front_image.jpg',
    );
    String backImageUrl = await _uploadImage(
      _backImage!,
      '${user.uid}_back_image.jpg',
    );

    String licenseNumber = _licenseNumberController.text;
    String expirationDate = _expirationDateController.text;

    DocumentReference userDoc = _firestore.collection('users').doc(user.uid);

    try {
      await userDoc.set({
        'num_permis': licenseNumber,
        'date_expiration_permis': expirationDate,
        'recto_permis': frontImageUrl,
        'verso_permis': backImageUrl,
        'isValidated': false, // Assurer que isValidated reste false ici
      }, SetOptions(merge: true));

      // Vérifier si toutes les informations sont saisies
      await _checkAndUpdateValidationStatus(user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations sur le permis mises à jour avec succès!'),
        ),
      );
    } catch (e) {
      print('Erreur lors de la mise à jour du document utilisateur : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreur lors de la mise à jour des informations du permis',
          ),
        ),
      );
    }
  }

  /// Vérifie si toutes les informations (permis + voiture) sont saisies
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

      // Ne met pas à jour isValidated ici, car cela nécessite la validation admin
      if (hasLicense && hasCar) {
        print(
          'Toutes les informations sont saisies, en attente de validation admin.',
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut : $e');
    }
  }

  void _showImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Center(
            child: Image.asset(
              'assets/images/drivinglicence.jpg',
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _expirationDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vérification du permis',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: InputDecoration(
                    labelText: 'Numéro de permis',
                    prefixIcon: Icon(Icons.credit_card, color: primaryColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.info_outline, color: primaryColor),
                      onPressed: _showImageDialog,
                    ),
                  ),
                  validator: _validateLicenseNumber,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expirationDateController,
                  decoration: InputDecoration(
                    labelText: 'Date d\'expiration',
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validateExpirationDate,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? selectedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (selectedDate != null) {
                      _expirationDateController.text =
                          '${selectedDate.toLocal()}'.split(' ')[0];
                    }
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectImage(ImageSource.gallery, true),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _frontImage != null
                              ? Colors.green
                              : primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          _frontImage != null
                              ? 'Recto sélectionné'
                              : 'Sélectionner le recto du permis',
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectImage(ImageSource.gallery, false),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _backImage != null
                              ? Colors.green
                              : primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          _backImage != null
                              ? 'Verso sélectionné'
                              : 'Sélectionner le verso du permis',
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: updateLicenseInfo,
                  child: const Text(
                    "Mettre à jour les informations du permis",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Retour',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
