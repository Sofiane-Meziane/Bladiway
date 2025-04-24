import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String? documentType;

const VerificationPendingScreen({
  this.documentType,
  super.key,
});

  @override
  _VerificationPendingScreenState createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = true;

  String _submissionDate = '';
  String _documentNumber = '';
  String _documentType = '';
  String _status = 'en_cours';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadDocumentData();
  }

  Future<void> _loadDocumentData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Query query = FirebaseFirestore.instance
          .collection('piece_identite')
          .where('id_proprietaire', isEqualTo: user.uid);

      // Appliquer le filtre par type de document seulement si précisé
      if (widget.documentType != null) {
        query = query.where('type_piece', isEqualTo: widget.documentType);
      }

      // Trier pour avoir le plus récent
      final docSnapshot = await query
          .orderBy('date_soumission', descending: true)
          .limit(1)
          .get();

      if (docSnapshot.docs.isNotEmpty) {
        final doc = docSnapshot.docs.first;
        setState(() {
          _isLoading = false;

          Timestamp timestamp = doc['date_soumission'] as Timestamp;
          DateTime dateTime = timestamp.toDate();
          _submissionDate = DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
          _documentNumber = doc['num_piece'] as String;
          _documentType = _getDocumentTypeName(doc['type_piece'] as String);
          _status = doc['statut'] as String;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun document trouvé.')),
        );
      }
    }
  } catch (e) {
    print('Erreur lors du chargement des données: $e');
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e')),
    );
  }
}




  String _getDocumentTypeName(String typeCode) {
    switch (typeCode) {
      case 'carte_identité':
        return 'Carte d\'identité';
      case 'permis':
        return 'Permis de conduire';
      case 'passeport':
        return 'Passeport';
      default:
        return typeCode;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _status == 'verifie'
              ? 'Document vérifié'
              : _status == 'refuse'
                  ? 'Document refusé'
                  : 'Vérification en cours',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVerificationPendingContent(colorScheme),
    );
  }

  Widget _buildVerificationPendingContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              child: Lottie.asset(
                'assets/animation/document_verification.json',
                controller: _animationController,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _status == 'verifie'
                  ? 'Document vérifié'
                  : _status == 'refuse'
                      ? 'Document refusé'
                      : 'Vérification en cours',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _status == 'verifie'
                    ? Colors.green
                    : _status == 'refuse'
                        ? Colors.red
                        : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(context, 'Type de document', _documentType, Icons.description_outlined),
                  const SizedBox(height: 10),
                  _infoRow(context, 'Numéro du document', _documentNumber, Icons.credit_card_outlined),
                  const SizedBox(height: 10),
                  _infoRow(context, 'Date de soumission', _submissionDate, Icons.calendar_today_outlined),
                  const SizedBox(height: 10),
                  _infoRow(
                    context,
                    'Statut',
                    _status == 'verifie'
                        ? 'Vérifié'
                        : _status == 'refuse'
                            ? 'Refusé'
                            : 'En cours de vérification',
                    _status == 'verifie'
                        ? Icons.verified_outlined
                        : _status == 'refuse'
                            ? Icons.cancel_outlined
                            : Icons.pending_outlined,
                    isStatus: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _status == 'verifie'
                    ? Colors.green.withOpacity(0.1)
                    : _status == 'refuse'
                        ? Colors.red.withOpacity(0.1)
                        : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _status == 'verifie'
                      ? Colors.green.withOpacity(0.3)
                      : _status == 'refuse'
                          ? Colors.red.withOpacity(0.3)
                          : Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _status == 'verifie'
                        ? Icons.check_circle_outline
                        : _status == 'refuse'
                            ? Icons.cancel_outlined
                            : Icons.info_outline,
                    color: _status == 'verifie'
                        ? Colors.green[800]
                        : _status == 'refuse'
                            ? Colors.red[800]
                            : Colors.amber[800],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status == 'verifie'
                          ? 'Votre document a été vérifié avec succès par notre équipe.'
                          : _status == 'refuse'
                              ? 'Votre document a été refusé. Veuillez soumettre un document valide.'
                              : 'Vos documents sont en cours d\'examen par notre équipe. '
                                'Cette procédure peut prendre jusqu\'à 48 heures ouvrables. '
                                'Nous vous informerons par email dès que la vérification sera terminée.',
                      style: TextStyle(
                        color: _status == 'verifie'
                            ? Colors.green[800]
                            : _status == 'refuse'
                                ? Colors.red[800]
                                : Colors.amber[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Retour à l\'accueil',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _showSupportDialog(context);
              },
              icon: Icon(
                Icons.help_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              label: Text(
                'Besoin d\'aide ?',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, IconData icon, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              isStatus
                  ? _buildStatusBadge(_status)
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String label;
    Color textColor;

    switch (status) {
      case 'verifie':
        badgeColor = Colors.green;
        label = 'Vérifié';
        textColor = Colors.green;
        break;
      case 'refuse':
        badgeColor = Colors.red;
        label = 'Refusé';
        textColor = Colors.red;
        break;
      case 'en_cours':
      default:
        badgeColor = Colors.amber;
        label = 'En cours de vérification';
        textColor = Colors.amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Besoin d\'aide ?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Si vous avez des questions concernant la vérification de vos documents, vous pouvez nous contacter :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _contactMethod(context, Icons.email_outlined, 'support@monapp.com'),
              const SizedBox(height: 8),
              _contactMethod(context, Icons.phone_outlined, '01 23 45 67 89'),
              const SizedBox(height: 8),
              _contactMethod(context, Icons.schedule, 'Du lundi au vendredi, 9h-18h'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Fermer',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  Widget _contactMethod(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
