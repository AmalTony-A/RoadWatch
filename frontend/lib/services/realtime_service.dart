import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

class RealtimeService {
  WebSocketChannel? _channel;

  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _statusDebounceTimer;
  Timer? _connectedConfirmTimer;
  bool _pendingConnected = false;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;
  bool _connected = false;

  // How long to wait before reporting a disconnected status to the UI.
  // This prevents rapid flicker when the connection briefly drops then
  // reconnects quickly.
  // Wait this long before reporting disconnected to the UI.
  static const Duration _statusDebounce = Duration(milliseconds: 5000);
  // Require this much stable time after opening before reporting connected.
  static const Duration _connectedConfirmDelay = Duration(milliseconds: 3000);

  void connect(
    void Function(Map<String, dynamic>) onUpdate, {
    void Function(bool connected)? onStatusChanged,
  }) {
    _shouldReconnect = true;
    unawaited(_closeCurrentConnection());
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
      // When a socket opens, wait briefly before reporting 'connected'.
      // This avoids showing connected for transient/failed handshakes.
      _statusDebounceTimer?.cancel();
      _pendingConnected = true;
      _connectedConfirmTimer?.cancel();
      _connectedConfirmTimer = Timer(_connectedConfirmDelay, () {
        _pendingConnected = false;
        _connected = true;
        onStatusChanged?.call(true);
      });
      // reset reconnect attempts on a successful connection start
      _reconnectAttempts = 0;
      _subscription = _channel!.stream.listen(
      (message) {
        // Ensure connected state is immediate when messages arrive.
        _statusDebounceTimer?.cancel();
        _connectedConfirmTimer?.cancel();
        _pendingConnected = false;
        if (!_connected) {
          _connected = true;
          onStatusChanged?.call(true);
        }
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
        // If we were still in the confirmation window, cancel and do not
        // report a transient connected state.
        if (_pendingConnected) {
          _connectedConfirmTimer?.cancel();
          _pendingConnected = false;
        }
        // Debounce reporting of disconnected status to avoid UI flicker.
        _statusDebounceTimer?.cancel();
        _statusDebounceTimer = Timer(_statusDebounce, () {
          _connected = false;
          onStatusChanged?.call(false);
        });
        _scheduleReconnect(onUpdate, onStatusChanged: onStatusChanged);
      },
      onError: (_) {
        if (_pendingConnected) {
          _connectedConfirmTimer?.cancel();
          _pendingConnected = false;
        }
        _statusDebounceTimer?.cancel();
        _statusDebounceTimer = Timer(_statusDebounce, () {
          _connected = false;
          onStatusChanged?.call(false);
        });
        _scheduleReconnect(onUpdate, onStatusChanged: onStatusChanged);
      },
      cancelOnError: true,
    );
    } catch (_) {
      // If initial connection fails, debounce the disconnected status
      // as well so the UI doesn't flash.
      _connectedConfirmTimer?.cancel();
      _pendingConnected = false;
      _statusDebounceTimer?.cancel();
      _statusDebounceTimer = Timer(_statusDebounce, () {
        _connected = false;
        onStatusChanged?.call(false);
      });
      _scheduleReconnect(onUpdate, onStatusChanged: onStatusChanged);
    }
  }

  void _scheduleReconnect(
    void Function(Map<String, dynamic>) onUpdate, {
    void Function(bool connected)? onStatusChanged,
  }) {
    if (!_shouldReconnect) {
      return;
    }
    _reconnectTimer?.cancel();
    // Exponential backoff with cap and jitter
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 6);
    final baseSeconds = pow(2, _reconnectAttempts).toInt();
    final delaySeconds = min(30, baseSeconds);
    final jitterMs = Random().nextInt(800);
    final delay = Duration(seconds: delaySeconds, milliseconds: jitterMs);
    _reconnectTimer = Timer(delay, () {
      _startConnection(onUpdate, onStatusChanged: onStatusChanged);
    });
  }

  bool get isConnected => _connected;

  Future<void> disconnect() async {
    _shouldReconnect = false;
    await _closeCurrentConnection();
  }

  Future<void> _closeCurrentConnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _statusDebounceTimer?.cancel();
    _statusDebounceTimer = null;
    _connectedConfirmTimer?.cancel();
    _connectedConfirmTimer = null;
    _reconnectAttempts = 0;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _connected = false;
    await subscription?.cancel();
    await channel?.sink.close();
  }
}
