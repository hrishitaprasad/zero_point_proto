import 'package:flutter/material.dart';

import '../../core/session_timer_notifier.dart';
import '../../services/identity_service.dart';
import '../chat/e2ee_chat_screen.dart';
import '../chat/e2ee_test_screen.dart';
import '../chat/group_broadcast_screen.dart';
import '../chat/chat_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../features/calculator/calculator_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final identity = IdentityService();
  final session = SessionTimerNotifier.instance;

  String alias = 'Loading...';
  String secretCodeMask = '••••';

  @override
  void initState() {
    super.initState();
    _load();
    session.initialize();
  }

  Future<void> _load() async {
    final a = await identity.getAlias();
    final secret = await identity.getSecretCode();

    if (!mounted) return;
    setState(() {
      alias = a;
      secretCodeMask = secret == null ? 'Not set' : ('•' * secret.length);
    });
  }

  String _fmt(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  Future<void> _flushNow() async {
    await identity.flushIdentity();
    session.stop();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  Widget _actionButton(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(title),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZeroPoint Dashboard'),
        actions: [
          IconButton(
            onPressed: _flushNow,
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Flush Identity',
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              alias,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text('Ephemeral identity active'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  'Session Timer',
                                  _fmt(session.remainingSeconds),
                                  Icons.timer_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _infoCard(
                                  'Secret Code',
                                  secretCodeMask,
                                  Icons.pin_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _actionButton(
                    'Open Secure Chat',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const E2EEChatScreen()),
                    ),
                  ),
                  _actionButton(
                    'One-to-Many Secure Chat',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupBroadcastScreen(),
                      ),
                    ),
                  ),
                  _actionButton(
                    'Test Real E2EE',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const E2EETestScreen()),
                    ),
                  ),
                  _actionButton(
                    'Open AES Demo Chat',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                  ),
                  _actionButton(
                    'Open Calculator Mask',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}