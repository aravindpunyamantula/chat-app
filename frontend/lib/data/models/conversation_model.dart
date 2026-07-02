import 'user_model.dart';
import 'message_model.dart';

class ConversationModel {
  final String id;
  final List<UserModel> participants;
  final bool isGroup;
  final bool isBonded;
  final String groupName;
  final UserModel? groupAdmin;
  final MessageModel? lastMessage;
  final DateTime updatedAt;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.isGroup,
    this.isBonded = false,
    required this.groupName,
    this.groupAdmin,
    this.lastMessage,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    var participantsList = (json['participants'] as List?) ?? [];
    List<UserModel> parsedParticipants = participantsList
        .whereType<Map<String, dynamic>>()
        .map((p) => UserModel.fromJson(p))
        .toList();

    return ConversationModel(
      id: json['_id'] ?? json['id'] ?? '',
      participants: parsedParticipants,
      isGroup: json['isGroup'] ?? false,
      isBonded: json['isBonded'] ?? false,
      groupName: json['groupName'] ?? '',
      groupAdmin: json['groupAdmin'] != null && json['groupAdmin'] is Map
          ? UserModel.fromJson(json['groupAdmin'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] != null && json['lastMessage'] is Map
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participants.map((p) => p.toJson()).toList(),
      'isGroup': isGroup,
      'isBonded': isBonded,
      'groupName': groupName,
      'groupAdmin': groupAdmin?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
