import 'package:flutter_app/data/datasources/chat_remote_datasource.dart';
import 'package:flutter_app/domain/entities/chat_message.dart';
import 'package:flutter_app/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ChatMessage>> getMessages(String serviceRequestId) {
    return remoteDataSource.getMessages(serviceRequestId);
  }

  @override
  Future<ChatMessage> sendMessage(String serviceRequestId, String content) {
    return remoteDataSource.sendMessage(serviceRequestId, content);
  }

  @override
  Future<void> markAsRead(String serviceRequestId) {
    return remoteDataSource.markAsRead(serviceRequestId);
  }
}
