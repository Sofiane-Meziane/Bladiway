import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bladiway/methods/user_data_notifier.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_screen.dart';
import 'mes_voitures_page.dart';
import 'notifications_page.dart';
import '../services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int totalTrips = 15;
  int proposedTrips = 5;
  int kilometersTraveled = 320;
  bool _hasCar = false;
  bool _isUserBlocked =
      false; // Variable pour suivre si l'utilisateur est bloqué
  String _userProfileImageUrl = ''; // Pour stocker l'URL de la photo de profil
  String _userName = ''; // Pour stocker le nom de l'utilisateur
  String _userEmail = ''; // Pour stocker l'email de l'utilisateur

  // Animation controller pour l'écran de blocage
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<DocumentSnapshot> _userStream;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();

    // Initialiser les animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    User? user = _auth.currentUser;
    if (user != null) {
      _userStream = _firestore.collection('users').doc(user.uid).snapshots();
      _setupUserListener();
      _checkUserBlockStatus(); // Vérifier si l'utilisateur est bloqué
    }
    _checkUserHasCar();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Méthode pour vérifier si l'utilisateur est bloqué
  Future<void> _checkUserBlockStatus() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            bool isBlocked = userData['blockStatus'] == "blocked";

            setState(() {
              _isUserBlocked = isBlocked;
              _userProfileImageUrl = userData['profileImageUrl'] ?? '';
              _userName =
                  '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}';
              _userEmail = userData['email'] ?? '';
            });

            // Démarrer l'animation une seule fois si l'utilisateur est bloqué
            if (isBlocked) {
              _animationController.forward();
              // Ne pas répéter l'animation
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut de blocage : $e');
    }
  }

  void _setupUserListener() {
    _userStream.listen(
      (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            final name = data['prenom'] ?? 'Utilisateur'.tr();
            final photoUrl = data['profileImageUrl'] ?? '';
            userDataNotifier.updateUserData(name, photoUrl);
            _checkUserHasCar();

            // Vérifier le statut de blocage à chaque mise à jour des données utilisateur
            bool isBlocked = data['blockStatus'] == "blocked";

            if (isBlocked != _isUserBlocked) {
              setState(() {
                _isUserBlocked = isBlocked;
                _userProfileImageUrl = data['profileImageUrl'] ?? '';
                _userName = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}';
                _userEmail = data['email'] ?? '';
              });

              // Démarrer l'animation une seule fois si l'utilisateur vient d'être bloqué
              if (isBlocked) {
                _animationController.forward();
                // Ne pas répéter l'animation
              }
            }
          }
        }
      },
      onError: (e) {
        print('Erreur lors de l\'écoute des données utilisateur : $e');
      },
    );
  }

  // Méthode pour copier l'email dans le presse-papier
  void _copyEmailToClipboard() {
    Clipboard.setData(const ClipboardData(text: 'bladiwayapp@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email copié dans le presse-papier'.tr()),
        backgroundColor: Theme.of(context).colorScheme.onSecondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Méthode pour ouvrir l'email avec un message prérempli
  void _launchEmail() async {
    final emailAddress = 'bladiwayapp@gmail.com';
    final subject = 'Compte bloqué - Demande d\'information';
    final body =
        'Bonjour,\n\nMon compte a été bloqué et je souhaiterais obtenir plus d\'informations.\n\nNom d\'utilisateur: $_userName\nEmail: $_userEmail\n\nCordialement,\n$_userName';

    try {
      // Méthode 1: Utiliser Intent.SENDTO (méthode recommandée pour Android)
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: emailAddress,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      print("Tentative d'ouverture de l'email avec URI: $emailLaunchUri");

      if (await canLaunchUrl(emailLaunchUri)) {
        final bool launched = await launchUrl(
          emailLaunchUri,
          mode: LaunchMode.externalApplication,
        );

        print("Email lancé: $launched");

        if (!launched) {
          // Méthode alternative si la première échoue
          final fallbackUri = Uri.parse(
            'mailto:$emailAddress?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
          );
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      } else {
        print("Impossible d'ouvrir l'application email");
        // Afficher un message à l'utilisateur avec des instructions alternatives
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Impossible d\'ouvrir l\'application email'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Veuillez essayer l\'une des options suivantes:'.tr()),
                  const SizedBox(height: 16),
                  Text(
                    '1. Vérifiez que vous avez une application email installée'
                        .tr(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '2. Copiez l\'adresse email et envoyez un message manuellement'
                        .tr(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Email: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('bladiwayapp@gmail.com'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _copyEmailToClipboard,
                  child: Text('Copier l\'email'.tr()),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Fermer'.tr()),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Erreur lors de l\'ouverture de l\'email: $e');
      // Afficher un message d'erreur plus détaillé
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _checkUserHasCar() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot carsSnapshot =
            await _firestore
                .collection('cars')
                .where('id_proprietaire', isEqualTo: user.uid)
                .limit(1)
                .get();

        setState(() {
          _hasCar = carsSnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification des voitures : $e');
    }
  }

  void _onItemTapped(int index) {
    // Si l'utilisateur est bloqué, ne pas permettre la navigation
    if (_isUserBlocked) {
      return;
    }

    final homeIndex = 0;
    final reservationIndex = 1;
    final tripsIndex = 2;
    final settingsIndex = 3;

    if (index == homeIndex) {
      setState(() {
        _selectedIndex = homeIndex;
      });
      return;
    }

    if (index == reservationIndex) {
      Navigator.pushNamed(context, '/reservations');
      return;
    }

    if (index == tripsIndex) {
      Navigator.pushNamed(context, '/trips');
      return;
    }

    if (index == settingsIndex) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ParametresPage()),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToMesVoitures() {
    // Si l'utilisateur est bloqué, ne pas permettre la navigation
    if (_isUserBlocked) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MesVoituresPage()),
    ).then((_) {
      _checkUserHasCar();
    });
  }

  void _navigateToNotifications() {
    // Si l'utilisateur est bloqué, ne pas permettre la navigation
    if (_isUserBlocked) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  Future<void> _checkAddTripPermission() async {
    // Si l'utilisateur est bloqué, ne pas permettre l'action
    if (_isUserBlocked) {
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté pour continuer'.tr())),
      );
      return;
    }

    try {
      // Récupérer le permis depuis la table piece_identite
      QuerySnapshot permisSnapshot =
          await _firestore
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .where('type_piece', isEqualTo: 'permis')
              .limit(1)
              .get();

      print('Permis doc trouvé: ${permisSnapshot.docs.isNotEmpty}');
      print(
        'Données du permis: ${permisSnapshot.docs.isNotEmpty ? permisSnapshot.docs.first.data() : "Aucune donnée"}',
      );

      bool hasVerifiedLicense = false;
      bool hasPendingOrNoLicense = true;

      if (permisSnapshot.docs.isNotEmpty) {
        var permisData =
            permisSnapshot.docs.first.data() as Map<String, dynamic>;
        String statut = permisData['statut'];
        String? dateExpirationStr = permisData['date_expiration'];

        DateTime? dateExpiration;
        if (dateExpirationStr != null) {
          try {
            dateExpiration = DateTime.parse(dateExpirationStr);
          } catch (e) {
            print('Erreur de parsing de la date d\'expiration: $e');
          }
        }

        bool isLicenseExpired =
            dateExpiration == null || dateExpiration.isBefore(DateTime.now());

        hasVerifiedLicense = statut == 'verifie' && !isLicenseExpired;
        hasPendingOrNoLicense =
            statut == 'en cours' || statut == 'refuse' || isLicenseExpired;
      }

      // Récupérer les voitures
      QuerySnapshot carsSnapshot =
          await _firestore
              .collection('cars')
              .where('id_proprietaire', isEqualTo: user.uid)
              .limit(1)
              .get();

      bool hasCar = carsSnapshot.docs.isNotEmpty;

      print('Nombre de voitures: ${carsSnapshot.docs.length}');
      print('hasVerifiedLicense: $hasVerifiedLicense');
      print('hasCar: $hasCar');
      print('hasPendingOrNoLicense: $hasPendingOrNoLicense');

      if (_hasCar != hasCar) {
        setState(() {
          _hasCar = hasCar;
        });
      }

      // Redirection
      if (hasVerifiedLicense && hasCar) {
        Navigator.pushNamed(context, '/info_trajet');
      } else {
        Navigator.pushNamed(context, '/verifier_Conducteur');
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la vérification'.tr())),
      );
    }
  }

  Future<void> _checkReservationPermission() async {
    // Si l'utilisateur est bloqué, ne pas permettre l'action
    if (_isUserBlocked) {
      return;
    }

    User? user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté pour continuer'.tr())),
      );
      return;
    }

    try {
      QuerySnapshot piecesSnapshot =
          await _firestore
              .collection('piece_identite')
              .where('id_proprietaire', isEqualTo: user.uid)
              .get();

      final pieces =
          piecesSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

      bool hasVerifiedID = pieces.any((piece) => piece['statut'] == 'verifie');
      bool hasPendingOrRefusedID =
          pieces.isEmpty ||
          pieces.any(
            (piece) =>
                piece['statut'] == 'en cours' || piece['statut'] == 'refuse',
          );

      if (hasVerifiedID) {
        Navigator.pushNamed(context, '/reserver');
      } else if (hasPendingOrRefusedID) {
        Navigator.pushNamed(context, '/verifier_Passager');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous devez soumettre une pièce d\'identité pour réserver un trajet'
                  .tr(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification des conditions : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la vérification'.tr())),
      );
    }
  }

  // Méthode pour construire l'écran de blocage avec design bleu et blanc
  // Méthode pour construire l'écran de blocage avec design bleu et blanc
  Widget _buildBlockedScreen() {
    // List of blocking reasons to display
    final List<String> blockingReasons = [
      'Vous avez reçu des commentaires négatifs de la part des passagers.',
      'Vous avez créé plusieurs trajets fictifs qui ont été annulés systématiquement.',
      'Vous avez publié des commentaires inappropriés ou offensants.',
      'Vous avez enfreint les conditions générales d\'utilisation de Bladiway.',
      'Votre comportement a été signalé comme dangereux ou irrespectueux.',
      'Vous avez fourni des informations personnelles incorrectes ou frauduleuses.',
      'Vous avez tenté de contourner le système de paiement de la plateforme.',
      'Vous n\'avez pas respecté les mesures de sécurité requises pour les trajets.',
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo Bladiway en haut
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "Bladiway",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // User info row (profile pic, name and email)
                              Row(
                                children: [
                                  // Photo de profil de l'utilisateur avec bordure bleue
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child:
                                          _userProfileImageUrl.isNotEmpty
                                              ? Image.network(
                                                _userProfileImageUrl,
                                                fit: BoxFit.cover,
                                              )
                                              : Container(
                                                color: Colors.white,
                                                child: Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Nom d'utilisateur
                                        Text(
                                          _userName,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Email de l'utilisateur
                                        Text(
                                          _userEmail,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Status container with icon and message
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.error,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.block,
                                      size: 40,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Compte bloqué'.tr(),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Votre compte a été bloqué pour non-respect des conditions d\'utilisation.'
                                                .tr(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    childrenPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    title: Text(
                                      'Raisons possibles du blocage'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                    collapsedIconColor:
                                        Theme.of(context).colorScheme.primary,
                                    iconColor:
                                        Theme.of(context).colorScheme.primary,
                                    children:
                                        blockingReasons.skip(1).map((reason) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  size: 6,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    reason,
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                      fontSize: 13,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Message d'explication
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Vous n\'avez plus accès aux fonctionnalités de l\'application. Pour plus d\'informations, veuillez contacter notre équipe de support.'
                                      .tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Contact support button
                              GestureDetector(
                                onTap: _launchEmail,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.email_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Contacter le support',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email with copy button in a single row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'bladiwayapp@gmail.com',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _copyEmailToClipboard,
                                    child: Icon(
                                      Icons.copy,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Logout button
                              ElevatedButton.icon(
                                onPressed: () {
                                  _auth.signOut();
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/login',
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(Icons.logout, size: 18),
                                label: Text('Se déconnecter'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si l'utilisateur est bloqué, afficher l'écran de blocage
    if (_isUserBlocked) {
      return _buildBlockedScreen();
    }

    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              ClipPath(
                clipper: HeaderClipper(),
                child: Container(
                  height: 270,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                left: 16,
                right: 16,
                child: ValueListenableBuilder<Map<String, String>>(
                  valueListenable: userDataNotifier,
                  builder: (context, userData, child) {
                    final name = userData['name'];
                    final photoUrl = userData['photoUrl'];

                    if (name == null || photoUrl == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/profile');
                                  },
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                    child:
                                        photoUrl.isEmpty
                                            ? const Icon(
                                              Icons.person,
                                              color: Colors.blue,
                                              size: 24,
                                            )
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Bienvenue à notre plateforme'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            StreamBuilder<int>(
                              stream:
                                  _notificationService
                                      .getUnreadNotificationsCount(),
                              builder: (context, snapshot) {
                                int unreadCount = snapshot.data ?? 0;

                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.notifications_none,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        size: 28,
                                      ),
                                      onPressed: _navigateToNotifications,
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Bladiway',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('Bonjour, {}', args: [name]),
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                buildCard(
                  title: 'Trouvez votre trajet idéal 🚗'.tr(),
                  subtitle:
                      'Découvrez facilement les meilleurs trajets adaptés à vos besoins.'
                          .tr(),
                  buttonText: 'Réserver'.tr(),
                  color1: Theme.of(context).colorScheme.primary,
                  color2: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.7),
                  onPressed: _checkReservationPermission,
                ),
                const SizedBox(height: 16),
                buildCard(
                  title: 'Proposez votre trajet 🛣️'.tr(),
                  subtitle:
                      'Partagez votre route et faites des économies.'.tr(),
                  buttonText: 'Ajouter un trajet'.tr(),
                  color1: Theme.of(context).colorScheme.onSecondary,
                  color2: Theme.of(
                    context,
                  ).colorScheme.onSecondary.withOpacity(0.7),
                  onPressed: _checkAddTripPermission,
                ),

                // Ajouter la carte "Mes voitures" uniquement si l'utilisateur a au moins une voiture
                if (_hasCar) ...[
                  const SizedBox(height: 16),
                  buildCard(
                    title: 'Gérez vos voitures 🚘'.tr(),
                    subtitle:
                        'Consultez et modifiez les informations de vos véhicules.'
                            .tr(),
                    buttonText: 'Voir mes voitures'.tr(),
                    // Nouveau dégradé bleu-vert au lieu du rouge
                    color1: Theme.of(context).colorScheme.onSecondary,
                    color2: Theme.of(context).colorScheme.primary,
                    onPressed: _navigateToMesVoitures,
                    buttonTextColor:
                        Theme.of(
                          context,
                        ).colorScheme.error, // Texte en rouge du thème
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.5),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'Accueil'.tr(),
          ),
          _buildReservationsIconWithBadge(context),
          _buildMessageIconWithBadge(context),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres'.tr(),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildReservationsIconWithBadge(
    BuildContext context,
  ) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
            const Icon(Icons.check_circle_outline),
          StreamBuilder<int>(
            stream: _notificationService.getPassengerUnreadMessagesCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    snapshot.data! > 99 ? '99+' : '${snapshot.data}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      label: 'Réservations'.tr(),
    );
  }

  BottomNavigationBarItem _buildMessageIconWithBadge(BuildContext context) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          const Icon(Icons.directions_car_outlined),
          StreamBuilder<int>(
            stream: _notificationService.getUnreadMessagesCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    snapshot.data! > 99 ? '99+' : '${snapshot.data}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      label: 'Mes trajets'.tr(),
    );
  }

  Widget buildCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required Color color1,
    required Color color2,
    required VoidCallback onPressed,
    Color? buttonTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: buttonTextColor ?? color1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
