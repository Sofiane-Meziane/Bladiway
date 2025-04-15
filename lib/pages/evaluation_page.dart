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

  const EvaluationPage({super.key, required this.userId, required this.currentUserId});

  @override
  _EvaluationPageState createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? userData;
  bool isLoading = true; // Indicateur de chargement

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez sélectionner une note")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('reviews').add({
      'ratedUserId': widget.userId,
      'reviewerId': widget.currentUserId,
      'rating': _rating,
      'comment': _commentController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Évaluation soumise avec succès !")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Évite les problèmes avec le clavier
      appBar: AppBar(
        title: Text("Évaluer l'utilisateur"),
        backgroundColor: Color(0xFF2196F3), // Couleur de l'AppBar en bleu
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator()) // Indicateur de chargement
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: userData?['profileImageUrl'] != null
                          ? NetworkImage(userData!['profileImageUrl'])
                          : AssetImage('assets/default_avatar.png') as ImageProvider, // Image par défaut
                    ),
                    SizedBox(height: 10),
                    Text(
                      "${userData?['prenom'] ?? "Utilisateur"} ${userData?['nom'] ?? ""}",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text("Notez cet utilisateur"),
                    RatingBar.builder(
                      initialRating: 0,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemBuilder: (context, _) => Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
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
                        labelText: "Laissez un commentaire",
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2196F3), // Couleur du bouton en bleu
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Soumettre",
                        style: TextStyle(fontSize: 16, color: Colors.white), // Texte en blanc
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
