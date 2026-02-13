import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../screens/no_internet_screen.dart';

class NetworkManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const NetworkManager({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<NetworkManager> createState() => _NetworkManagerState();
}

class _NetworkManagerState extends State<NetworkManager> with WidgetsBindingObserver {
  final InternetConnection _internetConnection = InternetConnection();
  StreamSubscription<InternetStatus>? _internetSubscription;
  bool _isNoInternetScreenShown = false;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _internetSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isAppInForeground) {
          _validateConnection();
        }
      });
    } else {
      _isAppInForeground = false;
    }
  }

  void _startMonitoring() {
    _internetSubscription = _internetConnection.onStatusChange.listen((status) {
      if (!_isAppInForeground) return;

      if (status == InternetStatus.disconnected) {
        _handleDisconnection();
      } else {
        _removeNoInternetScreen();
      }
    });
  }

  Future<void> _handleDisconnection() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted || !_isAppInForeground) return;

    bool hasInternet = await _internetConnection.hasInternetAccess;
    if (!hasInternet) {
      _showNoInternetScreen();
    }
  }

  Future<void> _validateConnection() async {
    bool hasInternet = await _internetConnection.hasInternetAccess;
    if (mounted) {
      if (hasInternet) {
        _removeNoInternetScreen();
      } else if (_isAppInForeground) {
        _showNoInternetScreen();
      }
    }
  }

  void _showNoInternetScreen() {
    if (_isNoInternetScreenShown || !_isAppInForeground) return;

    _isNoInternetScreenShown = true;
    widget.navigatorKey.currentState?.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoInternetScreen(onRetry: _validateConnection),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      _isNoInternetScreenShown = false;
    });
  }

  void _removeNoInternetScreen() {
    if (_isNoInternetScreenShown && widget.navigatorKey.currentState != null) {
      widget.navigatorKey.currentState!.popUntil((route) {
        if (route.settings.name == null && _isNoInternetScreenShown) {
          return false;
        }
        return true;
      });
      _isNoInternetScreenShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}