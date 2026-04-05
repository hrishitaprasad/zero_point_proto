import 'package:flutter/material.dart';
import '../../services/e2ee_service.dart';

class E2EETestScreen extends StatefulWidget {
  const E2EETestScreen({super.key});

  @override
  State<E2EETestScreen> createState() => _E2EETestScreenState();
}

class _E2EETestScreenState extends State<E2EETestScreen> {
  final userA = E2EEService();
  final userB = E2EEService();

  final _customController = TextEditingController();

  String selectedMessage = "Hello 👋";
  String encrypted = "Not tested yet";
  String decrypted = "Not tested yet";
  bool loading = false;

  final List<String> sampleMessages = const [
    "Hello 👋",
    "How are you?",
    "നമസ്കാരം, സുഖമാണോ?",
    "नमस्ते, आप कैसे हैं?",
    "வணக்கம், எப்படி இருக்கிறீர்கள்?",
    "ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಾ?",
    "Hola, ¿cómo estás?",
    "مرحبا، كيف حالك؟",
  ];

  Future<void> _runTest([String? message]) async {
    final testMessage = (message ?? _customController.text.trim()).isEmpty
        ? selectedMessage
        : (message ?? _customController.text.trim());

    setState(() {
      loading = true;
      encrypted = "Testing...";
      decrypted = "Testing...";
    });

    try {
      await userA.generateKeyPair();
      await userB.generateKeyPair();

      await userA.setPeerPublicKeyBase64(userB.exportMyPublicKeyBase64());
      await userB.setPeerPublicKeyBase64(userA.exportMyPublicKeyBase64());

      final enc = await userA.encrypt(testMessage);
      final dec = await userB.decrypt(enc);

      if (!mounted) return;
      setState(() {
        encrypted = enc;
        decrypted = dec;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        encrypted = "Error: $e";
        decrypted = "Error";
        loading = false;
      });
    }
  }

  void _setQuickMessage(String msg) {
    setState(() {
      selectedMessage = msg;
      _customController.text = msg;
    });
  }

  Widget _card(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _quickLanguageButtons() {
    final quickMessages = <Map<String, String>>[
      {"label": "English", "text": "Hello 👋"},
      {"label": "Malayalam", "text": "നമസ്കാരം, സുഖമാണോ?"},
      {"label": "Hindi", "text": "नमस्ते, आप कैसे हैं?"},
      {"label": "Tamil", "text": "வணக்கம், எப்படி இருக்கிறீர்கள்?"},
      {"label": "Kannada", "text": "ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಾ?"},
      {"label": "Spanish", "text": "Hola, ¿cómo estás?"},
      {"label": "Arabic", "text": "مرحبا، كيف حالك؟"},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickMessages.map((item) {
        return ActionChip(
          label: Text(item["label"]!),
          onPressed: () => _setQuickMessage(item["text"]!),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = _customController.text.trim().isEmpty
        ? selectedMessage
        : _customController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text("E2EE Test"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              "Quick Language Demo",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tap any language button below to auto-fill a real message.",
                  ),
                  const SizedBox(height: 12),
                  _quickLanguageButtons(),
                ],
              ),
            ),
            _card(
              "Choose Demo Message",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedMessage,
                    isExpanded: true,
                    items: sampleMessages
                        .map(
                          (msg) => DropdownMenuItem(
                            value: msg,
                            child: Text(
                              msg,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedMessage = value;
                        _customController.text = value;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Or type your own message in any language...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : _runTest,
                      child: Text(loading ? "Testing..." : "Test E2EE"),
                    ),
                  ),
                ],
              ),
            ),
            _card(
              "Original Message",
              SelectableText(original),
            ),
            _card(
              "Encrypted",
              SelectableText(encrypted),
            ),
            _card(
              "Decrypted",
              SelectableText(decrypted),
            ),
          ],
        ),
      ),
    );
  }
}
