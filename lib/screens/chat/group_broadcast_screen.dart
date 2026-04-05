import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/e2ee_service.dart';
import '../../services/p2p_ws_transport.dart';
import 'qr_scanner_screen.dart';

class BroadcastPeer {
  final String id;
  final String name;
  final String userId;
  final String publicKey;

  BroadcastPeer({
    required this.id,
    required this.name,
    required this.userId,
    required this.publicKey,
  });
}

class SentRecipientStatus {
  final String userId;
  final String name;
  String state;

  SentRecipientStatus({
    required this.userId,
    required this.name,
    this.state = "Sent",
  });
}

class SentBroadcastItem {
  final String baseMessageId;
  final String text;
  final int expiresAtMs;
  final List<SentRecipientStatus> recipients;

  SentBroadcastItem({
    required this.baseMessageId,
    required this.text,
    required this.expiresAtMs,
    required this.recipients,
  });
}

class ReceivedBroadcastItem {
  final String messageId;
  final String fromUserId;
  final String text;
  final int expiresAtMs;

  ReceivedBroadcastItem({
    required this.messageId,
    required this.fromUserId,
    required this.text,
    required this.expiresAtMs,
  });
}

class GroupBroadcastScreen extends StatefulWidget {
  const GroupBroadcastScreen({super.key});

  @override
  State<GroupBroadcastScreen> createState() => _GroupBroadcastScreenState();
}

class _GroupBroadcastScreenState extends State<GroupBroadcastScreen> {
  final _myUserIdController = TextEditingController();
  final _relayIpController = TextEditingController(text: "10.0.2.2");
  final _messageController = TextEditingController();
  final _inviteController = TextEditingController();

  final _recipientNameController = TextEditingController();
  final _recipientUserIdController = TextEditingController();
  final _recipientKeyController = TextEditingController();

  final _transport = P2PWsTransport();
  final _crypto = E2EEService();

  final List<BroadcastPeer> _recipients = [];
  final List<SentBroadcastItem> _sentBroadcasts = [];
  final List<ReceivedBroadcastItem> _receivedMessages = [];

  final List<int> _ttlOptions = [10, 30, 60, 120];
  int _selectedTtl = 30;

  String _status = "Not connected";
  String _myPublicKey = "Generating...";
  String _myInviteCode = "";

  bool _connected = false;
  bool _registered = false;
  bool _keysReady = false;

  Timer? _ticker;
  int _recipientCounter = 0;
  int _messageCounter = 0;

  @override
  void initState() {
    super.initState();
    _initCrypto();
  }

