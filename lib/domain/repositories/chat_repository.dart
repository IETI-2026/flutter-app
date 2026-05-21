import 'package:flutter_app/domain/entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String serviceRequestId);
  Future<ChatMessage> sendMessage(String serviceRequestId, String content);
  Future<void> markAsRead(String serviceRequestId);
}
