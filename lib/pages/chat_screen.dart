import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String reservationId;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.reservationId,
    required this.otherUserId,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String receiverName = "Chargement...";
  String? receiverProfileImageUrl;
  String? senderProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUsersData();
  }

  // Fetch data for both receiver and sender
  void _fetchUsersData() async {
    try {
      // Fetch receiver data
      DocumentSnapshot receiverDoc =
          await _firestore.collection('users').doc(widget.otherUserId).get();
      if (mounted && receiverDoc.exists) {
        final data = receiverDoc.data() as Map<String, dynamic>;
        setState(() {
          receiverName =
              "${data['prenom'] ?? ''} ${data['nom'] ?? 'Utilisateur'}".trim();
          if (receiverName.isEmpty) receiverName = "Utilisateur";
          receiverProfileImageUrl = data['profileImageUrl'] as String?;
        });
      } else if (mounted) {
        setState(() {
          receiverName = "Utilisateur"; // Default name if not found
        });
      }

      // Fetch sender data
      String currentUserId = _auth.currentUser!.uid;
      DocumentSnapshot senderDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (mounted && senderDoc.exists) {
        final data = senderDoc.data() as Map<String, dynamic>;
        setState(() {
          senderProfileImageUrl = data['profileImageUrl'] as String?;
        });
      }
    } catch (e) {
      // Handle potential errors during fetch, e.g., network issues
      print("Error fetching user data: $e");
      if (mounted) {
        setState(() {
          receiverName = "Erreur"; // Indicate an error occurred
        });
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      String currentUserId = _auth.currentUser!.uid;
      try {
        await _firestore.collection('messages').add({
          'reservationId': widget.reservationId,
          'senderId': currentUserId,
          'receiverId': widget.otherUserId,
          'text': _messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        _messageController.clear();
      } catch (e) {
        print("Error sending message: $e");
        // Optionally show a SnackBar to the user
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erreur d'envoi du message.")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final String currentUserId =
        _auth.currentUser?.uid ?? ''; // Handle potential null user

    // Return placeholder if currentUserId is somehow empty
    if (currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Erreur")),
        body: const Center(child: Text("Utilisateur non authentifié.")),
      );
    }

    return Scaffold(
      backgroundColor:
          colorScheme.surface, // Use theme surface color for background
      appBar: AppBar(
        backgroundColor: colorScheme.primary, // Use theme primary color
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.onPrimary,
          ), // Use theme onPrimary color
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          receiverName,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ), // Use theme onPrimary color
        ),
        elevation: 1, // Subtle shadow
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('messages')
                      .where('reservationId', isEqualTo: widget.reservationId)
                      .where(
                        'senderId',
                        whereIn: [currentUserId, widget.otherUserId],
                      )
                      .where(
                        'receiverId',
                        whereIn: [currentUserId, widget.otherUserId],
                      )
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Erreur de chargement des messages.",
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "Commencez la conversation !",
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  );
                }
                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: false, // Keep false if ordering ascending
                  padding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                  ), // Add padding
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageDoc = messages[index];
                    var messageData =
                        messageDoc.data()
                            as Map<String, dynamic>?; // Safely cast

                    // Handle cases where message data might be missing or invalid
                    if (messageData == null) {
                      return const SizedBox.shrink(); // Skip invalid message data
                    }

                    final message = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    Timestamp? timestamp =
                        messageData['timestamp'] as Timestamp?;
                    DateTime dateTime =
                        timestamp?.toDate() ??
                        DateTime.now(); // Use current time as fallback

                    // Skip rendering if senderId is empty
                    if (senderId.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    String messageDate = DateFormat(
                      'yyyy-MM-dd',
                    ).format(dateTime);
                    String messageTime = DateFormat('HH:mm').format(dateTime);

                    // Determine if the date header should be shown
                    bool showDateHeader = index == 0;
                    if (index > 0) {
                      var prevMessageData =
                          messages[index - 1].data() as Map<String, dynamic>?;
                      Timestamp? prevTimestamp =
                          prevMessageData?['timestamp'] as Timestamp?;
                      if (prevTimestamp != null) {
                        String prevMessageDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(prevTimestamp.toDate());
                        showDateHeader = messageDate != prevMessageDate;
                      }
                    }

                    bool isMe = senderId == currentUserId;
                    String? profileImageUrl =
                        isMe ? senderProfileImageUrl : receiverProfileImageUrl;

                    // Message Bubble Widget
                    Widget messageBubble = Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width *
                            0.75, // Max width constraint
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ), // Adjusted padding
                      margin: const EdgeInsets.symmetric(
                        vertical: 2,
                      ), // Reduced vertical margin
                      decoration: BoxDecoration(
                        color:
                            isMe
                                ? colorScheme.primary
                                : colorScheme
                                    .secondaryContainer, // Use secondaryContainer for others
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft:
                              isMe
                                  ? Radius.circular(18)
                                  : Radius.circular(4), // Chat tail effect
                          bottomRight:
                              isMe
                                  ? Radius.circular(4)
                                  : Radius.circular(18), // Chat tail effect
                        ),
                        boxShadow: [
                          // Subtle shadow for depth
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                            isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment
                                    .start, // Align time correctly
                        mainAxisSize: MainAxisSize.min, // Fit content
                        children: [
                          Text(
                            message,
                            style: TextStyle(
                              color:
                                  isMe
                                      ? colorScheme.onPrimary
                                      : colorScheme
                                          .onSecondaryContainer, // Corresponding on-colors
                              fontSize: 15, // Slightly larger text
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ), // Space between text and time
                          Text(
                            messageTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: (isMe
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSecondaryContainer)
                                  .withOpacity(0.7), // Adjusted time color
                            ),
                          ),
                        ],
                      ),
                    );

                    // Avatar Widget
                    Widget avatar = CircleAvatar(
                      radius: 16, // Slightly smaller avatar
                      backgroundColor: colorScheme.secondary.withOpacity(0.2),
                      backgroundImage:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl)
                              : null,
                      // Conditionally add onBackgroundImageError ONLY if backgroundImage is set
                      onBackgroundImageError:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? (_, __) {
                                // Handle image loading errors if necessary
                                print("Error loading image: $profileImageUrl");
                                // Optionally update state here to show a placeholder if needed
                              }
                              : null, // Pass null if no backgroundImage
                      child:
                          profileImageUrl == null || profileImageUrl.isEmpty
                              ? Icon(
                                Icons.person,
                                size: 18,
                                color: colorScheme.primary.withOpacity(0.8),
                              )
                              : null,
                    );

                    // Arrange Avatar and Bubble in a Row
                    Widget messageRow = Row(
                      mainAxisAlignment:
                          isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end, // Align avatar bottom with bubble bottom
                      children: [
                        if (!isMe) ...[
                          avatar,
                          const SizedBox(width: 8),
                        ], // Show avatar on the left for others
                        messageBubble,
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          avatar,
                        ], // Show avatar on the right for me
                      ],
                    );

                    return Column(
                      children: [
                        // Date Header
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 20,
                            ), // Increased padding
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(
                                    0.8,
                                  ), // Use surfaceVariant
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  // TODO: Consider using EasyLocalization here if needed
                                  DateFormat(
                                    'dd MMMM yyyy',
                                    'fr_FR',
                                  ).format(dateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight
                                            .w500, // Slightly lighter weight
                                    color:
                                        colorScheme
                                            .onSurfaceVariant, // Use onSurfaceVariant
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Message Row with Padding
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 3.0,
                          ), // Add small vertical padding
                          child: messageRow,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Message Input Area
          SafeArea(
            // Ensure input is not obscured by system UI (like keyboard)
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              margin: const EdgeInsets.only(
                bottom: 8.0,
                left: 8.0,
                right: 8.0,
              ), // Margin around the input area
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ), // Slightly different background for input area
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  // Add a subtle shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .end, // Align button nicely with multiline text
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Écrire un message...",
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        filled: true, // Needed for fillColor
                        fillColor:
                            Colors
                                .transparent, // Make TextField background transparent
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 15,
                        ), // Adjusted padding
                        border: InputBorder.none, // Remove internal border
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ), // Use onSurfaceVariant for text
                      minLines: 1,
                      maxLines: 5, // Allow multi-line input
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ), // Space between TextField and Button
                  Material(
                    // Use Material for ink splash effect and clipping
                    color: colorScheme.primary,
                    shape: CircleBorder(), // Make it circular
                    clipBehavior: Clip.antiAlias, // Clip ink splash to circle
                    child: InkWell(
                      onTap: _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          10.0,
                        ), // Padding inside button
                        child: Icon(
                          Icons.send,
                          color: colorScheme.onPrimary, // Theme onPrimary color
                          size: 22, // Slightly smaller icon
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
