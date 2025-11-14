import 'package:chat_app_demo/model/conversation_model.dart';
import 'package:chat_app_demo/model/message_model.dart';
import 'package:chat_app_demo/model/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection('users')
        .where('id', isNotEqualTo: _auth.currentUser!.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<String> createConversation(String receiverId) async {
    final currentUserId = _auth.currentUser!.uid;
    final participants = [currentUserId, receiverId];
    participants.sort();
    final conversationId = participants.join('_');

    final conversationData = {
      'participants': participants,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': {
        currentUserId: 0,
        receiverId: 0,
      },
    };

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .set(conversationData);

    return conversationId;
  }

  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    final currentUserId = _auth.currentUser!.uid;
    final participants = [currentUserId, receiverId];
    participants.sort();
    final conversationId = participants.join('_');

    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) {
      await createConversation(receiverId);
    }

    final messageData = {
      'conversationId': conversationId,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isSeen': false,
    };

    await _firestore.collection('messages').add(messageData);

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastMessage': messageData,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });
  }

  Stream<List<ConversationModel>> getConversations() {
    final currentUserId = _auth.currentUser!.uid;

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessage.timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ConversationModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> markMessagesAsSeen(String conversationId) async {
    final currentUserId = _auth.currentUser!.uid;

    final messagesSnapshot = await _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isSeen', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'isSeen': true});
    }

    await batch.commit();

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
      'unreadCount.$currentUserId': 0,
    });
  }

  Future<void> updateLastSeen() async {
    final currentUserId = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .update({
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null;
  }
}