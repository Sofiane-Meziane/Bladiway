import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Méthodes communes (pour les SnackBars, etc.)
import '../methods/commun_methods.dart';
// Widgets réutilisables (SettingsHeader, SettingsCard, etc.)
import '../widgets/settings_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de saisie
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();

  String? _selectedGenre;
  final List<String> _genres = ['Homme', 'Femme', 'Autre'];

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _uid;

  // Animation pour le champ "Genre" lors de l'édition
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    super.dispose();
  }

  /// Chargement des données depuis Firestore
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        _uid = currentUser.uid;
        final doc = await _firestore.collection('users').doc(_uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _nomController.text = data['nom'] ?? '';
            _prenomController.text = data['prenom'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone']?.replaceAll('+', '') ?? '';
            _dateNaissanceController.text = data['dateNaissance'] ?? '';
            _selectedGenre = data['genre'];
          });
        }
      }
    } catch (e) {
      CommunMethods().displaySnackBar(
        'Erreur lors du chargement des données: $e',
        context,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Bascule entre mode lecture / édition
  void _toggleEditMode() {
    setState(() => _isEditing = !_isEditing);
    if (_isEditing) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  /// Sauvegarde les modifications sur Firestore et FirebaseAuth (email)
  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updatedData = {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'dateNaissance': _dateNaissanceController.text.trim(),
        'genre': _selectedGenre,
        'updatedAt': DateTime.now(),
      };
      await _firestore.collection('users').doc(_uid).update(updatedData);

      // Mise à jour de l'email si l'utilisateur l'a modifié
      final User? currentUser = _auth.currentUser;
      if (currentUser != null &&
          currentUser.email != _emailController.text.trim()) {
        await currentUser.updateEmail(_emailController.text.trim());
        await _firestore.collection('users').doc(_uid).update({
          'email': _emailController.text.trim(),
        });
      }

      CommunMethods().displaySnackBar('Profil mis à jour avec succès', context);
      _toggleEditMode();
    } catch (e) {
      CommunMethods().displaySnackBar(
        'Erreur lors de la mise à jour: $e',
        context,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Sélecteur de date pour la date de naissance
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

  /// Champ de texte personnalisé
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

    // Couleur de fond des TextFields en fonction du mode clair / sombre
    final fillColor =
        brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200];

    // Couleur de la bordure en fonction du mode
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
        labelText: label,
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

  /// Dropdown pour le genre, avec animation
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
          decoration: const InputDecoration(
            labelText: 'Genre',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            prefixIcon: Icon(Icons.people),
          ),
          value: _selectedGenre,
          items:
              _genres
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedGenre = value),
          validator: (value) => value == null ? 'Ce champ est requis' : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // Fond dégradé pour un rendu plus moderne, adapté au mode clair / sombre
      body: SafeArea(
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      // En-tête style "Paramètres"
                      const SettingsHeader(title: 'Mon profil'),
      
                      // Contenu du profil
                      Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: Column(
                            children: [
                              // Informations personnelles
                              SettingsCard(
                                title: 'Informations personnelles',
                                icon: Icons.person,
                                children: [
                                  _buildProfileInput(
                                    controller: _nomController,
                                    label: 'Nom',
                                    icon: Icons.person,
                                    enabled: _isEditing,
                                    validator:
                                        (value) =>
                                            value!.isEmpty
                                                ? 'Ce champ est requis'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildProfileInput(
                                    controller: _prenomController,
                                    label: 'Prénom',
                                    icon: Icons.person_outline,
                                    enabled: _isEditing,
                                    validator:
                                        (value) =>
                                            value!.isEmpty
                                                ? 'Ce champ est requis'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildProfileInput(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: _isEditing,
                                    validator: (value) {
                                      if (value!.isEmpty) {
                                        return 'Ce champ est requis';
                                      }
                                      final emailRegex = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      );
                                      return emailRegex.hasMatch(value)
                                          ? null
                                          : 'Email invalide';
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildProfileInput(
                                    controller: _phoneController,
                                    label: 'Téléphone',
                                    icon: Icons.phone,
                                    enabled: false,
                                    suffixIcon: Tooltip(
                                      message:
                                          'Le numéro de téléphone ne peut pas être modifié',
                                      child: const Icon(
                                        Icons.info_outline,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
      
                              // Détails personnels
                              SettingsCard(
                                title: 'Détails personnels',
                                icon: Icons.info,
                                children: [
                                  _buildProfileInput(
                                    controller: _dateNaissanceController,
                                    label: 'Date de naissance',
                                    icon: Icons.calendar_today,
                                    readOnly: true,
                                    enabled: _isEditing,
                                    onTap: _isEditing ? _selectDate : null,
                                    suffixIcon:
                                        _isEditing
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
                                                : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _isEditing
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
      // Bouton flottant (édition / sauvegarde)
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isSaving ? null : (_isEditing ? _saveUserData : _toggleEditMode),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child:
            _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(_isEditing ? Icons.save : Icons.edit),
      ),
    );
  }
}
