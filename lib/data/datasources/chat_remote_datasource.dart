import 'package:dio/dio.dart';
import 'package:flutter_app/data/models/chat_message_model.dart';

class ChatRemoteDataSource {
  final Dio dio;

  ChatRemoteDataSource({required this.dio});

  Future<List<ChatMessageModel>> getMessages(String serviceRequestId) async {
    final response = await dio.get('/chat/$serviceRequestId/messages');
    final data = response.data;
    List<dynamic> list;
    if (data is Map && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else if (data is List) {
      list = data;
    } else {
      return [];
    }
    return list
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageModel> sendMessage(
    String serviceRequestId,
    String content,
  ) async {
    final response = await dio.post(
      '/chat/$serviceRequestId/messages',
      data: {'content': content},
    );
    final data = response.data;
    final json = data is Map && data['data'] != null
        ? data['data'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return ChatMessageModel.fromJson(json);
  }

  Future<void> markAsRead(String serviceRequestId) async {
    await dio.patch('/chat/$serviceRequestId/messages/read');
  }
}
