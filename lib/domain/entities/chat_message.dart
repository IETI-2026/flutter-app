import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String serviceRequestId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime? readAt;
  final DateTime sentAt;
  final String? senderName;
  final String? senderPhotoUrl;

  const ChatMessage({
    required this.id,
    required this.serviceRequestId,
    required this.senderId,
    required this.content,
    required this.isRead,
    this.readAt,
    required this.sentAt,
    this.senderName,
    this.senderPhotoUrl,
  });

  @override
  List<Object?> get props => [id, serviceRequestId, senderId, content, isRead, sentAt];
}
