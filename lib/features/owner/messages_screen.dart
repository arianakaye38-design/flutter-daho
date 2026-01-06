import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OwnerMessagesScreen extends StatefulWidget {
  final String? preselectedCourierId;

  const OwnerMessagesScreen({super.key, this.preselectedCourierId});

  @override
  State<OwnerMessagesScreen> createState() => _OwnerMessagesScreenState();
}

class _OwnerMessagesScreenState extends State<OwnerMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedChatId;
  String? _selectedCourierName;
  String? _selectedCourierId; // Track the courier ID

  @override
  void initState() {
    super.initState();
    // If a preselected courier is provided, initialize or open that conversation
    if (widget.preselectedCourierId != null) {
      _initializeConversation(widget.preselectedCourierId!);
    }
  }

  Future<void> _initializeConversation(String courierId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Check if conversation already exists (owner messaging courier)
      final existingConversation = await FirebaseFirestore.instance
          .collection('messages')
          .where('ownerId', isEqualTo: currentUserId)
          .where('courierId', isEqualTo: courierId)
          .limit(1)
          .get();

      if (existingConversation.docs.isNotEmpty) {
        // Conversation exists, update it to ensure all fields are present
        final chatId = existingConversation.docs.first.id;
        final courierName = await _getCourierName(courierId);

        // Get owner name
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final ownerName = ownerDoc.data()?['name'] ?? 'Owner';

        // Update conversation to ensure all fields exist
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(chatId)
            .set({
              'ownerId': currentUserId,
              'ownerName': ownerName,
              'courierId': courierId,
              'courierName': courierName,
              'deletedByOwner': false,
              'deletedByCourier': false,
            }, SetOptions(merge: true));

        setState(() {
          _selectedChatId = chatId;
          _selectedCourierName = courierName;
          _selectedCourierId = courierId;
        });
      } else {
        // Create new conversation
        final courierName = await _getCourierName(courierId);

        // Get owner name
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final ownerName = ownerDoc.data()?['name'] ?? 'Owner';

        final newConversation = await FirebaseFirestore.instance
            .collection('messages')
            .add({
              'ownerId': currentUserId,
              'ownerName': ownerName,
              'courierId': courierId,
              'courierName': courierName,
              'lastMessage': '',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'unreadCountOwner': 0,
              'unreadCountCourier': 0,
              'deletedByOwner': false,
              'deletedByCourier': false,
            });

        setState(() {
          _selectedChatId = newConversation.id;
          _selectedCourierName = courierName;
          _selectedCourierId = courierId;
        });
      }
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
    }
  }

  Future<String> _getCourierName(String courierId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(courierId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          return '$firstName $lastName'.trim();
        }
        return data?['email']?.split('@')[0] ?? 'Courier';
      }
    } catch (e) {
      debugPrint('Error fetching courier name: $e');
    }
    return 'Courier';
  }

  void _showDeleteConfirmation(String chatId, String courierName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete your conversation with $courierName? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    // Validate chatId is not empty
    if (chatId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid chat ID'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Mark conversation as deleted for owner only
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(chatId)
          .update({'deletedByOwner': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // If the deleted chat was selected, go back to conversations list
      if (_selectedChatId == chatId) {
        setState(() {
          _selectedChatId = null;
          _selectedCourierName = null;
          _selectedCourierId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDialog(String chatId, String courierName, String courierId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Courier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report $courierName for inappropriate behavior?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                hintText: 'Describe the issue...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              reasonController.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              reasonController.dispose();
              Navigator.of(ctx).pop();
              await _submitReport(chatId, courierName, courierId, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(
    String chatId,
    String courierName,
    String courierId,
    String reason,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedBy': currentUser.uid,
        'reportedByEmail': currentUser.email,
        'reportedUser': courierId,
        'reportedUserName': courierName,
        'chatId': chatId,
        'reason': reason.isEmpty ? 'No reason provided' : reason,
        'type': 'message',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: const Color(0xFF1976d2),
        ),
        body: const Center(child: Text('Please log in to view messages')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedChatId == null ? 'Messages' : _selectedCourierName ?? 'Chat',
        ),
        backgroundColor: const Color(0xFF1976d2),
        leading: _selectedChatId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedChatId = null;
                    _selectedCourierName = null;
                    _selectedCourierId = null;
                  });
                },
              )
            : null,
      ),
      body: _selectedChatId == null
          ? _buildConversationsList(currentUserId)
          : _buildChatView(currentUserId),
    );
  }

  Widget _buildConversationsList(String ownerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact couriers to start messaging',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final conversations = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['deletedByOwner'] != true;
        }).toList();

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contact couriers to start messaging',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation =
                conversations[index].data() as Map<String, dynamic>;
            final chatId = conversations[index].id;
            final courierId = conversation['courierId'] ?? '';
            final lastMessage = conversation['lastMessage'] ?? '';
            final lastMessageTime =
                conversation['lastMessageTime'] as Timestamp?;
            final unreadCount = conversation['unreadCountOwner'] ?? 0;
            // Use stored courierName from conversation
            String courierName = conversation['courierName'] ?? '';

            // Skip conversations with invalid courierId
            if (courierId.isEmpty) {
              return const SizedBox.shrink();
            }

            // If courierName is not in conversation, fetch it from users collection
            if (courierName.isEmpty) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(courierId)
                    .get(),
                builder: (context, userSnapshot) {
                  String fetchedCourierName = 'Courier';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    fetchedCourierName = userData?['name'] ?? 'Courier';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1976d2),
                        child: Icon(Icons.delivery_dining, color: Colors.white),
                      ),
                      title: Text(
                        fetchedCourierName,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (lastMessageTime != null)
                                Text(
                                  _formatMessageTime(lastMessageTime.toDate()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount > 9
                                        ? '9+'
                                        : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _showDeleteConfirmation(
                                  chatId,
                                  fetchedCourierName,
                                );
                              } else if (value == 'report') {
                                _showReportDialog(
                                  chatId,
                                  fetchedCourierName,
                                  courierId,
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Chat'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.report, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Report'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedChatId = chatId;
                          _selectedCourierName = fetchedCourierName;
                          _selectedCourierId = courierId;
                        });
                        FirebaseFirestore.instance
                            .collection('messages')
                            .doc(chatId)
                            .update({'unreadCountOwner': 0});
                      },
                    ),
                  );
                },
              );
            }

            // If courierName exists in conversation, use it directly
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1976d2),
                  child: Icon(Icons.delivery_dining, color: Colors.white),
                ),
                title: Text(
                  courierName,
                  style: TextStyle(
                    fontWeight: unreadCount > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lastMessageTime != null)
                          Text(
                            _formatMessageTime(lastMessageTime.toDate()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(chatId, courierName);
                        } else if (value == 'report') {
                          _showReportDialog(chatId, courierName, courierId);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Chat'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.report, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Report'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedChatId = chatId;
                    _selectedCourierName = courierName;
                    _selectedCourierId = courierId;
                  });
                  FirebaseFirestore.instance
                      .collection('messages')
                      .doc(chatId)
                      .update({'unreadCountOwner': 0});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatView(String ownerId) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .doc(_selectedChatId)
                .collection('chat')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No messages yet. Start the conversation!'),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message =
                      messages[index].data() as Map<String, dynamic>;
                  final messageText = message['message'] ?? '';
                  final senderId = message['senderId'] ?? '';
                  final timestamp = message['timestamp'] as Timestamp?;
                  final isMe = senderId == ownerId;

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF1976d2)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            messageText,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('h:mm a').format(timestamp.toDate()),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF1976d2),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _selectedChatId == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Get current user data for name
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Owner';

      // Get or create conversation document
      final conversationRef = FirebaseFirestore.instance
          .collection('messages')
          .doc(_selectedChatId);

      final conversationDoc = await conversationRef.get();
      final conversationData = conversationDoc.data();

      // Ensure both IDs exist for queries to work
      final courierId = conversationData?['courierId'] ?? _selectedCourierId;
      final courierName = conversationData?['courierName'] ?? 'Courier';

      debugPrint('[OWNER] Sending message to courierId: $courierId');

      // Add message to chat subcollection
      await conversationRef.collection('chat').add({
        'message': messageText,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create/update conversation with BOTH owner and courier IDs
      await conversationRef.set({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCountCourier': FieldValue.increment(1),
        'unreadCountOwner': 0,
        'ownerId': currentUserId, // Critical: owner ID for queries
        'courierId': courierId, // Critical: courier ID for queries
        'ownerName': currentUserName,
        'courierName': courierName,
        'deletedByOwner': false,
        'deletedByCourier': false,
      }, SetOptions(merge: true));

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
