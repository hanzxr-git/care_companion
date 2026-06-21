// cc_invite.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'cc_theme.dart';
import 'models/circle_model.dart';

class InviteSheet extends StatelessWidget {
  final CircleModel circle;
  const InviteSheet({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final code = circle.inviteCode;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: C.divider, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        Text('Add a person', style: TextStyle(
          fontSize: context.fs(C.sz20), fontWeight: FontWeight.w900, color: C.textDark)),
        SizedBox(height: e ? 5 : 4),
        Text('Share your invite code',
          style: TextStyle(fontSize: context.fs(C.sz14), color: C.textMid)),
        SizedBox(height: e ? 24 : 20),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: e ? 24 : 20),
          decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('INVITE CODE', style: TextStyle(
              fontSize: context.fs(C.sz10), fontWeight: FontWeight.w800,
              color: C.primary, letterSpacing: 1.5)),
            SizedBox(height: e ? 10 : 8),
            Text(code, style: TextStyle(
              fontSize: context.fs(32), fontWeight: FontWeight.w900,
              color: C.primary, letterSpacing: 8)),
            SizedBox(height: e ? 16 : 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!'), behavior: SnackBarBehavior.floating));
                },
                icon: Icon(Icons.copy_outlined, size: e ? 18 : 15),
                label: Text('Copy', style: TextStyle(fontSize: context.fs(C.sz12), fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.primary, side: const BorderSide(color: C.primary),
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: e ? 20 : 16, vertical: e ? 10 : 8))),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // ignore: deprecated_member_use
                  Share.share('Join my care circle "${circle.name}" on Carely! Use invite code: $code');
                },
                icon: Icon(Icons.share_outlined, size: e ? 18 : 15),
                label: Text('Share', style: TextStyle(fontSize: context.fs(C.sz12), fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary, foregroundColor: Colors.white,
                  shape: const StadiumBorder(), elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: e ? 20 : 16, vertical: e ? 10 : 8))),
            ]),
          ]),
        ),
        SizedBox(height: e ? 16 : 14),
      ]),
    );
  }
}