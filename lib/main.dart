// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'cc_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'services/alarm_service.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/setup_circle_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'models/circle_model.dart';
import 'screens/admin_console_screen.dart';
import 'cc_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AlarmService.init();
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
        ProxyProvider<FirestoreService, LocationService>(
          update: (_, db, _) => LocationService(db),
        ),
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
  bool _elderInitialized = false;
  void _toggleElder(bool v) => setState(() => _elder = v);
  String? _activeCircleId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (ctx, auth, _) {
        // On first load once user profile is available, initialize elder mode from saved preference
        if (!_elderInitialized && auth.userModel != null) {
          _elder = auth.userModel!.elderMode;
          _elderInitialized = true;
        }

        return ElderScope(
          on: _elder,
          child: MaterialApp(
            title: 'Carely',
            debugShowCheckedModeBanner: false,
            theme: C.theme,
            home: _buildHome(ctx, auth),
          ),
        );
      },
    );
  }

  Widget _buildHome(BuildContext ctx, AuthService auth) {
    switch (auth.status) {

      case AuthStatus.unknown:
      case AuthStatus.loading:
        return const _SplashScreen();

      case AuthStatus.authenticated:
        if (auth.userModel?.phone == '+60987654321') {
          return const AdminConsoleScreen();
        }

        final db = Provider.of<FirestoreService>(ctx, listen: false);
        return StreamBuilder<List<CircleModel>>(
          stream: db.streamMyCircles(auth.uid!),
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
              return StreamBuilder<List<CircleModel>>(
                stream: db.streamMyPendingCircles(auth.uid!),
                builder: (context, pendingSnap) {
                  if (pendingSnap.connectionState == ConnectionState.waiting) {
                    return const _SplashScreen();
                  }
                  final pendingCircles = pendingSnap.data ?? [];
                  if (pendingCircles.isNotEmpty) {
                    return PendingApprovalScreen(circle: pendingCircles.first);
                  }
                  return const SetupCircleScreen();
                },
              );
            }

            // Determine active circle
            final activeCircle = circles.firstWhere(
              (c) => c.circleId == _activeCircleId,
              orElse: () => circles.first,
            );

            return Shell(
              key: ValueKey(activeCircle.circleId),
              circle: activeCircle,
              onToggleElder: _toggleElder,
              allCircles: circles,
              onSwitchCircle: (id) {
                setState(() {
                  _activeCircleId = id;
                });
              },
            );
          },
        );

      case AuthStatus.unauthenticated:
        return const PhoneScreen();
    }
  }
}


class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/logo.png', width: 72, height: 72),
            ),
            const SizedBox(height: 24),
            Text('Carely', style: TextStyle(
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