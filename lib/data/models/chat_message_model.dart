import 'package:flutter_app/domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.serviceRequestId,
    required super.senderId,
    required super.content,
    required super.isRead,
    super.readAt,
    required super.sentAt,
    super.senderName,
    super.senderPhotoUrl,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessageModel(
      id: json['id'] as String,
      serviceRequestId: json['serviceRequestId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      isRead: (json['isRead'] as bool?) ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      sentAt: DateTime.parse(json['sentAt'] as String),
      senderName: sender?['fullName'] as String?,
      senderPhotoUrl: sender?['profilePhotoUrl'] as String?,
    );
  }

  factory ChatMessageModel.fromSocketData(Map<String, dynamic> data, {String? currentSenderName}) {
    return ChatMessageModel(
      id: data['id'] as String,
      serviceRequestId: data['serviceRequestId'] as String,
      senderId: data['senderId'] as String,
      content: data['content'] as String,
      isRead: (data['isRead'] as bool?) ?? false,
      sentAt: data['sentAt'] != null
          ? DateTime.parse(data['sentAt'] as String)
          : DateTime.now(),
      senderName: currentSenderName,
    );
  }
}
