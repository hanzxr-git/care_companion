// screens/auth/pending_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cc_theme.dart';
import '../../models/circle_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class PendingApprovalScreen extends StatefulWidget {
  final CircleModel circle;
  const PendingApprovalScreen({super.key, required this.circle});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _cancelRequest() async {
    final auth = context.read<AuthService>();
    final db = context.read<FirestoreService>();

    setState(() => _cancelling = true);

    try {
      await db.declineJoinRequest(widget.circle.circleId, auth.uid!);
      if (mounted) {
        C.showSuccess(context, 'Request Cancelled', 'You can now create or join another circle.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        C.showError(context, 'Cancellation Failed', 'Failed to cancel request. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: C.textDark),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated pulsing icon container
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: C.primarySoft.withValues(alpha: 0.5 + (_pulseController.value * 0.5)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      color: C.primary,
                      size: 64 + (_pulseController.value * 8),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text(
                'Join Request Sent!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: C.fTitle - 4,
                  fontWeight: FontWeight.w900,
                  color: C.textDark,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: C.fBody,
                    color: C.textMid,
                    fontFamily: 'Nunito',
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Your request to join '),
                    TextSpan(
                      text: widget.circle.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: C.textDark),
                    ),
                    const TextSpan(text: ' is pending approval from the circle monitors.'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CC(
                pad: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'INVITE CODE USED',
                      style: TextStyle(
                        fontSize: C.fCap,
                        fontWeight: FontWeight.w800,
                        color: C.textLight,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      widget.circle.inviteCode,
                      style: const TextStyle(
                        fontSize: C.fBody,
                        fontWeight: FontWeight.w900,
                        color: C.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _cancelling ? null : _cancelRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.red,
                    side: const BorderSide(color: C.red, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                  child: _cancelling
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: C.red, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Cancel Request',
                          style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
