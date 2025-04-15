import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

class MesVoituresPage extends StatefulWidget {
  const MesVoituresPage({super.key});

  @override
  State<MesVoituresPage> createState() => _MesVoituresPageState();
}

class _MesVoituresPageState extends State<MesVoituresPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> voitures = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _chargerVoitures();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _chargerVoitures() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot carsSnapshot =
            await _firestore
                .collection('cars')
                .where('id_proprietaire', isEqualTo: user.uid)
                .get();

        setState(() {
          voitures = carsSnapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des voitures : $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _ajouterVoiture() {
    Navigator.pushNamed(context, '/add_car').then((_) => _chargerVoitures());
  }

  void _modifierVoiture(DocumentSnapshot voiture) {
    Navigator.pushNamed(
      context,
      '/edit_car',
      arguments: voiture,
    ).then((_) => _chargerVoitures());
  }

  void _supprimerVoiture(String voitureId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Confirmer la suppression'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Êtes-vous sûr de vouloir supprimer cette voiture ?'.tr(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuler'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    await _firestore.collection('cars').doc(voitureId).delete();
                    _chargerVoitures();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Supprimer'.tr()),
                ),
              ],
            ),
          ),
    );
  }

  // Création d'un widget 3D pour représenter une voiture sans glassmorphism
  Widget _buildCar3DCard(
    Map<String, dynamic> carData,
    DocumentSnapshot voiture,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final make = carData['make'] ?? '';
    final model = carData['model'] ?? '';
    final year = carData['year'] ?? '';
    final color = carData['color'] ?? '';
    final plate = carData['plate'] ?? '';
    final imageUrl = carData['imageUrl'] ?? '';

    return Hero(
      tag: 'car-${voiture.id}',
      child: GestureDetector(
        onTap: () => _afficherDetailVoiture(voiture),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Stack(
            children: [
              // Shadow effect (3D depth)
              Container(
                margin: const EdgeInsets.only(top: 8, right: 8),
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              // Main card without glassmorphism
              Container(
                    width: double.infinity,
                    height: 190,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Car image with tilt effect
                              Transform(
                                transform:
                                    Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(0.05),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: const Offset(5, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            color: colorScheme.primary
                                                .withOpacity(0.2),
                                            child: Icon(
                                              Icons.directions_car,
                                              size: 50,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$make $model',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Badge with plate number
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colorScheme.primary
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        plate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _buildInfoChip(
                                          Icons.calendar_today,
                                          year.toString(),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildInfoChip(Icons.color_lens, color),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () => _modifierVoiture(voiture),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: colorScheme.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primary
                                      .withOpacity(0.1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _supprimerVoiture(voiture.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _afficherDetailVoiture(DocumentSnapshot voiture) {
    // Navigation vers la page de détail qui serait à créer
    Navigator.pushNamed(context, '/car_detail', arguments: voiture);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerHeight = 280.0 - (_scrollOffset * 0.5).clamp(0.0, 100.0);

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.8),
                  colorScheme.surface,
                ],
                stops: const [0.0, 0.3, 0.5],
              ),
            ),
          ),

          // Car illustration in background (optional)
          Positioned(
            top: 60,
            right: -50,
            child: Opacity(
              opacity: 0.15,
              child: Transform(
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-0.3)
                      ..rotateZ(0.1),
                alignment: Alignment.center,
                child: SvgPicture.network(
                  'https://example.com/car-illustration.svg', // Remplacer par votre URL d'illustration
                  width: 200,
                  height: 200,
                  placeholderBuilder:
                      (context) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.transparent,
                      ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Container(
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Back button without search
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            height:
                                130 - (_scrollOffset * 0.5).clamp(0.0, 100.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                      'Mes Voitures'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 500.ms)
                                    .slideY(begin: 0.2, end: 0),
                                const SizedBox(height: 8),
                                Text(
                                      'Gérez votre collection de véhicules'
                                          .tr(),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms, duration: 500.ms)
                                    .slideY(begin: 0.2, end: 0),
                                if (_scrollOffset < 40)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      '${voitures.length} ${voitures.length <= 1 ? 'véhicule'.tr() : 'véhicules'.tr()}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ).animate().fadeIn(
                                      delay: 400.ms,
                                      duration: 500.ms,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child:
                      _isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          )
                          : voitures.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.network(
                                  'https://example.com/empty-state.svg', // Remplacer par votre URL d'illustration
                                  width: 150,
                                  height: 150,
                                  placeholderBuilder:
                                      (context) => Container(
                                        width: 150,
                                        height: 150,
                                        color: colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.directions_car_outlined,
                                          size: 60,
                                          color: colorScheme.primary
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Aucune voiture enregistrée'.tr(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ajoutez votre première voiture dès maintenant'
                                      .tr(),
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _ajouterVoiture,
                                  icon: const Icon(Icons.add),
                                  label: Text('Ajouter une voiture'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                            itemCount: voitures.length,
                            itemBuilder: (context, index) {
                              final voiture = voitures[index];
                              final data =
                                  voiture.data() as Map<String, dynamic>;
                              return _buildCar3DCard(data, voiture)
                                  .animate(
                                    delay: Duration(milliseconds: 100 * index),
                                  )
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0, duration: 400.ms);
                            },
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterVoiture,
        backgroundColor: colorScheme.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Row(
          children: [
            const Icon(Icons.add),
            const SizedBox(width: 8),
            Text('Ajouter'.tr()),
          ],
        ),
      ).animate().scale(delay: 400.ms, duration: 400.ms),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
