import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cc_theme.dart';
import 'models/notification_model.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';

class NotificationsSheet extends StatelessWidget {
  final bool hasCheckedInToday;
  final List<String> pendingMedicines;
  const NotificationsSheet({super.key, this.hasCheckedInToday = true, this.pendingMedicines = const []});

  static void show(BuildContext context, {bool hasCheckedInToday = true, List<String> pendingMedicines = const []}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsSheet(hasCheckedInToday: hasCheckedInToday, pendingMedicines: pendingMedicines),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'WELCOME': return Icons.waving_hand_rounded;
      case 'CIRCLE': return Icons.group_add_rounded;
      case 'STREAK': return Icons.local_fire_department_rounded;
      case 'REMINDER': return Icons.medication_rounded;
      case 'CHECKIN': return Icons.mood_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'WELCOME': return C.primary;
      case 'CIRCLE': return C.green;
      case 'STREAK': return C.fire;
      case 'REMINDER': return C.orange;
      case 'CHECKIN': return C.red;
      default: return C.textMid;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.uid;
    final fs = context.read<FirestoreService>();

    if (uid == null) return const SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: context.fs(C.fH2),
                        fontWeight: FontWeight.w900,
                        color: C.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: C.textMid),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (val) async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (val == 'read') await fs.markAllNotificationsAsRead(uid);
                              if (val == 'clear') await fs.deleteAllNotifications(uid);
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'read', child: Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w600))),
                            const PopupMenuItem(value: 'clear', child: Text('Clear all', style: TextStyle(color: C.red, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: C.textLight),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // ── List
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: fs.streamNotifications(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading notifications'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                List<NotificationModel> notifications = List.from(snapshot.data!);

                // Inject local transient CHECKIN notification if needed
                if (!hasCheckedInToday) {
                  notifications.insert(0, NotificationModel(
                    id: 'local_checkin',
                    type: 'CHECKIN',
                    title: 'Daily Check-in',
                    body: 'You haven\'t checked in yet today. How are you feeling?',
                    createdAt: DateTime.now(),
                    isRead: false,
                  ));
                }

                // Inject local transient REMINDER notifications for pending meds
                for (var medName in pendingMedicines.reversed) {
                  notifications.insert(0, NotificationModel(
                    id: 'local_med_${medName.hashCode}',
                    type: 'REMINDER',
                    title: 'Medication Reminder',
                    body: 'Don\'t forget to take your $medName.',
                    createdAt: DateTime.now(),
                    isRead: false,
                  ));
                }

                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'No new notifications',
                      style: TextStyle(color: C.textMid, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: notifications.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final notif = notifications[i];
                    final bool isNew = !notif.isRead;
                    final isLocal = notif.id.startsWith('local_');
                    return Dismissible(
                      key: Key(notif.id),
                      direction: isLocal ? DismissDirection.none : DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (!isLocal) {
                          try {
                            await fs.deleteNotification(uid, notif.id);
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                          }
                        } else {
                          messenger.showSnackBar(const SnackBar(content: Text('Cannot delete action-required reminders. Please complete the task.')));
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: C.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      child: PressableCard(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (!isLocal && !notif.isRead) {
                            try {
                              await fs.markNotificationAsRead(uid, notif.id);
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          } else if (isLocal) {
                            messenger.showSnackBar(const SnackBar(content: Text('This is a local reminder. Please complete the action.')));
                          }
                        },
                        padding: const EdgeInsets.all(16),
                        color: isNew ? C.primarySoft.withValues(alpha: 0.3) : C.surface,
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getColorForType(notif.type).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(notif.type),
                                color: _getColorForType(notif.type),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontSize: context.fs(C.fBody),
                                            fontWeight: isNew ? FontWeight.w900 : FontWeight.w700,
                                            color: C.textDark,
                                          ),
                                        ),
                                      ),
                                      if (isNew)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 8),
                                          decoration: const BoxDecoration(
                                            color: C.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif.body,
                                    style: TextStyle(
                                      fontSize: context.fs(C.fSub),
                                      color: C.textMid,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(notif.createdAt),
                                    style: TextStyle(
                                      fontSize: context.fs(C.fTiny),
                                      fontWeight: FontWeight.bold,
                                      color: C.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
