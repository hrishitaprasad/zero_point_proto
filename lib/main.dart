import 'package:flutter/material.dart';
import 'core/app_lifecycle_native.dart';
import 'core/session_timer_notifier.dart';
import 'features/calculator/calculator_screen.dart';
import 'features/home/dashboard_screen.dart';
import 'features/identity/identity_setup_screen.dart';
import 'services/identity_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionTimerNotifier.instance.initialize();
  runApp(const ZeroPointApp());
}

class ZeroPointApp extends StatefulWidget {
  const ZeroPointApp({super.key});

  @override
  State<ZeroPointApp> createState() => _ZeroPointAppState();
}

class _ZeroPointAppState extends State<ZeroPointApp> {
  final _identity = IdentityService.instance;
  final _session = SessionTimerNotifier.instance;
  bool _calculatorVisible = false;
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();

    _listener = AppLifecycleListener(
      onResume: () async {
        AppLifecycleNative.instance.update(AppLifecycleState.resumed);
        await _session.refresh();

        final hasIdentity = await _identity.hasValidIdentity();
        if (!hasIdentity || !_session.isAlive || _calculatorVisible) return;

        final nav = appNavigatorKey.currentState;
        if (nav == null) return;

        _calculatorVisible = true;
        await nav.push(
          MaterialPageRoute(
            builder: (_) => const CalculatorScreen(),
            fullscreenDialog: true,
          ),
        );
        _calculatorVisible = false;
      },
      onPause: () {
        AppLifecycleNative.instance.update(AppLifecycleState.paused);
      },
      onInactive: () {
        AppLifecycleNative.instance.update(AppLifecycleState.inactive);
      },
      onDetach: () {
        AppLifecycleNative.instance.update(AppLifecycleState.detached);
      },
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  ThemeData _theme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.greenAccent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D0D),
        elevation: 0,
      ),
      fontFamily: 'monospace',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ZeroPoint',
      theme: _theme(),
      home: FutureBuilder<bool>(
        future: _identity.hasValidIdentity(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!
              ? const DashboardScreen()
              : const IdentitySetupScreen();
        },
      ),
    );
  }
}
