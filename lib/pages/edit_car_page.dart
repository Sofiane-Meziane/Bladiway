import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class EditCarPage extends StatefulWidget {
  final DocumentSnapshot voiture;

  const EditCarPage({super.key, required this.voiture});

  @override
  _EditCarPageState createState() => _EditCarPageState();
}

class _EditCarPageState extends State<EditCarPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _marqueController;
  late TextEditingController _modeleController;
  late TextEditingController _immatriculationController;
  late TextEditingController _anneeController;
  late TextEditingController _couleurController;
  File? _imageFile;
  String? _imageUrl;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Couleurs pour le design moderne
  final Color _primaryColor = Color(0xFF3A86FF);
  final Color _secondaryColor = Color(0xFF8338EC);
  final Color _backgroundColor = Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    final data = widget.voiture.data() as Map<String, dynamic>;
    _marqueController = TextEditingController(text: data['make']);
    _modeleController = TextEditingController(text: data['model']);
    _immatriculationController = TextEditingController(text: data['plate']);
    _anneeController = TextEditingController(text: data['year']);
    _couleurController = TextEditingController(text: data['color']);
    _imageUrl = data['imageUrl'];

    // Initialisation de l'animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _marqueController.dispose();
    _modeleController.dispose();
    _immatriculationController.dispose();
    _anneeController.dispose();
    _couleurController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    // Animation lors du clic
    _animationController.forward().then((_) => _animationController.reverse());

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });

      // Feedback haptique léger
      HapticFeedback.lightImpact();
    }
  }

  Future<String?> _uploadImage(String voitureId) async {
    if (_imageFile == null) return _imageUrl;

    final ref = FirebaseStorage.instance.ref().child('car_images/$voitureId.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final voitureId = widget.voiture.id;
        final imageUrl = await _uploadImage(voitureId);

        await FirebaseFirestore.instance.collection('cars').doc(voitureId).update({
          'make': _marqueController.text.trim(),
          'model': _modeleController.text.trim(),
          'plate': _immatriculationController.text.trim(),
          'year': _anneeController.text.trim(),
          'color': _couleurController.text.trim(),
          'imageUrl': imageUrl,
        });

        // Feedback haptique pour confirmer la sauvegarde
        HapticFeedback.mediumImpact();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voiture modifiée avec succès'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la modification'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildNeumorphicField({
    required Widget child,
    double height = 60,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: height,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: Offset(3, 3),
            blurRadius: 5,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-3, -3),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _primaryColor,
        title: Text(
          'Modifier la voiture',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSaving
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Enregistrement en cours...',
              style: GoogleFonts.poppins(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informations du véhicule',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Modifiez les détails et l\'image de votre voiture',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),

                // Zone d'image avec effet 3D
                Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _imageFile != null
                                      ? Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                  )
                                      : _imageUrl != null
                                      ? Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                              : null,
                                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                        ),
                                      );
                                    },
                                  )
                                      : Container(
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.directions_car,
                                      size: 70,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.6],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 15,
                                    left: 15,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _primaryColor.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Modifier l\'image',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 30),

                // Champs de formulaire avec design neumorphique
                _buildNeumorphicField(
                  child: TextFormField(
                    controller: _marqueController,
                    decoration: InputDecoration(
                      labelText: 'Marque',
                      prefixIcon: Icon(Icons.branding_watermark, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                    ),
                    style: GoogleFonts.poppins(),
                    validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                  ),
                ),

                _buildNeumorphicField(
                  child: TextFormField(
                    controller: _modeleController,
                    decoration: InputDecoration(
                      labelText: 'Modèle',
                      prefixIcon: Icon(Icons.model_training, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                    ),
                    style: GoogleFonts.poppins(),
                    validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                  ),
                ),

                _buildNeumorphicField(
                  child: TextFormField(
                    controller: _immatriculationController,
                    decoration: InputDecoration(
                      labelText: 'Immatriculation',
                      prefixIcon: Icon(Icons.credit_card, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                    ),
                    style: GoogleFonts.poppins(),
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildNeumorphicField(
                        child: TextFormField(
                          controller: _anneeController,
                          decoration: InputDecoration(
                            labelText: 'Année',
                            prefixIcon: Icon(Icons.date_range, color: _primaryColor),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                          ),
                          style: GoogleFonts.poppins(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildNeumorphicField(
                        child: TextFormField(
                          controller: _couleurController,
                          decoration: InputDecoration(
                            labelText: 'Couleur',
                            prefixIcon: Icon(Icons.color_lens, color: _primaryColor),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 40),

                // Bouton avec effet 3D
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _saveChanges,
                        splashColor: Colors.white.withOpacity(0.2),
                        highlightColor: Colors.transparent,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.save_alt,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Enregistrer les modifications',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}