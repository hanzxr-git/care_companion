// app_providers.dart — wire everything together with Provider
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth — drives login state
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Firestore — shared service instance
        Provider(create: (_) => FirestoreService()),
      ],
      child: child,
    );
  }
}
