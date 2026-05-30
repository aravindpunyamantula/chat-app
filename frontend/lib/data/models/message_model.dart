import 'user_model.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final UserModel sender;
  final String content;
  final String messageType;
  final String fileUrl;
  final DateTime createdAt;
  final String status; // 'pending', 'sent', 'delivered', 'read'
  final String? tempId; // Client-side temporary ID for optimistic rendering

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.messageType,
    required this.fileUrl,
    required this.createdAt,
    this.status = 'sent',
    this.tempId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      sender: json['sender'] is Map
          ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : UserModel(
              id: json['sender'] is String ? json['sender'] as String : '',
              name: 'User',
              email: '',
              profileImage: '',
              isOnline: false,
              lastSeen: DateTime.now(),
            ),
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      fileUrl: json['fileUrl'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      status: json['status'] ?? 'sent',
      tempId: json['tempId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'sender': sender.toJson(),
      'content': content,
      'messageType': messageType,
      'fileUrl': fileUrl,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'tempId': tempId,
    };
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    UserModel? sender,
    String? content,
    String? messageType,
    String? fileUrl,
    DateTime? createdAt,
    String? status,
    String? tempId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      tempId: tempId ?? this.tempId,
    );
  }
}
