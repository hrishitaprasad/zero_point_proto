import 'package:flutter/widgets.dart';

class AppLifecycleNative extends ChangeNotifier {
  AppLifecycleNative._();
  static final AppLifecycleNative instance = AppLifecycleNative._();

  AppLifecycleState _state = AppLifecycleState.resumed;

  AppLifecycleState get state => _state;

  void update(AppLifecycleState state) {
    _state = state;
    notifyListeners();
  }
}