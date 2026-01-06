import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CourierMessagesScreen extends StatefulWidget {
  final String? preselectedUserId;

  const CourierMessagesScreen({super.key, this.preselectedUserId});

  @override
  State<CourierMessagesScreen> createState() => _CourierMessagesScreenState();
}

class _CourierMessagesScreenState extends State<CourierMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedChatId;
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    // If a preselected user is provided, initialize or open that conversation
    if (widget.preselectedUserId != null) {
      _initializeConversation(widget.preselectedUserId!);
    }
  }

  Future<void> _initializeConversation(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Check if conversation already exists
      final existingConversation = await FirebaseFirestore.instance
          .collection('messages')
          .where('courierId', isEqualTo: currentUserId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingConversation.docs.isNotEmpty) {
        // Conversation exists, select it
        final chatId = existingConversation.docs.first.id;
        final userName = await _getUserName(userId);
        setState(() {
          _selectedChatId = chatId;
          _selectedUserName = userName;
        });
      } else {
        // Create new conversation
        final userName = await _getUserName(userId);
        final newConversation = await FirebaseFirestore.instance
            .collection('messages')
            .add({
              'courierId': currentUserId,
              'userId': userId,
              'lastMessage': '',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'unreadCountCourier': 0,
              'unreadCountUser': 0,
            });

        setState(() {
          _selectedChatId = newConversation.id;
          _selectedUserName = userName;
        });
      }
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['name'] ?? data?['firstName'] ?? 'Customer';
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
    return 'Customer';
  }

  void _showDeleteConfirmation(String chatId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete your conversation with $userName? This action cannot be undone.',
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
      // Mark conversation as deleted for courier only
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(chatId)
          .update({'deletedByCourier': true});

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
          _selectedUserName = null;
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

  void _showReportDialog(String chatId, String userName, String userId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report $userName for inappropriate behavior?'),
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
              await _submitReport(chatId, userName, userId, reason);
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
    String userName,
    String userId,
    String reason,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedBy': currentUser.uid,
        'reportedByEmail': currentUser.email,
        'reportedUser': userId,
        'reportedUserName': userName,
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
          _selectedChatId == null ? 'Messages' : _selectedUserName ?? 'Chat',
        ),
        backgroundColor: const Color(0xFF1976d2),
        leading: _selectedChatId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedChatId = null;
                    _selectedUserName = null;
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

  Widget _buildConversationsList(String courierId) {
    debugPrint(
      '[COURIER] Building conversations list for courierId: $courierId',
    );
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('courierId', isEqualTo: courierId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[COURIER] Waiting for conversations...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint(
            '[COURIER] Error loading conversations: ${snapshot.error}',
          );
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint(
            '[COURIER] No data or empty docs. hasData: ${snapshot.hasData}, docs count: ${snapshot.data?.docs.length ?? 0}',
          );
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
                  'Messages from customers will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        debugPrint(
          '[COURIER] Found ${snapshot.data!.docs.length} total conversations',
        );
        final conversations = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint(
            '[COURIER] Doc ${doc.id}: deletedByCourier=${data['deletedByCourier']}, userId=${data['userId']}, courierId=${data['courierId']}',
          );
          return data['deletedByCourier'] != true;
        }).toList();

        debugPrint(
          '[COURIER] After filtering: ${conversations.length} conversations to display',
        );

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
                  'Your conversations will appear here',
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

            // Support both customer-courier and owner-courier conversations
            final userId = conversation['userId'];
            final ownerId = conversation['ownerId'];
            final otherUserId = userId ?? ownerId ?? '';

            final lastMessage = conversation['lastMessage'] ?? '';
            final lastMessageTime =
                conversation['lastMessageTime'] as Timestamp?;
            final unreadCount = conversation['unreadCountCourier'] ?? 0;

            // Get the appropriate name - userName for customers, ownerName for owners
            String displayName =
                conversation['userName'] ?? conversation['ownerName'] ?? '';

            // Determine user type for icon
            final isOwner = ownerId != null && userId == null;

            // Skip conversations with invalid otherUserId
            if (otherUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            // If displayName is not in conversation, fetch it from users collection
            if (displayName.isEmpty) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  String fetchedUserName = isOwner ? 'Owner' : 'Customer';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    fetchedUserName = userData?['name'] ?? fetchedUserName;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1976d2),
                        child: Icon(
                          isOwner ? Icons.store : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        fetchedUserName,
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
                                  fetchedUserName,
                                );
                              } else if (value == 'report') {
                                _showReportDialog(
                                  chatId,
                                  fetchedUserName,
                                  userId,
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
                          _selectedUserName = fetchedUserName;
                        });

                        // Mark messages as read
                        FirebaseFirestore.instance
                            .collection('messages')
                            .doc(chatId)
                            .update({'unreadCountCourier': 0});
                      },
                    ),
                  );
                },
              );
            }

            // If displayName exists in conversation, use it directly without FutureBuilder
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1976d2),
                  child: Icon(
                    isOwner ? Icons.store : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  displayName,
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
                          _showDeleteConfirmation(chatId, displayName);
                        } else if (value == 'report') {
                          _showReportDialog(chatId, displayName, otherUserId);
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
                    _selectedUserName = displayName;
                  });

                  // Mark messages as read
                  FirebaseFirestore.instance
                      .collection('messages')
                      .doc(chatId)
                      .update({'unreadCountCourier': 0});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatView(String courierId) {
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
                  final isMe = senderId == courierId;

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
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Courier';

      // Get or create conversation document
      final conversationRef = FirebaseFirestore.instance
          .collection('messages')
          .doc(_selectedChatId);

      final conversationDoc = await conversationRef.get();
      final conversationData = conversationDoc.data();

      // Ensure both IDs exist for queries to work
      final userId = conversationData?['userId'];
      final userName = conversationData?['userName'] ?? 'Customer';

      // Add message to chat subcollection
      await conversationRef.collection('chat').add({
        'message': messageText,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create/update conversation with BOTH user IDs
      await conversationRef.set({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCountUser': FieldValue.increment(1),
        'unreadCountCourier': 0,
        'courierId': currentUserId,
        'userId': userId, // Critical: customer ID for queries
        'courierName': currentUserName,
        'userName': userName,
        'deletedByUser': false,
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
