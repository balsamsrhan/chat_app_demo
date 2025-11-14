import 'package:chat_app_demo/services/auth_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _authService.updateLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('List Chats', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          if (!usersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final otherUsers = usersSnapshot.data!.docs
              .where((doc) => doc.id != currentUserId)
              .toList();

          if (otherUsers.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمون آخرون'));
          }

          return ListView.builder(
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final userDoc = otherUsers[index];
              final userId = userDoc.id;
              final username = userDoc['username'] ?? 'مجهول';
              final ids = [currentUserId, userId];
              ids.sort();
              final chatId = ids.join('_');

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, messagesSnapshot) {
                  String lastMessage = 'Start Chat';
                  bool isSentByMe = false;
                  int unreadCount = 0;
                  Timestamp? lastTimestamp;

                  if (messagesSnapshot.hasData && messagesSnapshot.data!.docs.isNotEmpty) {
                    final msgDoc = messagesSnapshot.data!.docs.first;
                    final msgData = msgDoc.data() as Map<String, dynamic>;
                    lastMessage = msgData['text'] ?? '';
                    isSentByMe = msgData['senderId'] == currentUserId;
                    lastTimestamp = msgData['timestamp'] as Timestamp?;
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .where('senderId', isNotEqualTo: currentUserId)
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, unreadSnapshot) {
                      if (unreadSnapshot.hasData) {
                        unreadCount = unreadSnapshot.data!.docs.length;
                      }

                      return _buildChatTile(
                        username: username,
                        lastMessage: lastMessage,
                        isSentByMe: isSentByMe,
                        unreadCount: unreadCount,
                        lastTimestamp: lastTimestamp,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: userId,
                                receiverName: username,
                              ),
                            ),
                          ).then((_) {
                            setState(() {});
                          });
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile({
    required String username,
    required String lastMessage,
    required bool isSentByMe,
    required int unreadCount,
    required Timestamp? lastTimestamp,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Hero(
              tag: 'user_$username',
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade600,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            title: Text(
              username,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              lastMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isSentByMe ? Colors.grey[600] : Colors.black87,
                fontWeight: isSentByMe
                    ? FontWeight.w400
                    : (unreadCount > 0 ? FontWeight.w600 : FontWeight.w500),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (lastTimestamp != null)
                  Text(
                    _formatTime(lastTimestamp),
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes} د';
    if (diff.inHours < 24) return '${diff.inHours} س';
    return '${date.day}/${date.month}';
  }
}