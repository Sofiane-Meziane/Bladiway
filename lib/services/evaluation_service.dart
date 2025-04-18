import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/evaluation_page.dart';

class EvaluationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Variable statique pour suivre si une page d'évaluation est déjà ouverte
  static bool _isEvaluationPageOpen = false;

  // Vérifier si l'utilisateur a des évaluations en attente
  Future<void> checkPendingEvaluations(BuildContext context) async {
    // Si une page d'évaluation est déjà ouverte, ne pas en afficher une autre
    if (_isEvaluationPageOpen) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final String passengerId = user.uid;

      // Rechercher les évaluations en attente pour cet utilisateur qui ne sont pas complétées
      final querySnapshot =
          await _firestore
              .collection('evaluations_pending')
              .where('passengerId', isEqualTo: passengerId)
              .where('isCompleted', isEqualTo: false)
              .limit(1) // On ne traite qu'une évaluation à la fois
              .get();

      if (querySnapshot.docs.isEmpty) return;

      // Récupérer la première évaluation en attente
      final evaluationDoc = querySnapshot.docs.first;
      final evaluationData = evaluationDoc.data();
      final String driverId = evaluationData['driverId'] as String? ?? '';

      if (driverId.isEmpty) return;

      // Vérifier si le contexte est toujours valide avant d'afficher
      if (!context.mounted) return;

      // Marquer qu'une page d'évaluation est en cours d'affichage
      _isEvaluationPageOpen = true;

      // Afficher la page d'évaluation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => EvaluationPage(
                  userId: driverId,
                  currentUserId: passengerId,
                  evaluationId: evaluationDoc.id,
                  onReviewSubmitted: () {
                    // Pas besoin d'action supplémentaire ici,
                    // car l'évaluation sera marquée comme complétée dans submitReview
                  },
                ),
          ),
        ).then((_) {
          // Une fois la page fermée, réinitialiser le drapeau
          _isEvaluationPageOpen = false;
        });
      });
    } catch (e) {
      // En cas d'erreur, réinitialiser le drapeau
      _isEvaluationPageOpen = false;
      print('Erreur lors de la vérification des évaluations en attente: $e');
    }
  }
}
