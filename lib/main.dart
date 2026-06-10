// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'cc_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/setup_circle_screen.dart';
import 'models/circle_model.dart';
import 'cc_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: const _AppWrapper(),
    );
  }
}

class _AppWrapper extends StatefulWidget {
  const _AppWrapper();
  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> {
  bool _elder = false;
  void _toggleElder(bool v) => setState(() => _elder = v);

  @override
  Widget build(BuildContext context) {
    return ElderScope(
      on: _elder,
      child: MaterialApp(
        title: 'CareCompanion',
        debugShowCheckedModeBanner: false,
        theme: C.theme,
        home: Consumer<AuthService>(
          builder: (ctx, auth, _) {
            switch (auth.status) {

              case AuthStatus.unknown:
              case AuthStatus.loading:
                // App starting or fetching profile — show splash
                return const _SplashScreen();

              case AuthStatus.authenticated:
                // Logged in + profile ready — check for circles
                return StreamBuilder<List<CircleModel>>(
                  stream: Provider.of<FirestoreService>(ctx, listen: false).streamMyCircles(auth.uid!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _SplashScreen();
                    }
                    if (snapshot.hasError) {
                      debugPrint('STREAM ERROR IN MAIN: ${snapshot.error}');
                      debugPrint('STACKTRACE: ${snapshot.stackTrace}');
                      return Scaffold(
                        backgroundColor: C.bg,
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Database Error: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: C.fBody,
                                    fontWeight: FontWeight.w700,
                                    color: C.textDark,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => auth.signOut(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: C.primary,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Sign Out & Try Again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final circles = snapshot.data ?? [];
                    if (circles.isEmpty) {
                      return const SetupCircleScreen();
                    }
                    return Shell(circle: circles.first, onToggleElder: _toggleElder);
                  },
                );

              case AuthStatus.unauthenticated:
                // Not logged in — show phone screen
                return const PhoneScreen();
            }
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: C.primary,
              child: Icon(Icons.favorite_rounded,
                color: Colors.white, size: 32),
            ),
            SizedBox(height: 24),
            Text('CareCompanion', style: TextStyle(
              fontSize: C.fH2,
              fontWeight: FontWeight.w900,
              color: C.textDark)),
            SizedBox(height: 20),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                color: C.primary, strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}