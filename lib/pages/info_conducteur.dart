import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'evaluation_page.dart';

class InfoConducteurPage extends StatefulWidget {
  final String conductorId;
  final String reservationId;
  final String currentUserId;

  const InfoConducteurPage({
    super.key,
    required this.conductorId,
    required this.reservationId,
    required this.currentUserId,
  });

  @override
  _InfoConducteurPageState createState() => _InfoConducteurPageState();
}

class _InfoConducteurPageState extends State<InfoConducteurPage> {
  late Future<DocumentSnapshot> _userFuture;
  late Future<QuerySnapshot> _reviewsFuture;
  bool _hasAlreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkExistingReview();
  }

  Future<void> _checkExistingReview() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('reviewerId', isEqualTo: widget.currentUserId)
              .where('ratedUserId', isEqualTo: widget.conductorId)
              .get();

      if (mounted) {
        setState(() {
          _hasAlreadyReviewed = querySnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print("Erreur lors de la vérification des avis existants: $e");
    }
  }

  void _loadData() {
    _userFuture =
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.conductorId)
            .get();
    _reviewsFuture =
        FirebaseFirestore.instance
            .collection('reviews')
            .where('ratedUserId', isEqualTo: widget.conductorId)
            .get();
  }

  void _refreshReviews() {
    setState(() {
      _reviewsFuture =
          FirebaseFirestore.instance
              .collection('reviews')
              .where('ratedUserId', isEqualTo: widget.conductorId)
              .get();
      _hasAlreadyReviewed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.conductorId.isEmpty) {
      return Scaffold(
        body: Center(child: Text("Erreur: ID du conducteur invalide")),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Bladiway',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.white),
                            onPressed: () async {
                              final userDoc =
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.conductorId)
                                      .get();
                              if (userDoc.exists) {
                                final userData =
                                    userDoc.data() as Map<String, dynamic>;
                                final phoneNumber =
                                    userData['phone'] as String?;
                                if (phoneNumber != null) {
                                  final url = 'tel:$phoneNumber';
                                  if (await canLaunch(url)) {
                                    await launch(url);
                                  }
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.message,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ChatPage(
                                        reservationId: widget.reservationId,
                                        otherUserId: widget.conductorId,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: _userFuture,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (userSnapshot.hasError ||
                          !userSnapshot.hasData ||
                          !userSnapshot.data!.exists) {
                        return const Center(
                          child: Text(
                            "Erreur lors du chargement des données du conducteur",
                          ),
                        );
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final profileImageUrl =
                          userData['profileImageUrl'] as String?;
                      final prenom = userData['prenom'] as String? ?? '';
                      final nom = userData['nom'] as String? ?? '';
                      final phone =
                          userData['phone'] as String? ?? 'Non disponible';
                      final isValidated =
                          userData['isValidated'] as bool? ?? false;
                      final dateNaissance =
                          userData['dateNaissance'] as String? ?? '';
                      final age =
                          dateNaissance.isNotEmpty
                              ? _calculateAge(dateNaissance)
                              : -1; // Use -1 to indicate an invalid age
                      final dateInscription =
                          userData['dateInscription'] as Timestamp? ??
                          Timestamp.now();
                      final formattedDate = DateFormat(
                        'MM/yyyy',
                      ).format(dateInscription.toDate());

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Hero(
                                            tag:
                                                'conductor-${widget.conductorId}',
                                            child: CircleAvatar(
                                              radius: 40,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              backgroundImage:
                                                  profileImageUrl != null
                                                      ? NetworkImage(
                                                        profileImageUrl,
                                                      )
                                                      : null,
                                              child:
                                                  profileImageUrl == null
                                                      ? const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                      )
                                                      : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$prenom $nom',
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                FutureBuilder<QuerySnapshot>(
                                                  future: _reviewsFuture,
                                                  builder: (
                                                    context,
                                                    reviewsSnapshot,
                                                  ) {
                                                    if (reviewsSnapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return Row(
                                                        children: const [
                                                          Icon(
                                                            Icons.star,
                                                            color: Colors.grey,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text("Chargement..."),
                                                        ],
                                                      );
                                                    }
                                                    double rating = 0;
                                                    int reviewCount = 0;
                                                    if (reviewsSnapshot
                                                            .hasData &&
                                                        reviewsSnapshot
                                                            .data!
                                                            .docs
                                                            .isNotEmpty) {
                                                      reviewCount =
                                                          reviewsSnapshot
                                                              .data!
                                                              .docs
                                                              .length;
                                                      double totalRating = 0;
                                                      for (var doc
                                                          in reviewsSnapshot
                                                              .data!
                                                              .docs) {
                                                        final reviewData =
                                                            doc.data()
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >;
                                                        totalRating +=
                                                            (reviewData['rating']
                                                                        as num? ??
                                                                    0)
                                                                .toDouble();
                                                      }
                                                      rating =
                                                          totalRating /
                                                          reviewCount;
                                                    }
                                                    return Row(
                                                      children: [
                                                        Icon(
                                                          Icons.star,
                                                          color: Colors.amber,
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          rating
                                                              .toStringAsFixed(
                                                                1,
                                                              ),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          '($reviewCount avis)',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    if (isValidated)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: const [
                                                            Icon(
                                                              Icons.verified,
                                                              color:
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Vérifié',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 16),
                                      Column(
                                        children: [
                                          _buildInfoRow(
                                            icon: Icons.phone_android,
                                            label: 'Numéro de téléphone',
                                            value: phone,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildInfoRow(
                                            icon: Icons.cake,
                                            label: 'Âge',
                                            value:
                                                age >= 0
                                                    ? '$age ans'
                                                    : 'Non spécifié',
                                          ),
                                          const SizedBox(height: 16),
                                          _buildInfoRow(
                                            icon: Icons.calendar_today,
                                            label: 'Membre depuis',
                                            value: formattedDate,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Les Avis',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          FutureBuilder<QuerySnapshot>(
                                            future: _reviewsFuture,
                                            builder: (
                                              context,
                                              reviewsSnapshot,
                                            ) {
                                              if (reviewsSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Text("...");
                                              }
                                              int reviewCount = 0;
                                              double rating = 0;
                                              if (reviewsSnapshot.hasData &&
                                                  reviewsSnapshot
                                                      .data!
                                                      .docs
                                                      .isNotEmpty) {
                                                reviewCount =
                                                    reviewsSnapshot
                                                        .data!
                                                        .docs
                                                        .length;
                                                double totalRating = 0;
                                                for (var doc
                                                    in reviewsSnapshot
                                                        .data!
                                                        .docs) {
                                                  final reviewData =
                                                      doc.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  totalRating +=
                                                      (reviewData['rating']
                                                                  as num? ??
                                                              0)
                                                          .toDouble();
                                                }
                                                rating =
                                                    totalRating / reviewCount;
                                              }
                                              return Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${rating.toStringAsFixed(1)} ($reviewCount)',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      FutureBuilder<QuerySnapshot>(
                                        future: _reviewsFuture,
                                        builder: (context, reviewsSnapshot) {
                                          if (reviewsSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(20.0),
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          if (reviewsSnapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                "Erreur lors du chargement des avis",
                                              ),
                                            );
                                          }
                                          var reviewDocs =
                                              reviewsSnapshot.data?.docs ?? [];
                                          reviewDocs.sort((a, b) {
                                            var aTimestamp =
                                                a['timestamp'] as Timestamp? ??
                                                Timestamp(0, 0);
                                            var bTimestamp =
                                                b['timestamp'] as Timestamp? ??
                                                Timestamp(0, 0);
                                            return bTimestamp.compareTo(
                                              aTimestamp,
                                            );
                                          });
                                          var limitedDocs =
                                              reviewDocs.take(5).toList();
                                          if (limitedDocs.isEmpty) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(20.0),
                                                child: Text(
                                                  "Aucun avis pour le moment",
                                                ),
                                              ),
                                            );
                                          }
                                          return ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: limitedDocs.length,
                                            itemBuilder: (context, index) {
                                              final reviewData =
                                                  limitedDocs[index].data()
                                                      as Map<String, dynamic>;
                                              final rating =
                                                  (reviewData['rating']
                                                              as num? ??
                                                          0)
                                                      .toInt();
                                              final comment =
                                                  reviewData['comment']
                                                      as String? ??
                                                  '';
                                              final reviewDate =
                                                  reviewData['timestamp']
                                                      as Timestamp? ??
                                                  Timestamp.now();
                                              final reviewerId =
                                                  reviewData['reviewerId']
                                                      as String? ??
                                                  '';
                                              if (reviewerId.isEmpty) {
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 16,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.grey[200]!,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.05),
                                                        blurRadius: 3,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 20,
                                                            backgroundColor:
                                                                theme
                                                                    .colorScheme
                                                                    .primary
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                            child: const Icon(
                                                              Icons.person,
                                                              size: 20,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const Text(
                                                                'Anonyme',
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                DateFormat(
                                                                  'dd/MM/yyyy',
                                                                ).format(
                                                                  reviewDate
                                                                      .toDate(),
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const Spacer(),
                                                          Row(
                                                            children: List.generate(
                                                              5,
                                                              (
                                                                starIndex,
                                                              ) => Icon(
                                                                starIndex <
                                                                        rating
                                                                    ? Icons.star
                                                                    : Icons
                                                                        .star_border,
                                                                color:
                                                                    starIndex <
                                                                            rating
                                                                        ? Colors
                                                                            .amber
                                                                        : Colors
                                                                            .grey,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (comment
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        Text(
                                                          comment,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                );
                                              }
                                              return FutureBuilder<
                                                DocumentSnapshot
                                              >(
                                                future:
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(reviewerId)
                                                        .get(),
                                                builder: (
                                                  context,
                                                  reviewerSnapshot,
                                                ) {
                                                  String reviewerName =
                                                      'Anonyme';
                                                  String? profileImage;
                                                  if (reviewerSnapshot
                                                          .hasData &&
                                                      reviewerSnapshot
                                                          .data!
                                                          .exists) {
                                                    final reviewerData =
                                                        reviewerSnapshot.data!
                                                                .data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    reviewerName =
                                                        '${reviewerData['prenom'] ?? ''} ${reviewerData['nom'] ?? ''}';
                                                    profileImage =
                                                        reviewerData['profileImageUrl']
                                                            as String?;
                                                  }
                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 16,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[200]!,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                0.05,
                                                              ),
                                                          blurRadius: 3,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 20,
                                                              backgroundColor: theme
                                                                  .colorScheme
                                                                  .primary
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              backgroundImage:
                                                                  profileImage !=
                                                                          null
                                                                      ? NetworkImage(
                                                                        profileImage,
                                                                      )
                                                                      : null,
                                                              child:
                                                                  profileImage ==
                                                                          null
                                                                      ? const Icon(
                                                                        Icons
                                                                            .person,
                                                                        size:
                                                                            20,
                                                                      )
                                                                      : null,
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  reviewerName,
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  DateFormat(
                                                                    'dd/MM/yyyy',
                                                                  ).format(
                                                                    reviewDate
                                                                        .toDate(),
                                                                  ),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color:
                                                                        Colors
                                                                            .grey[600],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const Spacer(),
                                                            Row(
                                                              children: List.generate(
                                                                5,
                                                                (
                                                                  starIndex,
                                                                ) => Icon(
                                                                  starIndex <
                                                                          rating
                                                                      ? Icons
                                                                          .star
                                                                      : Icons
                                                                          .star_border,
                                                                  color:
                                                                      starIndex <
                                                                              rating
                                                                          ? Colors
                                                                              .amber
                                                                          : Colors
                                                                              .grey,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (comment
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Text(
                                                            comment,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      FutureBuilder<QuerySnapshot>(
                                        future: _reviewsFuture,
                                        builder: (context, snapshot) {
                                          final hasMoreReviews =
                                              snapshot.hasData &&
                                              (snapshot.data?.docs.length ??
                                                      0) >
                                                  5;
                                          return hasMoreReviews
                                              ? Center(
                                                child: TextButton(
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Fonctionnalité à venir: voir tous les avis',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Voir tous les avis',
                                                  ),
                                                ),
                                              )
                                              : const SizedBox.shrink();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text('CONTACTER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatPage(
                            reservationId: widget.reservationId,
                            otherUserId: widget.conductorId,
                          ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.phone_outlined),
                label: const Text('APPELER'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final userDoc =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.conductorId)
                          .get();
                  if (userDoc.exists) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final phoneNumber = userData['phone'] as String?;
                    if (phoneNumber != null) {
                      final url = 'tel:$phoneNumber';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateAge(String dateNaissance) {
    try {
      final birthDate = DateFormat('dd/MM/yyyy').parse(dateNaissance);
      final currentDate = DateTime(
        2025,
        4,
        17,
      ); // Current date as of April 17, 2025
      int age = currentDate.year - birthDate.year;
      if (currentDate.month < birthDate.month ||
          (currentDate.month == birthDate.month &&
              currentDate.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return -1; // Return -1 to indicate an error in parsing the date
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
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
}