  Future<void> _initCrypto() async {
    await _crypto.generateKeyPair();

    if (!mounted) return;
    setState(() {
      _myPublicKey = _crypto.exportMyPublicKeyBase64();
      _keysReady = true;
    });

    _transport.incoming.listen(_handleIncoming);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _cleanupExpired();
      setState(() {});
    });
  }

  void _cleanupExpired() {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    _sentBroadcasts.removeWhere((m) => nowMs >= m.expiresAtMs + 2000);
    _receivedMessages.removeWhere((m) => nowMs >= m.expiresAtMs + 2000);
  }

  int _remainingSeconds(int expiresAtMs) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final leftMs = expiresAtMs - nowMs;
    if (leftMs <= 0) return 0;
    return ((leftMs + 999) ~/ 1000);
  }

  Future<void> _connectRelay() async {
    final ip = _relayIpController.text.trim();
    final userId = _myUserIdController.text.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter My User ID")),
      );
      return;
    }

    final ok = await _transport.connectToServer(ip);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _connected = false;
        _registered = false;
        _status = "Connection failed";
      });
      return;
    }

    _transport.send(jsonEncode({
      "type": "register",
      "userId": userId,
    }));

    setState(() {
      _connected = true;
      _status = "Connected to relay";
    });
  }

  Future<void> _handleIncoming(String raw) async {
    try {
      final obj = jsonDecode(raw);

      if (obj is! Map<String, dynamic>) return;

      if (obj["type"] == "register_ok") {
        if (!mounted) return;
        setState(() {
          _registered = true;
          _status = "Registered as ${obj["userId"]}";
        });
        return;
      }

      if (obj["type"] == "ack") {
        final messageId = obj["messageId"]?.toString();
        final targetUserId = obj["targetUserId"]?.toString();

        if (messageId == null || targetUserId == null) return;

        final baseId = messageId.split("|").first;

        for (final msg in _sentBroadcasts) {
          if (msg.baseMessageId == baseId) {
            for (final recipient in msg.recipients) {
              if (recipient.userId == targetUserId) {
                recipient.state = "Delivered";
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {});
        return;
      }

      if (obj["type"] != "group_msg") return;

      final myUserId = _myUserIdController.text.trim();
      final to = obj["to"]?.toString();
      if (to == null || to != myUserId) return;

      final fromUserId = obj["from"]?.toString();
      final senderPublicKey = obj["senderPublicKey"]?.toString();
      final payload = obj["payload"]?.toString();
      final messageId = obj["messageId"]?.toString();

      if (fromUserId == null ||
          senderPublicKey == null ||
          payload == null ||
          messageId == null) {
        return;
      }

      await _crypto.setPeerPublicKeyBase64(senderPublicKey);

      final decryptedJson = await _crypto.decrypt(payload);
      final map = jsonDecode(decryptedJson) as Map<String, dynamic>;

      final text = map["text"]?.toString() ?? "";
      final expiresAtMs = map["expiresAtMs"] is int
          ? map["expiresAtMs"] as int
          : int.tryParse(map["expiresAtMs"].toString()) ?? 0;

      if (expiresAtMs <= DateTime.now().toUtc().millisecondsSinceEpoch) {
        return;
      }

      final alreadyExists =
          _receivedMessages.any((m) => m.messageId == messageId);
      if (alreadyExists) return;

      if (!mounted) return;
      setState(() {
        _receivedMessages.insert(
          0,
          ReceivedBroadcastItem(
            messageId: messageId,
            fromUserId: fromUserId,
            text: text,
            expiresAtMs: expiresAtMs,
          ),
        );
      });
    } catch (_) {}
  }

  void _generateInvite() {
    final userId = _myUserIdController.text.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter My User ID first")),
      );
      return;
    }

    final code = "$userId|$_myPublicKey";

    setState(() {
      _myInviteCode = code;
    });
  }

  void _joinInviteCode(String invite) {
    final code = invite.trim();

    if (!code.contains("|")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid invite code")),
      );
      return;
    }

    final firstSep = code.indexOf("|");
    final userId = code.substring(0, firstSep).trim();
    final key = code.substring(firstSep + 1).trim();

    if (userId.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid invite format")),
      );
      return;
    }

    final alreadyExists = _recipients.any((r) => r.userId == userId);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$userId already added")),
      );
      return;
    }

    setState(() {
      _recipientCounter++;
      _recipients.add(
        BroadcastPeer(
          id: "r$_recipientCounter",
          name: userId,
          userId: userId,
          publicKey: key,
        ),
      );
      _inviteController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added recipient $userId")),
    );
  }

  void _addRecipientManual() {
    final name = _recipientNameController.text.trim();
    final userId = _recipientUserIdController.text.trim();
    final key = _recipientKeyController.text.trim();

    if (name.isEmpty || userId.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all recipient fields")),
      );
      return;
    }

    setState(() {
      _recipientCounter++;
      _recipients.add(
        BroadcastPeer(
          id: "r$_recipientCounter",
          name: name,
          userId: userId,
          publicKey: key,
        ),
      );
      _recipientNameController.clear();
      _recipientUserIdController.clear();
      _recipientKeyController.clear();
    });
  }

  void _removeRecipient(String id) {
    setState(() {
      _recipients.removeWhere((r) => r.id == id);
    });
  }

  Future<void> _sendBroadcast() async {
    final myUserId = _myUserIdController.text.trim();
    final text = _messageController.text.trim();

    if (!_connected || !_registered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connect relay first")),
      );
      return;
    }

    if (!_keysReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Keys not ready yet")),
      );
      return;
    }

    if (myUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter My User ID")),
      );
      return;
    }

    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one recipient")),
      );
      return;
    }

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Type a message first")),
      );
      return;
    }

    _messageCounter++;
    final baseId = "grp_$_messageCounter";
    final expiresAtMs = DateTime.now()
        .toUtc()
        .add(Duration(seconds: _selectedTtl))
        .millisecondsSinceEpoch;

    final item = SentBroadcastItem(
      baseMessageId: baseId,
      text: text,
      expiresAtMs: expiresAtMs,
      recipients: _recipients
          .map(
            (r) => SentRecipientStatus(
              userId: r.userId,
              name: r.name,
              state: "Sent",
            ),
          )
          .toList(),
    );

    setState(() {
      _sentBroadcasts.insert(0, item);
      _messageController.clear();
    });

    for (final recipient in _recipients) {
      await _crypto.setPeerPublicKeyBase64(recipient.publicKey);

      final encrypted = await _crypto.encrypt(jsonEncode({
        "text": text,
        "expiresAtMs": expiresAtMs,
      }));

      final packetMessageId = "$baseId|${recipient.userId}";

      _transport.send(jsonEncode({
        "type": "group_msg",
        "messageId": packetMessageId,
        "from": myUserId,
        "to": recipient.userId,
        "senderPublicKey": _myPublicKey,
        "payload": encrypted,
      }));
    }
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$label copied")),
    );
  }

  Future<void> _showMyQrDialog() async {
    if (_myInviteCode.isEmpty) {
      _generateInvite();
    }

    if (_myInviteCode.isEmpty) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("My Invite QR"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              QrImageView(
                data: _myInviteCode,
                version: QrVersions.auto,
                size: 220,
              ),
              const SizedBox(height: 16),
              SelectableText(_myInviteCode),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyText("Invite", _myInviteCode),
            child: const Text("Copy Invite"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          onScanned: (code) {
            _joinInviteCode(code);
          },
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _quickMessages() {
    const items = [
      "Hello team 👋",
      "നമസ്കാരം ടീം",
      "नमस्ते टीम",
      "வணக்கம் குழு",
      "ನಮಸ್ಕಾರ ತಂಡ",
      "مرحبا بالفريق",
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((m) {
        return ActionChip(
          label: Text(m),
          onPressed: () {
            _messageController.text = m;
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  Widget _liveDemoStatusCard() {
    final latestSent =
        _sentBroadcasts.isNotEmpty ? _sentBroadcasts.first.text : null;
    final latestReceived =
        _receivedMessages.isNotEmpty ? _receivedMessages.first : null;

    return _section("Live Demo Status", [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip("Recipients: ${_recipients.length}"),
          _chip("Received: ${_receivedMessages.length}"),
          _chip(_registered ? "Broadcast Active" : "Not Ready"),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          latestSent == null
              ? "No sent broadcast yet"
              : "Latest Sent: $latestSent",
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: latestReceived == null
            ? const Text("No received message yet")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Latest Received: ${latestReceived.text}"),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip("From ${latestReceived.fromUserId}"),
                      _chip(
                        "TTL ${_remainingSeconds(latestReceived.expiresAtMs)}s",
                      ),
                      _chip("Decrypted"),
                    ],
                  ),
                ],
              ),
      ),
    ]);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _myUserIdController.dispose();
    _relayIpController.dispose();
    _messageController.dispose();
    _inviteController.dispose();
    _recipientNameController.dispose();
    _recipientUserIdController.dispose();
    _recipientKeyController.dispose();
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("One-to-Many Secure Chat"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _section("Connection", [
                TextField(
                  controller: _myUserIdController,
                  decoration: const InputDecoration(
                    labelText: "My User ID",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _relayIpController,
                  decoration: const InputDecoration(
                    labelText: "Relay IP",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _connectRelay,
                    child: const Text("Connect Relay"),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(_connected ? "Connected" : "Offline"),
                    _chip(_registered ? "Registered" : "Not Registered"),
                    _chip(_status),
                  ],
                ),
              ]),
              const SizedBox(height: 16),
              _section("My Public Key", [
                SelectableText(_myPublicKey),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _copyText("Public key", _myPublicKey),
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy"),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _section("Invite QR / Join Invite", [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _generateInvite,
                    child: const Text("Generate Invite"),
                  ),
                ),
                const SizedBox(height: 10),
                if (_myInviteCode.isNotEmpty) SelectableText(_myInviteCode),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _myInviteCode.isEmpty ? null : _showMyQrDialog,
                        icon: const Icon(Icons.qr_code),
                        label: const Text("Show QR"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text("Scan QR"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inviteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Paste Invite Code",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinInviteCode(_inviteController.text),
                    child: const Text("Join Invite"),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _section("Add Recipients (Manual Fallback)", [
                TextField(
                  controller: _recipientNameController,
                  decoration: const InputDecoration(
                    labelText: "Recipient Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipientUserIdController,
                  decoration: const InputDecoration(
                    labelText: "Recipient User ID",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipientKeyController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Recipient Public Key",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addRecipientManual,
                    child: const Text("Add Recipient"),
                  ),
                ),
                const SizedBox(height: 12),
                if (_recipients.isEmpty)
                  const Text("No recipients added")
                else
                  ..._recipients.map((r) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(r.name),
                        subtitle: Text(r.userId),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeRecipient(r.id),
                        ),
                      ),
                    );
                  }),
              ]),
              const SizedBox(height: 16),
              _section("Compose Broadcast", [
                _quickMessages(),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: "Type one broadcast message...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("TTL"),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: _selectedTtl,
                      items: _ttlOptions
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text("${s}s"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedTtl = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendBroadcast,
                    icon: const Icon(Icons.send),
                    label: const Text("Send Broadcast"),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _liveDemoStatusCard(),
              const SizedBox(height: 16),
              _section("Sent Broadcasts", [
                if (_sentBroadcasts.isEmpty)
                  const Text("No sent broadcasts yet")
                else
                  ..._sentBroadcasts.map((msg) {
                    final ttl = _remainingSeconds(msg.expiresAtMs);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip("${msg.recipients.length} recipients"),
                                _chip(ttl > 0 ? "TTL ${ttl}s" : "Expired"),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...msg.recipients.map((r) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip(r.name),
                                    _chip(r.userId),
                                    _chip(r.state),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
