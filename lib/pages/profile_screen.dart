import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bladiway/methods/commun_methods.dart';
import 'package:bladiway/widgets/settings_widgets.dart';
import 'package:bladiway/methods/user_data_notifier.dart';
import 'package:bladiway/pages/phone_update_otp_screen.dart';
import 'package:bladiway/pages/email_update_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de saisie
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();

  String? _selectedGenre;
  final List<String> _genres = ['Homme', 'Femme'];

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _uid;
  String? _profileImageUrl;
  File? _newProfileImage;

  bool _isLoadingReviews = false;
  List<Map<String, dynamic>> _reviewsList = [];
  Map<String, dynamic> _reviewersData = {};

  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  TabController? _tabController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _identityStatus;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateNaissanceController.dispose();
    _animationController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        _uid = currentUser.uid;
        final doc = await _firestore.collection('users').doc(_uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          // Synchronisation email Firestore <-> Auth
          if (data['email'] != currentUser.email) {
            await _firestore.collection('users').doc(_uid).update({
              'email': currentUser.email,
            });
            data['email'] = currentUser.email;
          }
          setState(() {
            _nomController.text = data['nom'] ?? '';
            _prenomController.text = data['prenom'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone']?.replaceAll('+', '') ?? '';
            _dateNaissanceController.text = data['dateNaissance'] ?? '';
            _selectedGenre = data['genre'];
            _profileImageUrl = data['profileImageUrl'];
          });
          userDataNotifier.updateUserData(
            _prenomController.text,
            _profileImageUrl ?? '',
          );
        }
        // Vérifier le statut de la pièce d'identité la plus récente
        final pieceSnapshot =
            await _firestore
                .collection('piece_identite')
                .where('id_proprietaire', isEqualTo: _uid)
                .orderBy('date_soumission', descending: true)
                .limit(1)
                .get();
        if (pieceSnapshot.docs.isNotEmpty) {
          final pieceData = pieceSnapshot.docs.first.data();
          setState(() {
            _identityStatus = pieceData['statut'] as String?;
          });
        } else {
          setState(() {
            _identityStatus = null;
          });
        }
      }
      await _loadUserReviews();
    } catch (e) {
      CommunMethods().displaySnackBar(
        '${'Erreur'.tr()} : ${e.toString()}',
        context,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserReviews() async {
    if (_uid == null) return;

    setState(() => _isLoadingReviews = true);

    try {
      final QuerySnapshot reviewsSnapshot =
          await _firestore
              .collection('reviews')
              .where('ratedUserId', isEqualTo: _uid)
              .orderBy('timestamp', descending: true)
              .get();

      final List<Map<String, dynamic>> reviews = [];
      final Map<String, dynamic> reviewersInfo = {};
      final List<String> reviewerIds = [];

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        reviews.add({
          'id': doc.id,
          'comment': data['comment'] ?? '',
          'rating': data['rating'] ?? 0.0,
          'reviewerId': data['reviewerId'] ?? '',
          'timestamp': data['timestamp'],
          'tripId': data['tripId'] ?? '',
        });

        if (data['reviewerId'] != null &&
            data['reviewerId'].toString().isNotEmpty) {
          reviewerIds.add(data['reviewerId'].toString());
        }
      }

      for (String reviewerId in reviewerIds) {
        try {
          final userDoc =
              await _firestore.collection('users').doc(reviewerId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            reviewersInfo[reviewerId] = {
              'nom': userData['nom'] ?? '',
              'prenom': userData['prenom'] ?? '',
              'profileImageUrl': userData['profileImageUrl'] ?? '',
            };
          }
        } catch (e) {
          print(
            'Erreur lors de la récupération des informations du reviewer: $e',
          );
        }
      }

      setState(() {
        _reviewsList = reviews;
        _reviewersData = reviewersInfo;
      });
    } catch (e) {
      CommunMethods().displaySnackBar(
        '${'Erreur lors du chargement des avis'.tr()} : ${e.toString()}',
        context,
      );
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  void _toggleEditMode() {
    setState(() => _isEditing = !_isEditing);
    if (_isEditing) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _newProfileImage = File(pickedFile.path);
        });
        // Sauvegarde automatique
        final newProfileImageUrl = await _uploadProfileImage();
        if (newProfileImageUrl != null) {
          await _firestore.collection('users').doc(_uid).update({
            'profileImageUrl': newProfileImageUrl,
          });
          setState(() {
            _profileImageUrl = newProfileImageUrl;
            _newProfileImage = null;
          });
          userDataNotifier.updateUserData(
            _prenomController.text.trim(),
            newProfileImageUrl,
          );
          CommunMethods().displaySnackBar(
            'Photo de profil mise à jour avec succès',
            context,
          );
        }
      }
    } catch (e) {
      CommunMethods().displaySnackBar(
        '${'Erreur'.tr()} : ${e.toString()}',
        context,
      );
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return null;
    try {
      final storageRef = _storage.ref().child('profile_images/$_uid.jpg');
      await storageRef.putFile(_newProfileImage!);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      CommunMethods().displaySnackBar(
        '${'Erreur'.tr()} : ${e.toString()}',
        context,
      );
      return null;
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? newProfileImageUrl;
      if (_newProfileImage != null) {
        newProfileImageUrl = await _uploadProfileImage();
      }

      final updatedData = {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'dateNaissance': _dateNaissanceController.text.trim(),
        'genre': _selectedGenre,
        'updatedAt': DateTime.now(),
        if (newProfileImageUrl != null) 'profileImageUrl': newProfileImageUrl,
      };
      await _firestore.collection('users').doc(_uid).update(updatedData);

      final User? currentUser = _auth.currentUser;
      if (currentUser != null &&
          currentUser.email != _emailController.text.trim()) {
        await currentUser.updateEmail(_emailController.text.trim());
        await _firestore.collection('users').doc(_uid).update({
          'email': _emailController.text.trim(),
        });
      }

      if (newProfileImageUrl != null) {
        setState(() {
          _profileImageUrl = newProfileImageUrl;
          _newProfileImage = null;
        });
      }
      userDataNotifier.updateUserData(
        _prenomController.text.trim(),
        newProfileImageUrl ?? _profileImageUrl ?? '',
      );

      CommunMethods().displaySnackBar(
        'Profil mis à jour avec succès'.tr(),
        context,
      );
      _toggleEditMode();
    } catch (e) {
      CommunMethods().displaySnackBar(
        '${'Erreur'.tr()} : ${e.toString()}',
        context,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate() async {
    if (!_isEditing) return;
    DateTime initialDate =
        _dateNaissanceController.text.isNotEmpty
            ? DateFormat('dd/MM/yyyy').parse(_dateNaissanceController.text)
            : DateTime.now().subtract(const Duration(days: 365 * 25));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Widget _buildProfileInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    final brightness = Theme.of(context).brightness;
    final fillColor =
        brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200];
    final borderColor =
        brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey[300]!;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color:
            enabled
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Colors.grey,
      ),
      decoration: InputDecoration(
        labelText: label.tr(),
        prefixIcon: Icon(
          icon,
          color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreDropdown() {
    final brightness = Theme.of(context).brightness;
    final fillColor =
        brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200];
    final borderColor =
        brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey[300]!;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Genre'.tr(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            prefixIcon: const Icon(Icons.people),
          ),
          value: _selectedGenre,
          items:
              _genres
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.tr())),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedGenre = value),
          validator:
              (value) => value == null ? 'Ce champ est requis'.tr() : null,
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[300],
            backgroundImage:
                _newProfileImage != null
                    ? FileImage(_newProfileImage!)
                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : null),
            child:
                _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
          ),
          // Le bouton appareil photo est toujours visible et cliquable
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final reviewerId = review['reviewerId'] as String;
    final reviewerData = _reviewersData[reviewerId] ?? {};
    final nom = reviewerData['nom'] ?? '';
    final prenom = reviewerData['prenom'] ?? '';
    final profileImageUrl = reviewerData['profileImageUrl'] ?? '';

    final DateTime timestamp;
    if (review['timestamp'] is Timestamp) {
      timestamp = (review['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    final String formattedDate = DateFormat(
      'dd/MM/yyyy à HH:mm',
    ).format(timestamp);
    final comment = review['comment'] as String? ?? '';
    final rating =
        (review['rating'] is int)
            ? (review['rating'] as int).toDouble()
            : (review['rating'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                  child:
                      profileImageUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildRatingStars(rating),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comment, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return _isLoadingReviews
        ? Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        )
        : _reviewsList.isEmpty
        ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun avis pour le moment'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        )
        : RefreshIndicator(
          onRefresh: _loadUserReviews,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _reviewsList.length,
            itemBuilder: (context, index) {
              return _buildReviewItem(_reviewsList[index]);
            },
          ),
        );
  }

  // Ajout : Méthodes pour modification du numéro
  void _showPhoneEditDialog() {
    final TextEditingController _newPhoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le numéro de téléphone'),
          content: TextField(
            controller: _newPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nouveau numéro',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPhone = _newPhoneController.text.trim();
                if (newPhone.isEmpty) {
                  CommunMethods().displaySnackBar(
                    'Veuillez entrer un numéro',
                    context,
                  );
                  return;
                }
                Navigator.pop(context);
                await _startPhoneVerification(newPhone);
              },
              child: const Text('Soumettre'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startPhoneVerification(String newPhone) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: newPhone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          CommunMethods().displaySnackBar('Erreur: \\${e.message}', context);
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PhoneUpdateOTPScreen(
                    verificationId: verificationId,
                    newPhone: newPhone,
                    onPhoneUpdated: (String updatedPhone) async {
                      setState(() {
                        _phoneController.text = updatedPhone;
                      });
                      CommunMethods().displaySnackBar(
                        'Numéro mis à jour avec succès',
                        context,
                      );
                      await _loadUserData();
                    },
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      CommunMethods().displaySnackBar('Erreur: \\${e.toString()}', context);
    }
  }

  // Ajout : Méthodes pour modification de l'email
  void _showEmailEditDialog() {
    final TextEditingController _newEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier l\'adresse e-mail'),
          content: TextField(
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Nouvel e-mail',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newEmail = _newEmailController.text.trim();
                if (newEmail.isEmpty) {
                  CommunMethods().displaySnackBar(
                    'Veuillez entrer un e-mail',
                    context,
                  );
                  return;
                }
                Navigator.pop(context);
                await _startEmailUpdate(newEmail);
              },
              child: const Text('Soumettre'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startEmailUpdate(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await user.verifyBeforeUpdateEmail(newEmail);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => EmailUpdateVerificationScreen(
                newEmail: newEmail,
                onEmailUpdated: (String updatedEmail) async {
                  setState(() {
                    _emailController.text = updatedEmail;
                  });
                  CommunMethods().displaySnackBar(
                    'Adresse e-mail mise à jour avec succès',
                    context,
                  );
                  await _loadUserData();
                },
              ),
        ),
      );
    } catch (e) {
      CommunMethods().displaySnackBar('Erreur: \\${e.toString()}', context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                : Column(
                  children: [
                    SettingsHeader(title: 'settings.my_profile'.tr()),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _buildProfilePhoto(),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'Profil'.tr()),
                        Tab(text: 'Mes avis'.tr()),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          SingleChildScrollView(
                            child: Form(
                              key: _formKey,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                child: Column(
                                  children: [
                                    SettingsCard(
                                      title: 'Informations personnelles'.tr(),
                                      icon: Icons.person,
                                      children: [
                                        _buildProfileInput(
                                          controller: _nomController,
                                          label: 'Nom',
                                          icon: Icons.person,
                                          enabled:
                                              _isEditing &&
                                              (_identityStatus == null ||
                                                  _identityStatus != 'verifie'),
                                          validator:
                                              (value) =>
                                                  value!.isEmpty
                                                      ? 'Ce champ est requis'
                                                          .tr()
                                                      : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildProfileInput(
                                          controller: _prenomController,
                                          label: 'Prénom',
                                          icon: Icons.person_outline,
                                          enabled:
                                              _isEditing &&
                                              (_identityStatus == null ||
                                                  _identityStatus != 'verifie'),
                                          validator:
                                              (value) =>
                                                  value!.isEmpty
                                                      ? 'Ce champ est requis'
                                                          .tr()
                                                      : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildProfileInput(
                                          controller: _dateNaissanceController,
                                          label: 'Date de naissance',
                                          icon: Icons.calendar_today,
                                          readOnly: true,
                                          enabled:
                                              _isEditing &&
                                              (_identityStatus == null ||
                                                  _identityStatus != 'verifie'),
                                          onTap:
                                              _isEditing &&
                                                      (_identityStatus ==
                                                              null ||
                                                          _identityStatus !=
                                                              'verifie')
                                                  ? _selectDate
                                                  : null,
                                          suffixIcon:
                                              _isEditing &&
                                                      (_identityStatus ==
                                                              null ||
                                                          _identityStatus !=
                                                              'verifie')
                                                  ? IconButton(
                                                    icon: Icon(
                                                      Icons.calendar_month,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                    ),
                                                    onPressed: _selectDate,
                                                  )
                                                  : null,
                                          validator:
                                              (value) =>
                                                  value!.isEmpty
                                                      ? 'Ce champ est requis'
                                                          .tr()
                                                      : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _isEditing &&
                                                (_identityStatus == null ||
                                                    _identityStatus !=
                                                        'verifie')
                                            ? _buildGenreDropdown()
                                            : _buildProfileInput(
                                              controller: TextEditingController(
                                                text: _selectedGenre ?? '',
                                              ),
                                              label: 'Genre',
                                              icon: Icons.people,
                                              enabled: false,
                                            ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SettingsCard(
                                      title: 'Détails personnels'.tr(),
                                      icon: Icons.info,
                                      children: [
                                        // Affichage de l'email avec bouton crayon toujours cliquable
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _emailController
                                                          .text
                                                          .isNotEmpty
                                                      ? _emailController.text
                                                      : '-',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                tooltip: 'Modifier l\'e-mail',
                                                onPressed: _showEmailEditDialog,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Affichage du numéro de téléphone avec bouton crayon toujours cliquable
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _phoneController
                                                          .text
                                                          .isNotEmpty
                                                      ? _phoneController.text
                                                      : '-',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                tooltip: 'Modifier le numéro',
                                                onPressed: _showPhoneEditDialog,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildReviewsSection(),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
      floatingActionButton:
          (_tabController?.index == 0 &&
                  (_identityStatus == null || _identityStatus != 'verifie'))
              ? FloatingActionButton(
                onPressed:
                    _isSaving
                        ? null
                        : (_isEditing ? _saveUserData : _toggleEditMode),
                backgroundColor: Theme.of(context).colorScheme.primary,
                tooltip: _isEditing ? 'Sauvegarder'.tr() : 'Modifier'.tr(),
                child:
                    _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(_isEditing ? Icons.save : Icons.edit),
              )
              : null,
    );
  }
}
