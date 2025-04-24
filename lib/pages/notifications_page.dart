import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  bool _isMarkingAllAsRead = false;

  @override
  void initState() {
    super.initState();
  }

  // Format de date pour afficher quand la notification a été reçue
  String _formatNotificationDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Aujourd'hui, on affiche l'heure
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      // Hier
      return 'Hier à ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      // Cette semaine
      return '${DateFormat('EEEE', 'fr').format(date)} à ${DateFormat('HH:mm').format(date)}';
    } else {
      // Plus ancien
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(date);
    }
  }

  // Marquer toutes les notifications comme lues
  Future<void> _markAllAsRead() async {
    if (_isMarkingAllAsRead) return;

    setState(() {
      _isMarkingAllAsRead = true;
    });

    try {
      await _notificationService.markAllAsRead();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les notifications ont été marquées comme lues'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isMarkingAllAsRead = false;
      });
    }
  }

  // Supprimer une notification
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification supprimée'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Marquer une notification comme lue
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Récupérer l'icône appropriée selon le type de notification
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'reservation':
        return Icons.bookmark_added;
      case 'cancellation':
        return Icons.cancel;
      case 'message':
        return Icons.message;
      case 'payment':
        return Icons.payment;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  // Récupérer la couleur appropriée selon le type de notification
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'reservation':
        return Colors.green;
      case 'cancellation':
        return Colors.red;
      case 'message':
        return Colors.blue;
      case 'payment':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tout marquer comme lu',
            onPressed: _isMarkingAllAsRead ? null : _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allNotifications = snapshot.data ?? [];

          // Filtrer les notifications pour ne garder que les réservations et annulations
          final notifications =
              allNotifications.where((notification) {
                return notification.type == 'reservation' ||
                    notification.type == 'cancellation';
              }).toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune notification de réservation ou d\'annulation', // Message mis à jour
                    textAlign: TextAlign.center, // Centrer le texte si besoin
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les notifications de réservation apparaîtront ici', // Message mis à jour
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length, // Utiliser la liste filtrée
            itemBuilder: (context, index) {
              final notification =
                  notifications[index]; // Utiliser la liste filtrée
              final bool isUnread = !notification.isRead;

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(notification.id),
                child: InkWell(
                  onTap: () {
                    if (isUnread) {
                      _markAsRead(notification.id);
                    }

                    // Logique pour naviguer ou afficher plus de détails selon le type
                    // Note: La logique pour 'message' n'est plus nécessaire ici car filtrée avant
                    if (notification.type == 'reservation') {
                      // Si c'est une notification de réservation, on pourrait naviguer vers les détails de la réservation
                      if (notification.data != null &&
                          notification.data!['tripId'] != null) {
                        // Naviguer vers les détails du trajet
                        /*
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripDetailPage(
                              tripId: notification.data!['tripId'],
                            ),
                          ),
                        );
                        */
                      }
                    }
                    // La condition else if (notification.type == 'message') a été retirée car ces notifications sont filtrées
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isUnread
                              ? theme.colorScheme.primary.withOpacity(0.05)
                              : null,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicateur non lu
                        if (isUnread)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 8),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),

                        // Icône de la notification
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getNotificationColor(
                              notification.type,
                            ).withOpacity(0.1),
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: _getNotificationColor(notification.type),
                            size: 24,
                          ),
                        ),

                        // Contenu de la notification
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight:
                                      isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.message,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatNotificationDate(notification.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
