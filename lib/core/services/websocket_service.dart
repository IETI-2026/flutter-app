import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebSocketService {
  io.Socket? _socket;

  String? _pendingTechnicianId;
  String? _pendingTenantId;

  String get _wsBaseUrl {
    const url = AppConstants.baseUrl;
    if (url.endsWith('/api')) {
      return url.substring(0, url.length - 4);
    }
    return url;
  }

  void connect({String? technicianId, String? tenantId}) {
    if (technicianId != null) _pendingTechnicianId = technicianId;
    if (tenantId != null) _pendingTenantId = tenantId;

    if (_socket != null && _socket!.connected) {
      // Already connected — join room immediately if credentials are new
      if (_pendingTechnicianId != null && _pendingTenantId != null) {
        _emitJoinTechnicianRoom();
      }
      return;
    }

    _socket = io.io(
      _wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      AppLogger.info('WebSocket connected');
      if (_pendingTechnicianId != null && _pendingTenantId != null) {
        _emitJoinTechnicianRoom();
      }
    });

    _socket!.onReconnect((_) {
      AppLogger.info('WebSocket reconnected');
      if (_pendingTechnicianId != null && _pendingTenantId != null) {
        _emitJoinTechnicianRoom();
      }
    });

    _socket!.onDisconnect((_) {
      AppLogger.info('WebSocket disconnected');
    });

    _socket!.onError((data) {
      AppLogger.error('WebSocket error: $data');
    });

    _socket!.connect();
  }

  void _emitJoinTechnicianRoom() {
    _socket?.emit('join_technician_room', {
      'technicianId': _pendingTechnicianId,
      'tenantId': _pendingTenantId,
    });
    AppLogger.info(
      'WebSocket joined technician room: tenant=$_pendingTenantId',
    );
  }

  void disconnect() {
    _pendingTechnicianId = null;
    _pendingTenantId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinTechnicianRoom(String technicianId, String tenantId) {
    _pendingTechnicianId = technicianId;
    _pendingTenantId = tenantId;
    if (_socket?.connected == true) {
      _emitJoinTechnicianRoom();
    }
  }

  void joinRequestRoom(String requestId) {
    _socket?.emit('join_request_room', {
      'requestId': requestId,
    });
  }

  void onNewServiceRequest(void Function(Map<String, dynamic>) handler) {
    _socket?.on('new_service_request', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      } else if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void offNewServiceRequest() {
    _socket?.off('new_service_request');
  }

  void onTechnicianAccepted(void Function(Map<String, dynamic>) handler) {
    _socket?.on('technician_accepted', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      } else if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void offTechnicianAccepted() {
    _socket?.off('technician_accepted');
  }

  bool get isConnected => _socket?.connected ?? false;
}
