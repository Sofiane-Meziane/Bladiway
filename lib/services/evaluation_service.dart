import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/evaluation_page.dart';

class EvaluationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Variable statique pour suivre si une page d'évaluation est déjà ouverte
  static bool _isEvaluationPageOpen = false;

  // Vérifier si l'utilisateur a des évaluations en attente (basé uniquement sur 'reviews')
  Future<void> checkPendingEvaluations(BuildContext context) async {
    if (_isEvaluationPageOpen) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final String passengerId = user.uid;

      // Récupérer les trajets terminés où l'utilisateur était passager
      final reservationsSnapshot =
          await _firestore
              .collection('reservations')
              .where('userId', isEqualTo: passengerId)
              .get();

      for (var reservationDoc in reservationsSnapshot.docs) {
        final reservationData = reservationDoc.data();
        final String tripId = reservationData['tripId'] ?? '';
        if (tripId.isEmpty) continue;

        // Vérifier que le trajet est terminé
        final tripDoc = await _firestore.collection('trips').doc(tripId).get();
        if (!tripDoc.exists) continue;
        final tripData = tripDoc.data() as Map<String, dynamic>;
        if (tripData['status'] != 'terminé') continue;

        // Récupérer le conducteur
        final String driverId = tripData['userId'] ?? '';
        if (driverId.isEmpty) continue;
        if (driverId == passengerId) continue; // Ne pas s'auto-évaluer

        // Vérifier si un avis existe déjà
        final reviewQuery =
            await _firestore
                .collection('reviews')
                .where('reviewerId', isEqualTo: passengerId)
                .where('ratedUserId', isEqualTo: driverId)
                .where('tripId', isEqualTo: tripId)
                .get();
        if (reviewQuery.docs.isNotEmpty) continue;

        // Vérifier si le contexte est toujours valide avant d'afficher
        if (!context.mounted) return;

        _isEvaluationPageOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EvaluationPage(
                    userId: driverId,
                    currentUserId: passengerId,
                    tripId: tripId, // Ajouté
                    onReviewSubmitted: () {},
                  ),
            ),
          ).then((_) {
            _isEvaluationPageOpen = false;
          });
        });
        break; // On ne traite qu'une évaluation à la fois
      }
    } catch (e) {
      _isEvaluationPageOpen = false;
      print('Erreur lors de la vérification des évaluations en attente: $e');
    }
  }
}
