import 'package:flutter/material.dart';

import '../../core/session_timer_notifier.dart';
import '../../services/identity_service.dart';
import '../../screens/chat/e2ee_chat_screen.dart';
import '../../screens/chat/e2ee_test_screen.dart';
import '../../screens/chat/group_broadcast_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../calculator/calculator_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final identity = IdentityService.instance;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('ZeroPoint Dashboard'),
        actions: [
          IconButton(
            onPressed: _flushNow,
            icon: const Icon(Icons.delete_forever),
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
                  // 🔥 Identity Card
                  Card(
                    elevation: 0,
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFF334155),
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(
                              alias,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'Ephemeral identity active',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  'Session Timer',
                                  _fmt(session.remainingSeconds),
                                  Icons.timer_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _infoCard(
                                  'Secret Code',
                                  secretCodeMask,
                                  Icons.lock_outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🔥 Actions
                  _actionButton(
                    'Open Secure Chat',
                    Icons.lock_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const E2EEChatScreen()),
                    ),
                  ),
                  _actionButton(
                    'One-to-Many Secure Chat',
                    Icons.groups,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GroupBroadcastScreen()),
                    ),
                  ),
                  _actionButton(
                    'Test Real E2EE',
                    Icons.science_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const E2EETestScreen()),
                    ),
                  ),
                  _actionButton(
                    'Open AES Demo Chat',
                    Icons.chat_bubble_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                  ),
                  _actionButton(
                    'Open Calculator Mask',
                    Icons.calculate_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CalculatorScreen()),
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

  // 🔥 Clean Action Button
  Widget _actionButton(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 15)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 Info Cards
  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
