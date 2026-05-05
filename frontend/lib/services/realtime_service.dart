import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

class RealtimeService {
  WebSocketChannel? _channel;

  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  bool _connected = false;

  void connect(
    void Function(Map<String, dynamic>) onUpdate, {
    void Function(bool connected)? onStatusChanged,
  }) {
    _shouldReconnect = true;
    disconnect();
    _startConnection(onUpdate, onStatusChanged: onStatusChanged);
  }

  void _startConnection(
    void Function(Map<String, dynamic>) onUpdate, {
    void Function(bool connected)? onStatusChanged,
  }) {
    if (!_shouldReconnect) {
      return;
    }

    final baseUri = Uri.parse(AppConfig.baseUrl);
    final wsUri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/updates',
    );

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _connected = true;
      onStatusChanged?.call(true);
      _subscription = _channel!.stream.listen(
      (message) {
        _connected = true;
        onStatusChanged?.call(true);
        try {
          if (message is String) {
            onUpdate(jsonDecode(message) as Map<String, dynamic>);
            return;
          }
          if (message is Map<String, dynamic>) {
            onUpdate(message);
            return;
          }
        } catch (_) {}
        onUpdate({'type': 'update'});
      },
      onDone: () {
        _connected = false;
        onStatusChanged?.call(false);
        _scheduleReconnect(onUpdate);
      },
      onError: (_) {
        _connected = false;
        onStatusChanged?.call(false);
        _scheduleReconnect(onUpdate);
      },
      cancelOnError: true,
    );
    } catch (_) {
      _connected = false;
      onStatusChanged?.call(false);
      _scheduleReconnect(onUpdate);
    }
  }

  void _scheduleReconnect(void Function(Map<String, dynamic>) onUpdate) {
    if (!_shouldReconnect) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _startConnection(onUpdate);
    });
  }

  bool get isConnected => _connected;

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
  }
}