// screens/auth/join_circle_screen.dart
// For users who received an invite code and want to join
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../cc_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'phone_screen.dart';

class JoinCircleScreen extends StatefulWidget {
  const JoinCircleScreen({super.key});
  @override
  State<JoinCircleScreen> createState() => _S();
}

class _S extends State<JoinCircleScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code');
      return;
    }

    final auth = context.read<AuthService>();
    final db   = context.read<FirestoreService>();

    // Must be logged in first
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please sign in or register first'),
        behavior: SnackBarBehavior.floating));
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const PhoneScreen()));
      return;
    }

    var formattedCode = code;
    if (!formattedCode.startsWith('CC-') && formattedCode.length == 6) {
      formattedCode = 'CC-$formattedCode';
    }

    setState(() { _loading = true; _error = null; });

    try {
      final circle = await db.joinCircleByCode(auth.uid!, formattedCode);
      if (circle == null) {
        setState(() {
          _error = 'Invalid code. Check and try again.';
          _loading = false;
        });
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Joined "${circle.name}"!'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('ERROR JOINING CIRCLE: $e');
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: C.textDark),
          onPressed: () => Navigator.pop(context))),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.primary.withValues(alpha: 0.15), C.bg],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            const Text('Join a circle', style: TextStyle(
              fontSize: C.fTitle, fontWeight: FontWeight.w900, color: C.textDark)),
            const SizedBox(height: 8),
            const Text('Enter the invite code sent by your family member.',
              style: TextStyle(fontSize: C.fBody, color: C.textMid, height: 1.5)),
            const SizedBox(height: 40),

            // Large code input
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: C.primary, letterSpacing: 8),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-]')),
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                hintText: 'CC-XXXXXX',
                hintStyle: const TextStyle(
                  fontSize: 28, color: C.textLight, letterSpacing: 8,
                  fontWeight: FontWeight.w700),
                filled: true, fillColor: C.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: C.divider)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: C.primary, width: 2)),
                errorText: _error,
              ),
            ),

            const SizedBox(height: 10),
            const Text('Format: CC-XXXXXX (6 characters after CC-)',
              style: TextStyle(fontSize: C.fCap, color: C.textLight)),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary, foregroundColor: Colors.white,
                  elevation: 0, shape: const StadiumBorder()),
                child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                  : const Text('Join circle', style: TextStyle(
                      fontSize: C.fH3, fontWeight: FontWeight.w900)),
              ),
            ),

            const SizedBox(height: 24),
            Center(child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I have a phone number instead',
                style: TextStyle(
                  fontSize: C.fBody, color: C.textMid,
                  fontWeight: FontWeight.w600)),
            )),
          ]),
        ),
      ),
      ),
    );
  }
}
