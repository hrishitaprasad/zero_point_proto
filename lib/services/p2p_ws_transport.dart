import 'dart:async';
import 'dart:convert';
import 'dart:io';

class P2PWsTransport {
  WebSocket? _socket;
  final _incomingController = StreamController<String>.broadcast();

  Stream<String> get incoming => _incomingController.stream;

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  // Primary connection method (dynamic IP connection)
  Future<bool> connectToServer(String ip, {int port = 4040}) async {
    return await _connectInternal('ws://$ip:$port');
  }

  // Core connection logic
  Future<bool> _connectInternal(String url) async {
    try {
      _socket = await WebSocket.connect(url);

      _socket!.listen(
        (data) {
          print("Incoming: $data");
          _incomingController.add(data.toString());
        },
        onDone: () {
          print("Disconnected");
          _socket = null;
        },
        onError: (e) {
          print("Error: $e");
          _socket = null;
        },
        cancelOnError: true,
      );

      print("Connected to $url");
      return true;
    } catch (e) {
      print("Connection failed: $e");
      _socket = null;
      return false;
    }
  }

  //FIXED send method
  void send(String message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(message);
    } else {
      print("Send failed: not connected");
    }
  }

  // Pack encrypted message
  String pack(String encryptedBase64) {
    return jsonEncode({
      "type": "msg",
      "payload": encryptedBase64,
    });
  }

  // Unpack received message
  String? unpackPayload(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is Map<String, dynamic> && obj["type"] == "msg") {
        return obj["payload"] as String?;
      }
    } catch (_) {}
    return null;
  }

  // Cleanup
  Future<void> dispose() async {
    await _socket?.close();
    _socket = null;
    await _incomingController.close();
  }
}
