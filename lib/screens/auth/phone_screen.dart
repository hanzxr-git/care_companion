// screens/auth/phone_screen.dart
// Step 1 — enter phone number
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../cc_theme.dart';
import '../../services/auth_service.dart';
import 'otp_screen.dart';
import 'join_circle_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _S();
}

class _S extends State<PhoneScreen> {
  final _phone = TextEditingController();
  final _name  = TextEditingController();
  bool _isRegister = false;
  String _countryCode = '+60'; // Malaysia default

  final _countries = [
    ('+60', 'MY 🇲🇾'),
    ('+65', 'SG 🇸🇬'),
    ('+62', 'ID 🇮🇩'),
    ('+66', 'TH 🇹🇭'),
    ('+44', 'UK 🇬🇧'),
    ('+1',  'US 🇺🇸'),
  ];

  @override
  void dispose() { _phone.dispose(); _name.dispose(); super.dispose(); }

  void _submit() {
    final number = _phone.text.trim();
    final name   = _name.text.trim();

    if (_isRegister && name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (number.isEmpty || number.length < 7) {
      _showError('Please enter a valid phone number');
      return;
    }

    // Remove leading 0 if present (Malaysian habit: 0123 → 123)
    final cleaned = number.startsWith('0') ? number.substring(1) : number;
    final fullNumber = '$_countryCode$cleaned';

    Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(
      phoneNumber: fullNumber,
      displayName: _isRegister ? name : 'User',
      isNewUser: _isRegister,
    )));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: C.red));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 56),

            // Logo
            Center(child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: C.primary, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 34)),
              const SizedBox(height: 16),
              const Text('CareCompanion', style: TextStyle(
                fontSize: C.fTitle, fontWeight: FontWeight.w900, color: C.textDark)),
              const SizedBox(height: 6),
              const Text('Family wellness, simplified.', style: TextStyle(
                fontSize: C.fBody, color: C.textMid)),
            ])),

            const SizedBox(height: 40),

            // Tab toggle
            Container(
              decoration: BoxDecoration(
                color: C.surface, borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                _tab('Sign in', !_isRegister, () => setState(() => _isRegister = false)),
                _tab('Register', _isRegister, () => setState(() => _isRegister = true)),
              ]),
            ),

            const SizedBox(height: 28),

            // Name field (register only)
            if (_isRegister) ...[
              _lbl('FULL NAME'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w600, color: C.textDark),
                decoration: _inputDec('Ahmad bin Ali', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 20),
            ],

            _lbl('PHONE NUMBER'),
            // Phone row: country code + number
            Row(children: [
              // Country code picker
              GestureDetector(
                onTap: () => _showCountryPicker(),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.divider)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_countryCode, style: const TextStyle(
                      fontSize: C.fBody, fontWeight: FontWeight.w700, color: C.textDark)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: C.textMid, size: 20),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w600, color: C.textDark),
                decoration: _inputDec('123456789', Icons.phone_outlined),
              )),
            ]),

            const SizedBox(height: 10),
            Text(
              'Example: $_countryCode 12-345 6789 → enter 123456789',
              style: const TextStyle(fontSize: C.fCap, color: C.textLight)),

            const SizedBox(height: 32),

            // CTA button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary, foregroundColor: Colors.white,
                  elevation: 0, shape: const StadiumBorder()),
                child: auth.isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(_isRegister ? 'Send OTP' : 'Continue',
                      style: const TextStyle(fontSize: C.fH3, fontWeight: FontWeight.w900)),
              ),
            ),

            const SizedBox(height: 32),
            Row(children: const [Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('or join with invite', style: TextStyle(color: C.textLight, fontSize: C.fCap))),
              Expanded(child: Divider())]),
            const SizedBox(height: 20),

            // Join via invite code
            SizedBox(
              width: double.infinity, height: 54,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JoinCircleScreen())),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Enter invite code',
                  style: TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.primary,
                  side: const BorderSide(color: C.primary),
                  shape: const StadiumBorder()),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? C.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: C.fSub,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? C.primary : C.textMid)),
      ),
    ));

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(
      fontSize: C.fCap, fontWeight: FontWeight.w800,
      color: C.textMid, letterSpacing: 1.2)));

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: C.textLight, fontSize: C.fBody),
    prefixIcon: Icon(icon, color: C.textLight, size: 20),
    filled: true, fillColor: C.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: C.divider)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: C.primary, width: 2)));

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: C.divider,
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Select country', style: TextStyle(
            fontSize: C.fH3, fontWeight: FontWeight.w900, color: C.textDark)),
          const SizedBox(height: 12),
          ..._countries.map((c) => ListTile(
            title: Text('${c.$2}  ${c.$1}', style: const TextStyle(
              fontSize: C.fBody, fontWeight: FontWeight.w600)),
            trailing: _countryCode == c.$1
              ? const Icon(Icons.check_rounded, color: C.primary) : null,
            onTap: () {
              setState(() => _countryCode = c.$1);
              Navigator.pop(context);
            },
          )),
        ]),
      ));
  }
}
