import 'package:equatable/equatable.dart';
import 'package:flutter_app/domain/entities/chat_message.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool sending;

  const ChatLoaded({required this.messages, this.sending = false});

  ChatLoaded copyWith({List<ChatMessage>? messages, bool? sending}) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
    );
  }

  @override
  List<Object?> get props => [messages, sending];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);
  @override
  List<Object?> get props => [message];
}
