import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/app_localizations.dart';
import 'platform_init_stub.dart' if (dart.library.io) 'platform_init_io.dart' as platform_init;
import 'screens/layout_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) await platform_init.initAndroidIfNeeded();
  if (kIsWeb || !platform_init.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: surfaceColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  runApp(const AppCageApp());
}

class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });

  final Locale? locale;
  final void Function(Locale?) setLocale;

  static AppLocaleScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppLocaleScope old) =>
      locale != old.locale;
}

class AppCageApp extends StatefulWidget {
  const AppCageApp({super.key});

  @override
  State<AppCageApp> createState() => _AppCageAppState();
}

class _AppCageAppState extends State<AppCageApp> {
  Locale? _locale = const Locale('ko');

  void _setLocale(Locale? locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      locale: _locale,
      setLocale: _setLocale,
      child: MaterialApp(
        title: 'Golden Dragon',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: (locale, supported) {
          for (final s in supported) {
            if (s.languageCode == locale?.languageCode) return s;
          }
          return const Locale('ko');
        },
        home: const _AuthGate(),
      ),
    );
  }
}

/// Shows LoginScreen until user has a stored token, then LayoutScreen.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _isLoggedIn = false;
  bool _pendingFingerprint = false;
  bool _attemptingFingerprint = false;

  Future<void> _checkAuth() async {
    // Login temporarily disabled while the app is being redesigned — go straight inside.
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _loading = false;
    });
  }

  Future<void> _tryFingerprintLogin() async {
    if (!mounted) return;
    final reason = AppLocalizations.of(context).fingerprintReason;
    // Let the first frame and activity settle so Android can show BiometricPrompt
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // Wake up biometric stack on some devices
    await BiometricService.instance.getAvailableBiometrics();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final result = await BiometricService.instance.authenticate(
      reason: reason,
      biometricOnly: false,
    );
    if (!mounted) return;
    if (result != BiometricAuthResult.success) {
      setState(() => _attemptingFingerprint = false);
      return;
    }
    final username = await AuthService.instance.getSavedUsername();
    final password = await AuthService.instance.getSavedPassword();
    final user = await AuthService.instance.login(username: username, password: password);
    if (!mounted) return;
    setState(() {
      _attemptingFingerprint = false;
      if (user != null && user.permissions == 1) _isLoggedIn = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  void _onLogout() {
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingFingerprint) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pendingFingerprint = false;
          _attemptingFingerprint = true;
        });
        _tryFingerprintLogin();
      });
    }
    if (_loading || _pendingFingerprint || _attemptingFingerprint) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: scaffoldGradient),
          child: Center(
            child: Image.asset(
              'assets/images/login.png',
              fit: BoxFit.contain,
              width: 280,
              errorBuilder: (_, __, ___) => CircularProgressIndicator(color: primaryIndigo),
            ),
          ),
        ),
      );
    }
    if (_isLoggedIn) {
      return LayoutScreen(onLogout: _onLogout);
    }
    return LoginScreen(onLoginSuccess: _onLoginSuccess);
  }
}
