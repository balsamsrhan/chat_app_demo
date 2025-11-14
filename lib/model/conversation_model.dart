import 'package:chat_app_demo/model/message_model.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final MessageModel? lastMessage;
  final DateTime createdAt;
  final Map<String, int> unreadCount;

  ConversationModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
    required this.unreadCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage?.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
    };
  }

  factory ConversationModel.fromMap(String id, Map<String, dynamic> map) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] != null
          ? MessageModel.fromMap('', map['lastMessage'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }
}