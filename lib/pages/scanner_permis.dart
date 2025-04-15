import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';

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
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _validateLicenseNumber(String? value) {
    if (value!.isEmpty) return 'validation.license_number'.tr();
    return null;
  }

  String? _validateExpirationDate(String? value) {
    if (value!.isEmpty) return 'validation.expiration_date'.tr();
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
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('uploading.image_error'.tr());
      throw Exception('uploading.image_error'.tr());
    }
  }

  Future<void> transmitLicense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error.select_both_images'.tr())));
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error.not_logged_in'.tr())));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      await userDoc.set({
        'num_permis': licenseNumber,
        'date_expiration_permis': expirationDate,
        'recto_permis': frontImageUrl,
        'verso_permis': backImageUrl,
        'isValidated': false,
      }, SetOptions(merge: true));

      await _checkAndUpdateValidationStatus(user);

      setState(() {
        _isLoading = false;
      });

      // Afficher un dialogue de succès
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('error.license_update_failed'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error.license_update_failed'.tr())),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 30),
              const SizedBox(width: 10),
              Text(
                'Succès',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          content: const Text(
            'Vos informations ont été enregistrées avec succès. Elles seront examinées par notre équipe.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer le dialogue
                Navigator.of(context).pop(); // Revenir à l'écran précédent
              },
              child: Text(
                'OK',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

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

      if (hasLicense && hasCar) {
        print('info.waiting_admin_validation'.tr());
      }
    } catch (e) {
      print('error.validation_check_failed'.tr());
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
        title: Text(
          'appbar.title'.tr(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Stack(
        children: [
          Padding(
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
                        labelText: 'form.license_number'.tr(),
                        prefixIcon: Icon(
                          Icons.credit_card,
                          color: primaryColor,
                        ),
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
                        labelText: 'form.expiration_date'.tr(),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: primaryColor,
                        ),
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
                    const SizedBox(height: 20),
                    _buildImageSelector(
                      onTap: () => _selectImage(ImageSource.gallery, true),
                      hasImage: _frontImage != null,
                      textKeyWhenSelected: 'upload.front_selected',
                      textKeyWhenNotSelected: 'upload.select_front',
                    ),
                    const SizedBox(height: 16),
                    _buildImageSelector(
                      onTap: () => _selectImage(ImageSource.gallery, false),
                      hasImage: _backImage != null,
                      textKeyWhenSelected: 'upload.back_selected',
                      textKeyWhenNotSelected: 'upload.select_back',
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : transmitLicense,
                      child: Text(
                        "Envoyer mes données",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: Text(
                        'button.back'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSelector({
    required VoidCallback onTap,
    required bool hasImage,
    required String textKeyWhenSelected,
    required String textKeyWhenNotSelected,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:
              hasImage
                  ? Colors.green.withOpacity(0.2)
                  : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImage ? Colors.green : primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasImage ? Icons.check_circle : Icons.camera_alt,
              color: hasImage ? Colors.green : primaryColor,
            ),
            const SizedBox(width: 10),
            Text(
              hasImage ? textKeyWhenSelected.tr() : textKeyWhenNotSelected.tr(),
              style: TextStyle(
                color: hasImage ? Colors.green : primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
