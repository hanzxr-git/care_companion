// cc_theme.dart
import 'package:flutter/material.dart';

class C {
  static const primary     = Color(0xFF7C6FCD);
  static const primarySoft = Color(0xFFEDEAFF);
  static const bg          = Color(0xFFF0EEF8);
  static const surface     = Color(0xFFFFFFFF);
  static const textDark    = Color(0xFF13103A);
  static const textMid     = Color(0xFF6B6880);
  static const textLight   = Color(0xFFAAABBD);
  static const green       = Color(0xFF3DBE6C);
  static const greenSoft   = Color(0xFFE6F9ED);
  static const orange      = Color(0xFFFF9800);
  static const orangeSoft  = Color(0xFFFFF3E0);
  static const red         = Color(0xFFEF5350);
  static const fire        = Color(0xFFFF6B35);
  static const divider     = Color(0xFFEEEDF5);

  // Font sizes — bigger and bolder to match screenshots
  static const double fTitle  = 32; // screen titles like "Daily Check-in"
  static const double fName   = 26; // user name in appbar
  static const double fH2     = 22; // card titles
  static const double fH3     = 18; // section labels
  static const double fBody   = 16; // body text
  static const double fSub    = 14; // subtitles
  static const double fCap    = 11; // ALL CAPS labels
  static const double fTiny   = 10; // smallest

  // 🔽 ADD THESE ALIASES TO FIX YOUR ERRORS 🔽
  static const double sz20    = fH2;   // matches 22 (closest to 20)
  static const double sz14    = fSub;  // matches 14
  static const double sz12    = 12.0;  // explicitly 12 since you don't have it
  static const double sz10    = fTiny; // matches 10

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    scaffoldBackgroundColor: bg,
    fontFamily: 'Nunito',
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textDark, size: 24),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      height: 68,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
        fontFamily: 'Nunito',
        fontSize: fTiny,
        fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
        color: s.contains(WidgetState.selected) ? primary : textLight,
      )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? primary : textLight,
        size: 24,
      )),
    ),
  );

  static void showNotification(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showNotificationWithMessenger(
      messenger,
      title: title,
      message: message,
      icon: icon,
      color: color,
      backgroundColor: backgroundColor,
    );
  }

  static void showNotificationWithMessenger(
    ScaffoldMessengerState messenger, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: textDark.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontFamily: 'Nunito',
                        fontSize: fBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: textMid,
                        fontFamily: 'Nunito',
                        fontSize: fSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String title, String message) {
    showNotification(
      context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      color: green,
      backgroundColor: greenSoft,
    );
  }

  static void showLogOut(ScaffoldMessengerState messenger, String title, String message) {
    showNotificationWithMessenger(
      messenger,
      title: title,
      message: message,
      icon: Icons.logout_rounded,
      color: orange,
      backgroundColor: orangeSoft,
    );
  }
}

class ElderScope extends InheritedWidget {
  final bool on;
  const ElderScope({super.key, required this.on, required super.child});
  static bool of(BuildContext c) =>
    c.dependOnInheritedWidgetOfExactType<ElderScope>()?.on ?? false;
  @override
  bool updateShouldNotify(ElderScope o) => on != o.on;
}

extension Ctx on BuildContext {
  bool get elder => ElderScope.of(this);
  double fs(double n) => elder ? n * 1.3 : n;
  double get ic => elder ? 28.0 : 22.0;
  double get bh => elder ? 62.0 : 54.0;
  EdgeInsets get hp => EdgeInsets.symmetric(horizontal: 20);
}

// Card widget — white rounded
class CC extends StatelessWidget {
  final Widget child;
  final EdgeInsets? pad;
  final Color? bg;
  final VoidCallback? onTap;
  const CC({super.key, required this.child, this.pad, this.bg, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: pad ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg ?? C.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    ),
  );
}

// ALL CAPS section label
class CapLabel extends StatelessWidget {
  final String text;
  const CapLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: TextStyle(
      fontSize: context.fs(C.fCap),
      fontWeight: FontWeight.w800,
      color: C.textMid,
      letterSpacing: 1.2,
    ));
}