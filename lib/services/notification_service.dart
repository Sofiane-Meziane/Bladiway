import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection de notifications dans Firestore
  static CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  // Récupérer les notifications de l'utilisateur actuel
  Stream<List<NotificationModel>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      // Si utilisateur non connecté, renvoyer une liste vide
      return Stream.value([]);
    }

    // Version temporaire sans orderBy pour éviter l'erreur d'index
    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        // Note: orderBy retiré pour éviter l'erreur d'index
        .snapshots()
        .map((snapshot) {
          final notifications =
              snapshot.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList();

          // Tri côté client par date de création (plus récent en premier)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return notifications;
        });
  }

  // Récupérer le nombre de notifications non lues
  Stream<int> getUnreadNotificationsCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        // Filtrer pour ne compter que les types affichés dans la page de notifications
        .where('type', whereIn: ['reservation', 'cancellation'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Récupérer le nombre de messages non lus pour les conducteurs
  Stream<int> getUnreadMessagesCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'message')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Récupérer le nombre de messages non lus pour une réservation spécifique
  Stream<int> getUnreadMessagesCountForReservation(String reservationId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'driver_message')
        .where('data.reservationId', isEqualTo: reservationId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Récupérer le nombre de messages non lus pour les passagers (messages du conducteur)
  Stream<int> getPassengerUnreadMessagesCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'driver_message')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Récupérer le nombre de messages non lus envoyés par un passager spécifique
  Stream<int> getUnreadMessagesCountFromPassenger(
    String passengerId,
    String tripId,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'message')
        .where('data.senderId', isEqualTo: passengerId)
        .where(
          'data.tripId',
          isEqualTo: tripId,
        ) // Filtre ajouté pour le trajet spécifique
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Récupérer le nombre de messages non lus envoyés par un conducteur spécifique
  Stream<int> getUnreadMessagesCountFromDriver(String driverId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'driver_message')
        .where('data.driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Vérifier si un passager spécifique a envoyé des messages non lus
  Stream<bool> hasUnreadMessagesFromPassenger(String passengerId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'message')
        .where('data.senderId', isEqualTo: passengerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Vérifier si un conducteur a envoyé des messages non lus au passager
  Stream<bool> hasUnreadMessagesFromDriver(String driverId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'driver_message')
        .where('data.driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Méthode statique pour envoyer une notification de base - facilite l'envoi depuis n'importe où
  static Future<void> sendNotification(
    String userId,
    String title,
    String message, {
    String type = 'default',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationsCollection.add(
        NotificationModel(
          id: '',
          userId: userId,
          title: title,
          message: message,
          type: type,
          createdAt: DateTime.now(),
          isRead: false,
          data: data,
        ).toMap(),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  // Créer une nouvelle notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationsCollection.add(
        NotificationModel(
          id: '', // Firestore va générer un ID
          userId: userId,
          title: title,
          message: message,
          type: type,
          createdAt: DateTime.now(),
          isRead: false,
          data: data,
        ).toMap(),
      );
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      rethrow;
    }
  }

  // Marquer une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Erreur lors du marquage de la notification comme lue: $e');
      rethrow;
    }
  }

  // Marquer toutes les notifications de l'utilisateur comme lues
  Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final unreadNotifications =
          await _notificationsCollection
              .where('userId', isEqualTo: user.uid)
              .where('isRead', isEqualTo: false)
              .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print(
        'Erreur lors du marquage de toutes les notifications comme lues: $e',
      );
      rethrow;
    }
  }

  // Marquer tous les messages d'un expéditeur spécifique comme lus
  Future<void> markAllMessagesFromSenderAsRead(String senderId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final unreadMessages =
          await _notificationsCollection
              .where('userId', isEqualTo: user.uid)
              .where('isRead', isEqualTo: false)
              .where('type', isEqualTo: 'message')
              .where('data.senderId', isEqualTo: senderId)
              .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Erreur lors du marquage des messages comme lus: $e');
      rethrow;
    }
  }

  // Marquer tous les messages d'un conducteur spécifique comme lus
  Future<void> markAllMessagesFromDriverAsRead(String driverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final unreadMessages =
          await _notificationsCollection
              .where('userId', isEqualTo: user.uid)
              .where('isRead', isEqualTo: false)
              .where('type', isEqualTo: 'driver_message')
              .where('data.driverId', isEqualTo: driverId)
              .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Erreur lors du marquage des messages du conducteur comme lus: $e');
      rethrow;
    }
  }

  // Supprimer une notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      print('Erreur lors de la suppression de la notification: $e');
      rethrow;
    }
  }

  // Créer une notification de réservation
  static Future<void> createReservationNotification({
    required String driverId,
    required String passengerId,
    required String passengerName,
    required String tripId,
    required String tripDestination,
    required String tripDate,
    required int seatsReserved,
  }) async {
    final title = 'Nouvelle réservation';
    final message =
        '$passengerName a réservé $seatsReserved ${seatsReserved > 1 ? 'places' : 'place'} pour votre trajet vers $tripDestination le $tripDate';

    await sendNotification(
      driverId,
      title,
      message,
      type: 'reservation',
      data: {
        'tripId': tripId,
        'passengerId': passengerId,
        'seatsReserved': seatsReserved,
      },
    );
  }

  // Créer une notification d'annulation de réservation
  static Future<void> createCancellationNotification({
    required String driverId,
    required String passengerId,
    required String passengerName,
    required String tripId,
    required String tripDestination,
    required String tripDate,
    required int seatsReserved,
  }) async {
    final title = 'Réservation annulée';
    final message =
        '$passengerName a annulé sa réservation de $seatsReserved ${seatsReserved > 1 ? 'places' : 'place'} pour votre trajet vers $tripDestination le $tripDate';

    await sendNotification(
      driverId,
      title,
      message,
      type: 'cancellation',
      data: {
        'tripId': tripId,
        'passengerId': passengerId,
        'seatsReserved': seatsReserved,
      },
    );
  }

  // Créer une notification de modification de places
  static Future<void> createSeatsModificationNotification({
    required String driverId,
    required String passengerId,
    required String passengerName,
    required String tripId,
    required String tripDestination,
    required String tripDate,
    required int oldSeatsCount,
    required int newSeatsCount,
  }) async {
    final title = 'Modification de réservation';
    final String action = oldSeatsCount < newSeatsCount ? 'augmenté' : 'réduit';
    final message =
        '$passengerName a $action sa réservation de $oldSeatsCount à $newSeatsCount ${newSeatsCount > 1 ? 'places' : 'place'} pour votre trajet vers $tripDestination le $tripDate';

    await sendNotification(
      driverId,
      title,
      message,
      type: 'reservation',
      data: {
        'tripId': tripId,
        'passengerId': passengerId,
        'seatsReserved': newSeatsCount,
      },
    );
  }

  // Créer une notification de message de chat
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String title,
    required String body,
    required String tripId, // Ajout de tripId comme paramètre requis
    String type = 'message',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationsCollection.add(
        NotificationModel(
          id: '',
          userId: receiverId,
          title: title,
          message: body,
          type: type,
          createdAt: DateTime.now(),
          isRead: false,
          data: {
            ...?data, // Inclut les données existantes, si présentes
            'tripId': tripId, // Ajout de tripId dans les données
            'senderId': _auth.currentUser?.uid ?? '', // Inclure l’expéditeur
          },
        ).toMap(),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  // Créer une notification de message du conducteur au passager
  static Future<void> sendDriverMessageNotification({
    required String passengerId,
    required String driverId,
    required String driverName,
    required String body,
    required String reservationId, required String tripId,
  }) async {
    try {
      await _notificationsCollection.add(
        NotificationModel(
          id: '',
          userId: passengerId,
          title: "Message de $driverName",
          message: body,
          type: 'driver_message',
          createdAt: DateTime.now(),
          isRead: false,
          data: {
            'driverId': driverId,
            'reservationId': reservationId,
            'senderId': driverId,
          },
        ).toMap(),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi du message du conducteur: $e');
    }
  }
}
