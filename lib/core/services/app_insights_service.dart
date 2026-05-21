import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_app/core/constants/app_constants.dart';

enum SeverityLevel { verbose, information, warning, error, critical }

class AppInsightsService {
  static AppInsightsService? _instance;
  static AppInsightsService get instance {
    _instance ??= AppInsightsService._();
    return _instance!;
  }

  AppInsightsService._();

  String? _instrumentationKey;
  String? _ingestionEndpoint;
  bool _initialized = false;

  final Queue<Map<String, dynamic>> _buffer = Queue();
  Timer? _flushTimer;

  static const int _maxBufferSize = 25;
  static const Duration _flushInterval = Duration(seconds: 30);

  bool get isEnabled => _initialized && _instrumentationKey != null;

  void initialize() {
    final connectionString = AppConstants.appInsightsConnectionString;
    if (connectionString.isEmpty) return;

    final parts = connectionString.split(';');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length < 2) continue;

      final key = kv[0].trim();
      final value = kv.sublist(1).join('=').trim();

      if (key == 'InstrumentationKey') {
        _instrumentationKey = value;
      } else if (key == 'IngestionEndpoint') {
        _ingestionEndpoint = value;
      }
    }

    if (_instrumentationKey == null || _instrumentationKey!.isEmpty) return;

    _ingestionEndpoint ??= 'https://dc.services.visualstudio.com';

    _initialized = true;
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  void trackTrace(
    String message,
    SeverityLevel severity, [
    Map<String, String>? properties,
  ]) {
    if (!isEnabled) return;

    _enqueue(
      _buildEnvelope('AppTraces', {
        'message': message,
        'severityLevel': _mapSeverity(severity),
      }, properties: properties),
    );
  }

  void trackException(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, String>? properties,
  }) {
    if (!isEnabled) return;

    _enqueue(
      _buildEnvelope('AppExceptions', {
        'exceptions': [
          {
            'typeName': exception.runtimeType.toString(),
            'message': exception.toString(),
            'hasFullStack': stackTrace != null,
            if (stackTrace != null) 'stack': stackTrace.toString(),
          },
        ],
        'severityLevel': 3,
      }, properties: properties),
    );
  }

  void trackEvent(String name, [Map<String, String>? properties]) {
    if (!isEnabled) return;

    _enqueue(
      _buildEnvelope('AppEvents', {'name': name}, properties: properties),
    );
  }

  void trackPageView(String name, [Duration? duration]) {
    if (!isEnabled) return;

    _enqueue(
      _buildEnvelope('AppPageViews', {
        'name': name,
        if (duration != null) 'duration': _formatDuration(duration),
      }),
    );
  }

  void trackRequest(
    String name,
    String url,
    int statusCode,
    Duration duration,
    bool success,
  ) {
    if (!isEnabled) return;

    _enqueue(
      _buildEnvelope('AppRequests', {
        'id': _generateId(),
        'name': name,
        'url': url,
        'responseCode': statusCode.toString(),
        'duration': _formatDuration(duration),
        'success': success,
      }),
    );
  }

  Map<String, dynamic> _buildEnvelope(
    String name,
    Map<String, dynamic> data, {
    Map<String, String>? properties,
  }) {
    final baseType = _getBaseType(name);

    if (baseType == 'RequestData') {
      data['id'] ??= _generateId();
    }

    final envelope = {
      'name': 'Microsoft.ApplicationInsights.$name',
      'time': DateTime.now().toUtc().toIso8601String(),
      'iKey': _instrumentationKey,
      'tags': {
        'ai.cloud.role': 'cameyo-flutter-app',
        'ai.device.os': Platform.operatingSystem,
        'ai.device.osVersion': Platform.operatingSystemVersion,
      },
      'data': {
        'baseType': baseType,
        'baseData': {
          'ver': 2,
          ...data,
          if (properties != null && properties.isNotEmpty)
            'properties': properties,
        },
      },
    };

    return envelope;
  }

  String _getBaseType(String name) {
    switch (name) {
      case 'AppEvents':
        return 'EventData';
      case 'AppTraces':
        return 'MessageData';
      case 'AppExceptions':
        return 'ExceptionData';
      case 'AppPageViews':
        return 'PageviewData';
      case 'AppRequests':
        return 'RequestData';
      default:
        return 'EventData';
    }
  }

  int _mapSeverity(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.verbose:
        return 0;
      case SeverityLevel.information:
        return 1;
      case SeverityLevel.warning:
        return 2;
      case SeverityLevel.error:
        return 3;
      case SeverityLevel.critical:
        return 4;
    }
  }

  void _enqueue(Map<String, dynamic> envelope) {
    _buffer.add(envelope);

    if (_buffer.length >= _maxBufferSize) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_buffer.isEmpty || !isEnabled) return;

    final batch = _buffer.toList();
    _buffer.clear();

    try {
      final uri = Uri.parse('$_ingestionEndpoint/v2/track');
      final client = HttpClient();
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/x-json-stream');

      final body = batch.map((e) => jsonEncode(e)).join('\n');
      request.write(body);

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      await response.transform(utf8.decoder).join();

      client.close(force: false);
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  String _generateId() {
    final rand = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '$timestamp-${rand.nextInt(999999)}';
  }

  void dispose() {
    _flushTimer?.cancel();
    flush();
  }
}
