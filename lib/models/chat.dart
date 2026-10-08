class ChatUserRef {
  final String id;
  final String name;
  final String? role;
  final String? avatar;

  ChatUserRef({required this.id, required this.name, this.role, this.avatar});

  factory ChatUserRef.fromJson(Map<String, dynamic> json) {
    return ChatUserRef(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}

class Conversation {
  final String id;
  final ChatUserRef otherUser;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  Conversation copyWith({
    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      otherUser: otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'].toString(),
      otherUser: json['otherUser'] is Map<String, dynamic>
          ? ChatUserRef.fromJson(json['otherUser'] as Map<String, dynamic>)
          : ChatUserRef(id: '', name: 'Unknown'),
      lastMessage: json['lastMessage'] as String?,
      lastMessageType: json['lastMessageType'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString())
          : null,
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount'] as int
          : int.tryParse('${json['unreadCount'] ?? 0}') ?? 0,
    );
  }
}

class ChatContact {
  final String id;
  final String name;
  final String? role;
  final String? avatar;
  final String? unionId;
  final String? enrollmentId;

  ChatContact({
    required this.id,
    required this.name,
    this.role,
    this.avatar,
    this.unionId,
    this.enrollmentId,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      avatar: json['avatar'] as String?,
      unionId: json['unionId']?.toString(),
      enrollmentId: json['enrollmentId']?.toString(),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String type;
  final String? mediaUrl;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      senderId: (json['senderId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
