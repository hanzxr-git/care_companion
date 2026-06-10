import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cc_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'join_circle_screen.dart';

class SetupCircleScreen extends StatefulWidget {
  const SetupCircleScreen({super.key});

  @override
  State<SetupCircleScreen> createState() => _SetupCircleScreenState();
}

class _SetupCircleScreenState extends State<SetupCircleScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final userName = auth.userModel?.displayName ?? '';
    _nameCtrl.text = userName.isNotEmpty ? "$userName's Family" : "My Family Circle";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a circle name');
      return;
    }

    final auth = context.read<AuthService>();
    final db = context.read<FirestoreService>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final circle = await db.createCircle(auth.uid!, name);
      if (mounted) {
        setState(() => _loading = false);
        C.showSuccess(context, 'Circle Created', 'Welcome to "${circle.name}"!');
      }
    } catch (e) {
      setState(() {
        _error = 'Could not create circle. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final name = auth.userModel?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.people_outline_rounded, color: C.primary, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, $name!',
                style: const TextStyle(
                  fontSize: C.fTitle,
                  fontWeight: FontWeight.w900,
                  color: C.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To get started, please create a new family circle or join an existing one using an invite code.',
                style: TextStyle(fontSize: C.fBody, color: C.textMid, height: 1.5),
              ),
              const SizedBox(height: 40),

              const Text(
                'CREATE A NEW CIRCLE',
                style: TextStyle(
                  fontSize: C.fCap,
                  fontWeight: FontWeight.w800,
                  color: C.textMid,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              CC(
                pad: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w600, color: C.textDark),
                      decoration: InputDecoration(
                        labelText: 'Circle Name',
                        errorText: _error,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _create,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.primary,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Create Circle', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('OR JOIN AN EXISTING ONE', style: TextStyle(color: C.textLight, fontSize: C.fCap, fontWeight: FontWeight.w800)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinCircleScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Enter Invite Code', style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.primary,
                    side: const BorderSide(color: C.primary, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
