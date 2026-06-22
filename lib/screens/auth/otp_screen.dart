// screens/auth/otp_screen.dart
// Step 2 — enter the 6-digit OTP
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../cc_theme.dart';
import '../../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String username;
  final bool isNewUser;
  final String? email;
  final String? gender;
  final DateTime? birthDate;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.username,
    required this.isNewUser,
    this.email,
    this.gender,
    this.birthDate,
  });

  @override
  State<OtpScreen> createState() => _S();
}

class _S extends State<OtpScreen> {
  // 6 separate controllers for each digit box
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());

  int _resendSeconds = 60;
  Timer? _timer;
  bool _codeSent = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _sendOtp() {
    final auth = context.read<AuthService>();
    auth.sendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: () => setState(() => _codeSent = true),
      onError: (e) => _showError(e),
    );
  }

  void _resend() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _startTimer();
    _sendOtp();
  }

  String get _fullOtp =>
    _controllers.map((c) => c.text).join();

  void _verify() async {
    final auth = context.read<AuthService>();
    if (auth.isLoading) return;

    final otp = _fullOtp;
    if (otp.length < 6) {
      _showError('Please enter the full 6-digit code');
      return;
    }

    final success = await auth.verifyOtp(
      otp: otp,
      username: widget.username,
      email: widget.email,
      gender: widget.gender,
      birthDate: widget.birthDate,
      onError: _showError,
    );

    if (success && mounted) {
      // Navigate to shell — Consumer in main.dart handles this automatically
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    C.showError(context, 'Verification Failed', msg);
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      // Move to next box
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move back on delete
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_fullOtp.length == 6) {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 300), _verify);
    }
  }

  // Handle paste of full OTP
  void _onPaste(String pasted) {
    final digits = pasted.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      setState(() {});
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 300), _verify);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.status == AuthStatus.authenticated && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final name = auth.userModel?.username ?? widget.username;
          final finalName = name.isNotEmpty ? name : 'User';
          final title = widget.isNewUser ? 'Welcome' : 'Welcome Back';
          C.showSuccess(context, title, 'Logged in as $finalName');
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: C.textDark),
          onPressed: () => Navigator.pop(context)),
      ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Header
              const Text('Verify your number', style: TextStyle(
                fontSize: C.fTitle, fontWeight: FontWeight.w900, color: C.textDark)),
              const SizedBox(height: 10),
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: C.fBody, color: C.textMid, height: 1.4),
                children: [
                  const TextSpan(text: 'We sent a 6-digit code to\n'),
                  TextSpan(
                    text: widget.phoneNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800, color: C.textDark)),
                ],
              )),

              const SizedBox(height: 40),

              // 6 digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _DigitBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) => _onDigitChanged(i, v),
                  onPaste: _onPaste,
                )),
              ),

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: (auth.isLoading || !_codeSent) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary, foregroundColor: Colors.white,
                    elevation: 0, shape: const StadiumBorder(),
                    disabledBackgroundColor: C.primarySoft),
                  child: auth.isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                    : const Text('Verify', style: TextStyle(
                        fontSize: C.fH3, fontWeight: FontWeight.w900)),
                ),
              ),

              const SizedBox(height: 24),

              // Resend timer
              Center(child: _resendSeconds > 0
                ? RichText(text: TextSpan(
                    style: const TextStyle(fontSize: C.fBody, color: C.textMid),
                    children: [
                      const TextSpan(text: 'Resend code in '),
                      TextSpan(
                        text: '${_resendSeconds}s',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800, color: C.primary)),
                    ],
                  ))
                : GestureDetector(
                    onTap: _resend,
                    child: const Text('Resend code', style: TextStyle(
                      fontSize: C.fBody, fontWeight: FontWeight.w800,
                      color: C.primary)),
                  ),
              ),

              const SizedBox(height: 32),

              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: C.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'The code expires in 60 seconds. If you didn\'t receive it, check that the number is correct or tap Resend.',
                    style: const TextStyle(
                      fontSize: C.fSub, color: C.primary, height: 1.5))),
                ]),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// Single digit input box
class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onPaste;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48, height: 58,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 24, fontWeight: FontWeight.w900, color: C.textDark),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: focusNode.hasFocus ? C.primarySoft : C.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: C.divider, width: 1.5)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: C.primary, width: 2.5)),
      ),
      onChanged: (v) {
        // Handle paste of full code
        if (v.length > 1) {
          onPaste(v);
        } else {
          onChanged(v);
        }
      },
    ),
  );
}
