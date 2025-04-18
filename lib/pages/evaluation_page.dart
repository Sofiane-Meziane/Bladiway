import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

Future<Map<String, dynamic>?> getUserInfo(String userId) async {
  DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

  if (userDoc.exists) {
    return userDoc.data() as Map<String, dynamic>;
  }
  return null;
}

class EvaluationPage extends StatefulWidget {
  final String userId; // ID de l'utilisateur à évaluer
  final String currentUserId; // ID de l'utilisateur qui évalue
  final VoidCallback
  onReviewSubmitted; // Callback pour notifier le rafraîchissement
  final String? evaluationId; // ID de l'évaluation en attente (optionnel)

  const EvaluationPage({
    super.key,
    required this.userId,
    required this.currentUserId,
    required this.onReviewSubmitted,
    this.evaluationId,
  });

  @override
  _EvaluationPageState createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? userData;
  bool isLoading = true; // Indicateur de chargement
  bool hasAlreadyReviewed =
      false; // Pour vérifier si l'utilisateur a déjà donné un avis

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingReview();
  }

  // Nouvelle méthode pour vérifier si un avis existe déjà
  Future<void> _checkExistingReview() async {
    try {
      // Vérifie si l'utilisateur actuel a déjà laissé un avis pour ce conducteur
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('reviewerId', isEqualTo: widget.currentUserId)
              .where('ratedUserId', isEqualTo: widget.userId)
              .get();

      if (mounted) {
        setState(() {
          hasAlreadyReviewed = querySnapshot.docs.isNotEmpty;
          if (hasAlreadyReviewed && mounted) {
            // Si un avis existe déjà, afficher un message et fermer la page après un court délai
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Vous avez déjà évalué cet utilisateur."),
                duration: Duration(seconds: 2),
              ),
            );

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la vérification des avis existants: $e");
    }
  }

  Future<void> _loadUserData() async {
    var data = await getUserInfo(widget.userId);
    if (mounted) {
      setState(() {
        userData = data;
        isLoading = false;
      });
    }
  }

  Future<void> submitReview() async {
    // Vérifier à nouveau avant de soumettre
    if (hasAlreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous avez déjà évalué cet utilisateur.")),
      );
      Navigator.of(context).pop();
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner une note")),
      );
      return;
    }

    // Désactiver les boutons pendant le traitement
    setState(() {
      isLoading = true;
    });

    try {
      // D'abord, marquer l'évaluation comme complétée pour éviter qu'elle ne soit affichée à nouveau
      if (widget.evaluationId != null) {
        await FirebaseFirestore.instance
            .collection('evaluations_pending')
            .doc(widget.evaluationId)
            .update({'isCompleted': true});
      }

      // Ensuite, sauvegarder l'avis
      await FirebaseFirestore.instance.collection('reviews').add({
        'ratedUserId': widget.userId,
        'reviewerId': widget.currentUserId,
        'rating': _rating,
        'comment': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      widget.onReviewSubmitted(); // Appeler le callback pour rafraîchir

      // Attendre un court instant pour s'assurer que les mises à jour sont bien prises en compte
      await Future.delayed(const Duration(milliseconds: 300));

      // Vérifier si le widget est toujours monté avant d'afficher le message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Évaluation soumise avec succès !")),
        );

        // Fermer la page
        Navigator.of(context).pop();
      }
    } catch (e) {
      // En cas d'erreur, réactiver les boutons
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
      }
    }
  }

  Future<void> skipReview() async {
    // Désactiver les boutons pendant le traitement
    setState(() {
      isLoading = true;
    });

    try {
      // Si c'est une évaluation en attente, la marquer comme complétée même si l'utilisateur passe
      if (widget.evaluationId != null) {
        await FirebaseFirestore.instance
            .collection('evaluations_pending')
            .doc(widget.evaluationId)
            .update({'isCompleted': true, 'skipped': true});
      }

      // Attendre un court instant pour s'assurer que les mises à jour sont bien prises en compte
      await Future.delayed(const Duration(milliseconds: 300));

      // Fermer la page
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // En cas d'erreur, réactiver les boutons
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si l'utilisateur a déjà donné un avis, afficher un indicateur de chargement pendant la fermeture
    if (hasAlreadyReviewed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Évaluation"),
          backgroundColor: const Color(0xFF2196F3),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Vous avez déjà évalué cet utilisateur."),
              Text("Fermeture en cours..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true, // Évite les problèmes avec le clavier
      appBar: AppBar(
        title: Text("Évaluer l'utilisateur"),
        backgroundColor: Color(0xFF2196F3), // Couleur de l'AppBar en bleu
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child:
            isLoading && userData == null
                ? Center(
                  child: CircularProgressIndicator(),
                ) // Indicateur de chargement initial
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            userData?['profileImageUrl'] != null
                                ? NetworkImage(userData!['profileImageUrl'])
                                : AssetImage('assets/default_avatar.png')
                                    as ImageProvider, // Image par défaut
                      ),
                      SizedBox(height: 10),
                      Text(
                        "${userData?['prenom'] ?? "Utilisateur"} ${userData?['nom'] ?? ""}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text("Notez cet utilisateur"),
                      RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemBuilder:
                            (context, _) =>
                                Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _rating = rating;
                          });
                        },
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Laissez un commentaire (facultatif)",
                        ),
                        maxLines: 3,
                        enabled: !isLoading, // Désactiver pendant le chargement
                      ),
                      SizedBox(height: 20),
                      isLoading && userData != null
                          ? Center(
                            child: CircularProgressIndicator(),
                          ) // Indicateur pendant la soumission
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: isLoading ? null : submitReview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(
                                    0xFF2196F3,
                                  ), // Couleur du bouton en bleu
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  "Soumettre",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: isLoading ? null : skipReview,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey),
                                  ),
                                ),
                                child: Text(
                                  "Ignorer",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
      ),
    );
  }
}
