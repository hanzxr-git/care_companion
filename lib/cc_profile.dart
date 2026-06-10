// cc_profile.dart — real user data from Firestore
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'services/auth_service.dart';

class ProfileTab extends StatefulWidget {
  final Function(bool) onToggleElder;
  const ProfileTab({super.key, required this.onToggleElder});
  @override
  State<ProfileTab> createState() => _S();
}

class _S extends State<ProfileTab> {
  bool _notif = true;

  @override
  Widget build(BuildContext context) {
    final e     = context.elder;
    final auth  = context.watch<AuthService>();
    final user  = auth.userModel;

    if (user == null) return const Center(child: CircularProgressIndicator());

    // Initials from real name
    final initials = user.avatarInitials;
    final color    = Color(user.avatarColorValue);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ListView(children: [
          const SizedBox(height: 32),

          // Avatar + name + phone + badges
          Center(child: Column(children: [
            CircleAvatar(
              radius: e ? 42 : 36,
              backgroundColor: color,
              child: Text(initials, style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900,
                fontSize: context.fs(e ? 26 : 22)))),
            const SizedBox(height: 14),
            Text(user.displayName, style: TextStyle(
              fontSize: context.fs(C.fH2),
              fontWeight: FontWeight.w900, color: C.textDark)),
            const SizedBox(height: 4),
            Text(user.phone, style: TextStyle(
              fontSize: context.fs(C.fSub), color: C.textMid)),
            if (user.email != null) ...[
              const SizedBox(height: 2),
              Text(user.email!, style: TextStyle(
                fontSize: context.fs(C.fSub), color: C.textMid)),
            ],
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _badge('FAMILY MEMBER', e, context),
              const SizedBox(width: 8),
              _badge('MONITOR', e, context),
            ]),
          ])),

          const SizedBox(height: 28),

          // Edit profile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfile(context, auth),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.primary,
                side: const BorderSide(color: C.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),

          const SizedBox(height: 24),

          // APPEARANCE
          _secLabel('APPEARANCE', context),
          _swTile(
            icon: Icons.phone_android_outlined,
            title: 'Elder Mode',
            value: e,
            onChanged: (v) {
              widget.onToggleElder(v);
              auth.setElderMode(v);
            },
            e: e, context: context, highlight: e),

          const SizedBox(height: 16),

          // SAFETY & PRIVACY
          _secLabel('SAFETY & PRIVACY', context),
          _swTile(
            icon: Icons.location_on_outlined,
            title: 'Share location',
            value: user.locationSharing,
            onChanged: (v) => auth.setLocationSharing(v),
            e: e, context: context),

          const SizedBox(height: 16),

          // NOTIFICATIONS
          _secLabel('NOTIFICATIONS', context),
          _swTile(
            icon: Icons.notifications_outlined,
            title: 'Push notifications',
            value: _notif,
            onChanged: (v) => setState(() => _notif = v),
            e: e, context: context),

          const SizedBox(height: 16),

          // SUPPORT
          _secLabel('SUPPORT', context),
          _infoTile(Icons.info_outline_rounded,
            'CareCompanion v2.0', e, context),
          _infoTile(Icons.school_outlined,
            'UTeM FTMK — BITU 3973', e, context),

          const SizedBox(height: 28),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => _confirmSignOut(context, auth),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: e ? 16 : 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.red.withOpacity(0.5))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: C.red, size: e ? 24 : 20),
                  const SizedBox(width: 8),
                  Text('Sign out', style: TextStyle(
                    fontSize: context.fs(C.fBody),
                    fontWeight: FontWeight.w800, color: C.red)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // Edit name + optional email
  void _showEditProfile(BuildContext context, AuthService auth) {
    final nameCtrl  = TextEditingController(text: auth.userModel?.displayName);
    final emailCtrl = TextEditingController(text: auth.userModel?.email ?? '');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          decoration: const BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: C.divider,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Edit profile', style: TextStyle(
              fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark)),
            const SizedBox(height: 20),

            const Text('DISPLAY NAME', style: TextStyle(
              fontSize: C.fCap, fontWeight: FontWeight.w800,
              color: C.textMid, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Your full name',
                filled: true, fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none))),
            const SizedBox(height: 16),

            const Text('EMAIL (optional — for recovery)', style: TextStyle(
              fontSize: C.fCap, fontWeight: FontWeight.w800,
              color: C.textMid, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'you@email.com',
                filled: true, fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none))),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  await auth.updateProfile(
                    displayName: nameCtrl.text.trim().isEmpty
                      ? null : nameCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty
                      ? null : emailCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary, foregroundColor: Colors.white,
                  shape: const StadiumBorder()),
                child: const Text('Save changes', style: TextStyle(
                  fontSize: C.fBody, fontWeight: FontWeight.w900)))),
          ]),
        ),
      ));
  }

  void _confirmSignOut(BuildContext context, AuthService auth) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Sign out?', style: TextStyle(
        fontWeight: FontWeight.w900, fontSize: C.fH2)),
      content: const Text('You will need to verify your phone number again to sign back in.',
        style: TextStyle(fontSize: C.fBody, color: C.textMid)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(
            color: C.textMid, fontSize: C.fBody))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final messenger = ScaffoldMessenger.of(context);
            await auth.signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            C.showLogOut(messenger, 'Logged Out', 'Hope to see you soon!');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: C.red, foregroundColor: Colors.white,
            shape: const StadiumBorder()),
          child: const Text('Sign out', style: TextStyle(fontSize: C.fBody))),
      ],
    ));
  }

  Widget _badge(String label, bool e, BuildContext ctx) => Container(
    padding: EdgeInsets.symmetric(horizontal: e ? 14 : 12, vertical: e ? 6 : 4),
    decoration: BoxDecoration(color: C.primarySoft,
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(
      fontSize: ctx.fs(C.fCap), fontWeight: FontWeight.w800,
      color: C.primary, letterSpacing: 0.5)));

  Widget _secLabel(String text, BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Text(text, style: TextStyle(
      fontSize: ctx.fs(C.fCap), fontWeight: FontWeight.w800,
      color: C.textMid, letterSpacing: 1.2)));

  Widget _swTile({
    required IconData icon, required String title, required bool value,
    required ValueChanged<bool> onChanged, required bool e,
    required BuildContext context, bool highlight = false,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    padding: EdgeInsets.symmetric(
      horizontal: e ? 18 : 16, vertical: e ? 16 : 13),
    decoration: BoxDecoration(
      color: highlight ? C.primarySoft : C.surface,
      borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Icon(icon, color: C.textMid, size: context.ic),
      SizedBox(width: e ? 16 : 14),
      Expanded(child: Text(title, style: TextStyle(
        fontSize: context.fs(C.fBody),
        fontWeight: FontWeight.w700, color: C.textDark))),
      Switch(value: value, onChanged: onChanged, activeThumbColor: C.primary),
    ]));

  Widget _infoTile(IconData icon, String title, bool e, BuildContext ctx) =>
    Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: EdgeInsets.symmetric(
        horizontal: e ? 18 : 16, vertical: e ? 16 : 13),
      decoration: BoxDecoration(
        color: C.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: C.textMid, size: ctx.ic),
        SizedBox(width: e ? 16 : 14),
        Text(title, style: TextStyle(
          fontSize: ctx.fs(C.fBody),
          fontWeight: FontWeight.w700, color: C.textDark)),
      ]));
}