import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/models/chat_message_model.dart';
import 'package:flutter_app/domain/repositories/chat_repository.dart';
import 'package:flutter_app/presentation/bloc/chat/chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository chatRepository;
  final WebSocketService webSocketService;
  final String serviceRequestId;
  final String currentUserId;

  ChatCubit({
    required this.chatRepository,
    required this.webSocketService,
    required this.serviceRequestId,
    required this.currentUserId,
  }) : super(const ChatInitial());

  Future<void> loadMessages() async {
    emit(const ChatLoading());
    try {
      webSocketService.joinRequestRoom(serviceRequestId);
      final messages = await chatRepository.getMessages(serviceRequestId);
      emit(ChatLoaded(messages: messages));
      await chatRepository.markAsRead(serviceRequestId);
      _listenToIncoming();
    } catch (e) {
      AppLogger.error('ChatCubit: failed to load messages', e);
      emit(ChatError(e.toString()));
    }
  }

  void _listenToIncoming() {
    // Limpia el listener anterior para evitar duplicados al recargar
    webSocketService.offChatMessage();
    webSocketService.onChatMessage((data) {
      if (data['serviceRequestId'] != serviceRequestId) return;
      final incoming = ChatMessageModel.fromSocketData(data);
      final current = state;
      if (current is ChatLoaded) {
        // Evita duplicar un mensaje que ya existe en la lista
        final alreadyExists = current.messages.any((m) => m.id == incoming.id);
        if (alreadyExists) return;
        final updated = List.of(current.messages)..add(incoming);
        emit(current.copyWith(messages: updated));
      }
    });
  }

  Future<void> sendMessage(String content) async {
    final current = state;
    if (current is! ChatLoaded) return;
    emit(current.copyWith(sending: true));
    try {
      // Envía siempre via HTTP para garantizar persistencia en el tenant correcto.
      // El backend emite el evento WebSocket después de guardar, por lo que el
      // mensaje llegará a través de _listenToIncoming para todos los participantes.
      await chatRepository.sendMessage(serviceRequestId, content);
      emit(current.copyWith(sending: false));
    } catch (e) {
      AppLogger.error('ChatCubit: failed to send message', e);
      emit(current.copyWith(sending: false));
    }
  }

  @override
  Future<void> close() {
    webSocketService.offChatMessage();
    return super.close();
  }
}
