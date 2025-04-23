import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

class IdentityVerificationScreen extends StatefulWidget {
  final String? forcedIdType; // Si spécifié, l'utilisateur ne peut pas changer le type de pièce

  const IdentityVerificationScreen({this.forcedIdType, super.key});

  @override
  _IdentityVerificationScreenState createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _expirationDateController = TextEditingController();

  XFile? _frontImage;
  XFile? _backImage;
  bool _isLoading = false;

  String _selectedIdType = 'permis'; // Valeur par défaut

  final List<Map<String, String>> _idTypes = [
    {'value': 'carte_identité', 'label': 'Carte d\'identité'},
    {'value': 'permis', 'label': 'Permis de conduire'},
    {'value': 'passeport', 'label': 'Passeport'},
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.forcedIdType != null) {
      _selectedIdType = widget.forcedIdType!;
    }
  }

  String? _validateIdNumber(String? value) {
    if (value!.isEmpty) return 'Veuillez entrer le numéro de la pièce d\'identité';
    return null;
  }

  String? _validateExpirationDate(String? value) {
    if (value!.isEmpty) return 'Veuillez entrer la date d\'expiration';
    return null;
  }

  // Vérifie si le type de document sélectionné nécessite une image verso
  bool _needsBackImage() {
    return _selectedIdType != 'passeport';
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
      final storageRef = _storage.ref().child('identity_docs/$fileName');
      final bytes = await image.readAsBytes();
      final uploadTask = storageRef.putData(Uint8List.fromList(bytes));
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Erreur lors du téléchargement de l\'image');
      throw Exception('Erreur lors du téléchargement de l\'image');
    }
  }

  Future<void> submitIdentityDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frontImage == null || (_needsBackImage() && _backImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_needsBackImage() 
          ? 'Veuillez sélectionner les deux faces de votre pièce d\'identité' 
          : 'Veuillez sélectionner une image de votre passeport')),
      );
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour effectuer cette action')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
  String frontImageUrl = await _uploadImage(
    _frontImage!,
    '${user.uid}_${_selectedIdType}_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );

  String? backImageUrl;
  if (_needsBackImage() && _backImage != null) {
    backImageUrl = await _uploadImage(
      _backImage!,
      '${user.uid}_${_selectedIdType}_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  String idNumber = _idNumberController.text;
  String expirationDate = _expirationDateController.text;

  Map<String, dynamic> idData = {
    'id_proprietaire': user.uid,
    'type_piece': _selectedIdType,
    'num_piece': idNumber,
    'date_expiration': expirationDate,
    'recto_piece': frontImageUrl,
    'statut': 'en cours',
    'date_soumission': FieldValue.serverTimestamp(),
  };

  if (_needsBackImage() && backImageUrl != null) {
    idData['verso_piece'] = backImageUrl;
  }

  // 🔁 Nouvelle structure : on ajoute un document dans piece_identite
  await _firestore.collection('piece_identite').add(idData);

  setState(() {
    _isLoading = false;
  });

  _showSuccessDialog();
} catch (e) {
  setState(() {
    _isLoading = false;
  });
  print('Erreur lors de la mise à jour: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Erreur lors de l\'enregistrement de votre pièce d\'identité')),
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
            'Votre pièce d\'identité a été enregistrée avec succès. Elle sera examinée par notre équipe.',
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

  
  void _showImageDialog() {
    // Adapter l'image à afficher en fonction du type de pièce sélectionné
    String assetPath;
    
    switch (_selectedIdType) {
      case 'permis':
        assetPath = 'assets/images/drivinglicence.jpg';
        break;
      case 'carte_identité':
        assetPath = 'assets/images/identity_card.jpg';
        break;
      case 'passeport':
        assetPath = 'assets/images/passport.jpg';
        break;
      default:
        assetPath = 'assets/images/identity_card.jpg';
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Center(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  String _getImageSelectorText(bool isFront, bool hasImage) {
    if (hasImage) {
      return isFront ? 'Recto sélectionné' : 'Verso sélectionné';
    } else {
      return isFront ? 'Sélectionner le recto' : 'Sélectionner le verso';
    }
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _expirationDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vérification d\'identité',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                    // Dropdown pour sélectionner le type de pièce d'identité
                    DropdownButtonFormField<String>(
                      value: _selectedIdType,
                      decoration: InputDecoration(
                        labelText: 'Type de pièce d\'identité',
                        prefixIcon: Icon(Icons.badge, color: primaryColor),
                        border: const OutlineInputBorder(),
                      ),
                      items: _idTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type['value'],
                          child: Text(type['label']!),
                        );
                      }).toList(),
                      onChanged: widget.forcedIdType == null
                          ? (value) {
                              setState(() {
                                _selectedIdType = value!;
                                // Réinitialiser _backImage si on passe à passeport
                                if (!_needsBackImage()) {
                                  _backImage = null;
                                }
                              });
                            }
                          : null, // Désactiver le changement si forcedIdType est spécifié
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idNumberController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de la pièce',
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
                      validator: _validateIdNumber,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _expirationDateController,
                      decoration: InputDecoration(
                        labelText: 'Date d\'expiration',
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
                      labelText: _getImageSelectorText(true, _frontImage != null),
                    ),
                    const SizedBox(height: 16),
                    // Affiche le sélecteur d'image verso uniquement si nécessaire
                    if (_needsBackImage())
                      _buildImageSelector(
                        onTap: () => _selectImage(ImageSource.gallery, false),
                        hasImage: _backImage != null,
                        labelText: _getImageSelectorText(false, _backImage != null),
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
                      onPressed: _isLoading ? null : submitIdentityDocument,
                      child: const Text(
                        "Envoyer ma pièce d'identité",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
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
    required String labelText,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:
              hasImage ? Colors.green.withOpacity(0.2) : primaryColor.withOpacity(0.1),
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
              labelText,
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