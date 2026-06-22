// screens/circle_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../cc_theme.dart';
import '../models/circle_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class CircleManagementScreen extends StatefulWidget {
  final CircleModel circle;
  const CircleManagementScreen({super.key, required this.circle});

  @override
  State<CircleManagementScreen> createState() => _CircleManagementScreenState();
}

class _CircleManagementScreenState extends State<CircleManagementScreen> {
  late final TextEditingController _nameCtrl;
  bool _renaming = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.circle.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    final db = context.read<FirestoreService>();
    setState(() => _saving = true);

    try {
      await db.renameCircle(widget.circle.circleId, newName);
      if (mounted) {
        setState(() {
          _saving = false;
          _renaming = false;
        });
        C.showSuccess(context, 'Circle Renamed', 'Name updated to "$newName"');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        C.showError(context, 'Rename Failed', 'Failed to rename circle. Please try again.');
      }
    }
  }

  Future<void> _removeMember(UserModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to remove ${m.username} from the circle?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: C.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final db = context.read<FirestoreService>();
      try {
        await db.leaveCircle(widget.circle.circleId, m.uid);
        if (mounted) {
          C.showSuccess(context, 'Member Removed', '${m.username} has been removed.');
        }
      } catch (e) {
        if (mounted) {
          C.showError(context, 'Remove Failed', 'Failed to remove member.');
        }
      }
    }
  }

  Future<void> _leaveCircle() async {
    final auth = context.read<AuthService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Circle', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to leave this circle? You will lose access to all member updates.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: C.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final db = context.read<FirestoreService>();
      try {
        await db.leaveCircle(widget.circle.circleId, auth.uid!);
        if (mounted) {
          Navigator.pop(context); // Close management screen
          C.showSuccess(context, 'Left Circle', 'You have successfully left the circle.');
        }
      } catch (e) {
        if (mounted) {
          C.showError(context, 'Leave Failed', 'Failed to leave circle.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.read<FirestoreService>();
    final isOwner = widget.circle.ownerId == auth.uid!;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: const Text(
          'Circle Management',
          style: TextStyle(fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: C.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<CircleModel?>(
        stream: db.streamCircle(widget.circle.circleId),
        builder: (context, circleSnap) {
          final circle = circleSnap.data ?? widget.circle;

          return StreamBuilder<List<UserModel>>(
            stream: db.streamCircleMemberProfiles(circle.memberUids),
            builder: (context, membersSnap) {
              final members = membersSnap.data ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Circle Name Card
                  CC(
                    pad: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CapLabel('CIRCLE NAME'),
                        const SizedBox(height: 8),
                        if (_renaming && isOwner)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: C.textDark),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.check_rounded, color: C.green),
                                      onPressed: _saveName,
                                    ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: C.red),
                                onPressed: () => setState(() {
                                  _renaming = false;
                                  _nameCtrl.text = circle.name;
                                }),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                circle.name,
                                style: const TextStyle(fontSize: C.fH2, fontWeight: FontWeight.w900, color: C.textDark),
                              ),
                              if (isOwner)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: C.primary),
                                  onPressed: () => setState(() => _renaming = true),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invite Code Card
                  CC(
                    pad: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CapLabel('INVITATION CODE'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                circle.inviteCode,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.primary, letterSpacing: 2),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, color: C.primary),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: circle.inviteCode));
                                      C.showSuccess(context, 'Code Copied', 'Invite code copied to clipboard!');
                                    },
                                    tooltip: 'Copy Code',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Member List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CapLabel('CIRCLE MEMBERS'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: C.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${members.length} TOTAL',
                          style: const TextStyle(fontSize: C.fCap, fontWeight: FontWeight.w900, color: C.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ...members.map((m) {
                    final isMe = m.uid == auth.uid!;
                    final isOwnerMember = circle.ownerId == m.uid;

                    String roleLabel = 'Member';
                    Color roleColor = C.green;
                    if (isOwnerMember) {
                      roleLabel = 'Owner';
                      roleColor = C.primary;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          m.buildAvatar(radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.username + (isMe ? ' (You)' : ''),
                                  style: const TextStyle(fontSize: C.fBody, fontWeight: FontWeight.w800, color: C.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.phone,
                                  style: const TextStyle(fontSize: C.fSub, color: C.textMid),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: C.fTiny,
                                fontWeight: FontWeight.w900,
                                color: roleColor,
                              ),
                            ),
                          ),
                          if (isOwner && !isMe && !isOwnerMember)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: C.red, size: 20),
                              onPressed: () => _removeMember(m),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 40),

                  // Leave Circle Button
                  if (!isOwner || circle.members.length > 1)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _leaveCircle,
                        icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                        label: const Text(
                          'LEAVE CIRCLE',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
