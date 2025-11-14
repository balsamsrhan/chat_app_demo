class UserModel {
  final String? id;
  final String username;
  final String email;
  final DateTime createdAt;
  final DateTime? lastSeen;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
          : null,
    );
  }
}