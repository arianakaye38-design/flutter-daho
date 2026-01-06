import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  String _selectedFilter = 'all'; // all, pending, resolved, dismissed

  // Method to send notification to a user
  Future<void> _sendNotification(String userId, String message) async {
    try {
      // Fetch user type from users collection
      String userType = 'customer'; // Default
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          userType = userDoc.data()?['type'] ?? 'customer';
        }
      } catch (e) {
        debugPrint('Error fetching user type: $e');
      }

      // Create notification with proper userType
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'userType': userType,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '[NOTIFICATION] Sent to userId=$userId, userType=$userType: $message',
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // Method to view conversation
  void _viewConversation(String chatId, String reportedUserName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewConversationScreen(
          chatId: chatId,
          reportedUserName: reportedUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: Column(
        children: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text(
                  'Filter:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Row(
                            children: [
                              Icon(Icons.list, size: 18),
                              SizedBox(width: 8),
                              Text('All Reports'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(
                                Icons.pending,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text('Pending'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text('Resolved'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'dismissed',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Dismissed'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFilter = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reports list
          Expanded(child: _buildReportsList()),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true);

    // Apply filter
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
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
                Icon(Icons.report_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 'all'
                      ? 'No reports found'
                      : 'No $_selectedFilter reports',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            final status = report['status'] ?? 'pending';
            final createdAt = report['createdAt'] as Timestamp?;
            final reportedUserName = report['reportedUserName'] ?? 'Unknown';
            final reportedByEmail = report['reportedByEmail'] ?? 'Unknown';
            final reason = report['reason'] ?? 'No reason provided';
            final type = report['type'] ?? 'general';
            final chatId = report['chatId'];

            Color statusColor;
            Color statusTextColor;
            switch (status) {
              case 'pending':
                statusColor = const Color(0xFFFDE68A);
                statusTextColor = const Color(0xFF92400E);
                break;
              case 'resolved':
                statusColor = const Color(0xFFA7F3D0);
                statusTextColor = const Color(0xFF065F46);
                break;
              case 'dismissed':
                statusColor = const Color(0xFFE5E7EB);
                statusTextColor = const Color(0xFF374151);
                break;
              default:
                statusColor = const Color(0xFFBFDBFE);
                statusTextColor = const Color(0xFF1E40AF);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'message'
                      ? Colors.orange
                      : const Color(0xFF1976d2),
                  child: Icon(
                    type == 'message' ? Icons.message : Icons.report,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Report: $reportedUserName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Reported by: $reportedByEmail',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (createdAt != null)
                          Flexible(
                            child: Text(
                              DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(createdAt.toDate()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Type', type),
                        _buildDetailRow('Reported User', reportedUserName),
                        _buildDetailRow(
                          'Reported User ID',
                          report['reportedUser'] ?? 'N/A',
                        ),
                        _buildDetailRow('Reported By', reportedByEmail),
                        _buildDetailRow(
                          'Reporter ID',
                          report['reportedBy'] ?? 'N/A',
                        ),
                        if (chatId != null) _buildDetailRow('Chat ID', chatId),
                        const Divider(height: 24),
                        const Text(
                          'Reason:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(reason),
                        const SizedBox(height: 16),
                        // View button for message reports
                        if (type == 'message' && chatId != null) ...[
                          ElevatedButton.icon(
                            onPressed: () =>
                                _viewConversation(chatId, reportedUserName),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Conversation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976d2),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Action buttons (only show for pending reports)
                        if (status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _flagReport(
                                    reportId,
                                    report['reportedBy'] ?? '',
                                    report['reportedUser'] ?? '',
                                    reportedUserName,
                                    reportedByEmail,
                                  ),
                                  icon: const Icon(Icons.flag, size: 18),
                                  label: const Text('Flag'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _dismissReport(
                                    reportId,
                                    report['reportedBy'] ?? '',
                                  ),
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text('Dismiss'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (status != 'pending')
                          ElevatedButton.icon(
                            onPressed: () =>
                                _updateReportStatus(reportId, 'pending'),
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('Reopen Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _flagReport(
    String reportId,
    String reporterId,
    String reportedUserId,
    String reportedUserName,
    String reporterEmail,
  ) async {
    try {
      debugPrint('[FLAG REPORT] Starting flag report process');
      debugPrint('[FLAG REPORT] Reporter ID: $reporterId');
      debugPrint('[FLAG REPORT] Reported User ID: $reportedUserId');
      debugPrint('[FLAG REPORT] Reported User Name: $reportedUserName');

      // Update report status
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'resolved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('[FLAG REPORT] Report status updated to resolved');

      // Send notification to reporter (success)
      await _sendNotification(
        reporterId,
        'Report successful! The user "$reportedUserName" has been warned for their violation.',
      );
      debugPrint('[FLAG REPORT] Notification sent to reporter');

      // Send notification to reported user (warning)
      await _sendNotification(
        reportedUserId,
        'Your account has been reported and reviewed by the administrator. A violation was confirmed, and a warning has been issued.',
      );
      debugPrint('[FLAG REPORT] Notification sent to reported user');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report flagged and notifications sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[FLAG REPORT] ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to flag report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _dismissReport(String reportId, String reporterId) async {
    try {
      // Update report status
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'dismissed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Send notification to reporter
      await _sendNotification(
        reporterId,
        'Thanks for your report! The admin has reviewed it and found no violations.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report dismissed and notification sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report marked as $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// View Conversation Screen (Read-only)
class ViewConversationScreen extends StatefulWidget {
  final String chatId;
  final String reportedUserName;

  const ViewConversationScreen({
    super.key,
    required this.chatId,
    required this.reportedUserName,
  });

  @override
  State<ViewConversationScreen> createState() => _ViewConversationScreenState();
}

class _ViewConversationScreenState extends State<ViewConversationScreen> {
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadConversationInfo();
  }

  Future<void> _loadConversationInfo() async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.chatId)
          .get();

      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        setState(() {
          _userNames = {
            data['userId'] ?? '': data['userName'] ?? 'User',
            data['courierId'] ?? '': data['courierName'] ?? 'Courier',
            data['ownerId'] ?? '': data['ownerName'] ?? 'Owner',
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading conversation info: $e');
    }
  }

  String _getSenderName(String senderId) {
    return _userNames[senderId] ?? 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation: ${widget.reportedUserName}'),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            .doc(widget.chatId)
            .collection('chat')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading messages: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No messages found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final messages = snapshot.data!.docs;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange[100],
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a read-only view of the conversation',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final messageText = message['message'] ?? '';
                    final senderId = message['senderId'] ?? '';
                    final timestamp = message['timestamp'] as Timestamp?;
                    final senderName = _getSenderName(senderId);

                    String timeStr = '';
                    if (timestamp != null) {
                      timeStr = DateFormat(
                        'hh:mm a',
                      ).format(timestamp.toDate());
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF1976d2),
                                child: Text(
                                  senderName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              messageText,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
