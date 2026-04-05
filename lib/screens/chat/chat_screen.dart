import 'package:flutter/material.dart';
import '../../services/link_safety_service.dart';

enum DemoBubbleType {
  normal,
  scanning,
  safety,
}

class DemoChatItem {
  final String id;
  final String text;
  final bool isMine;
  final DemoBubbleType type;
  final String? label;
  final int? detected;
  final int? total;
  final String? url;

  DemoChatItem({
    required this.id,
    required this.text,
    required this.isMine,
    required this.type,
    this.label,
    this.detected,
    this.total,
    this.url,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _ipController = TextEditingController(text: '10.0.2.2');
  final List<DemoChatItem> _items = [];
  int _counter = 0;

  // Dynamically create service with the current IP
  LinkSafetyService get _linkSafety => LinkSafetyService(
        baseUrl: 'http://${_ipController.text.trim()}:4040',
      );

  String _nextId() => 'msg_${++_counter}';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userMessage = DemoChatItem(
      id: _nextId(),
      text: text,
      isMine: true,
      type: DemoBubbleType.normal,
    );

    setState(() {
      _items.insert(0, userMessage);
      _messageController.clear();
    });

    final url = extractFirstUrl(text);
    if (url == null) return;

    final scanningId = _nextId();

    setState(() {
      _items.insert(
        0,
        DemoChatItem(
          id: scanningId,
          text: 'Scanning link...',
          isMine: false,
          type: DemoBubbleType.scanning,
          url: url,
        ),
      );
    });

    final result = await _linkSafety.scanUrl(url);

    if (!mounted) return;

    final index = _items.indexWhere((e) => e.id == scanningId);
    if (index == -1) return;

    if (result == null) {
      setState(() {
        _items[index] = DemoChatItem(
          id: scanningId,
          text: 'Link Safety\nScan failed',
          isMine: false,
          type: DemoBubbleType.safety,
          label: 'unknown',
          detected: 0,
          total: 0,
          url: url,
        );
      });
      return;
    }

    setState(() {
      _items[index] = DemoChatItem(
        id: scanningId,
        text: result.summary,
        isMine: false,
        type: DemoBubbleType.safety,
        label: result.label,
        detected: result.detected,
        total: result.total,
        url: result.url,
      );
    });
  }

  Color _bubbleColor(DemoChatItem item) {
    if (item.type == DemoBubbleType.normal) {
      return item.isMine ? Colors.blueGrey.shade700 : Colors.grey.shade800;
    }

    if (item.type == DemoBubbleType.scanning) {
      return Colors.orange.shade700;
    }

    switch (item.label) {
      case 'safe':
        return Colors.green.shade700;
      case 'risky_but_can_try':
        return Colors.orange.shade700;
      case 'risky':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _labelText(String? label) {
    switch (label) {
      case 'safe':
        return 'Safe';
      case 'risky_but_can_try':
        return 'Risky but can try';
      case 'risky':
        return 'Risky';
      default:
        return 'Unknown';
    }
  }

  Widget _messageBubble(DemoChatItem item) {
    final align =
        item.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bubbleColor(item),
              borderRadius: BorderRadius.circular(16),
            ),
            child: item.type == DemoBubbleType.safety
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Link Safety',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if ((item.url ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.url!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _labelText(item.label),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (item.total != null && item.total! > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${item.detected}/${item.total} engines flagged it',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    item.text,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _quickSamples() {
    const samples = [
      'Check this https://example.com',
      'Open this link https://google.com',
      'Random message without link',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: samples.map((sample) {
        return ActionChip(
          label: Text(
            sample.length > 24 ? '${sample.substring(0, 24)}...' : sample,
          ),
          onPressed: () {
            _messageController.text = sample;
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AES Demo Chat + Link Checker'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _quickSamples(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _messageBubble(item);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a message or paste a URL...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}