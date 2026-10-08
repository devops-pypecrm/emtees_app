import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/secure_storage.dart';

/// Lightweight event bus for realtime events the UI can subscribe to.
class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;
  RealtimeEvent(this.type, this.payload);
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final service = SocketService(storage);
  ref.onDispose(service.disconnect);
  return service;
});

/// Stream of realtime events (class started/ended/updated, incoming 1:1 calls).
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.events;
});

class SocketService {
  SocketService(this._storage);

  final SecureStorageService _storage;
  io.Socket? _socket;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> connect() async {
    final token = await _storage.readToken();
    if (token == null) return;
    disconnect();
    final socket = io.io(
      AppConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {});
    socket.on('class:started', (data) => _emit('class:started', data));
    socket.on('class:ended', (data) => _emit('class:ended', data));
    socket.on('class:updated', (data) => _emit('class:updated', data));
    socket.on(
        '1to1:incoming_call', (data) => _emit('1to1:incoming_call', data));
    socket.on('private_message:new',
        (data) => _emit('private_message:new', data));

    socket.connect();
  }

  void _emit(String type, dynamic data) {
    final payload = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    _controller.add(RealtimeEvent(type, payload));
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
