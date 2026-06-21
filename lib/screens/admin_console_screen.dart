// screens/admin_console_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/circle_model.dart';
import '../models/audit_log_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Lightweight helper class to unify standard system logs and medical logs for AI analysis
class UnifiedLog {
  final DateTime timestamp;
  final String content;

  UnifiedLog({required this.timestamp, required this.content});
}

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  int _currentTab = 0; // 0: Users, 1: Logs, 2: AI Reports
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  
  // AI State
  bool _isGeneratingAI = false;
  String _aiReport = '';

  late final Stream<List<UserModel>> _usersStream;
  late final Stream<List<CircleModel>> _circlesStream;
  late final Stream<List<AuditLogModel>> _logsStream;

  @override
  void initState() {
    super.initState();
    final db = context.read<FirestoreService>();
    _usersStream = db.streamAllUsers();
    _circlesStream = db.streamAllCircles();
    _logsStream = db.streamSystemLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _generateAiReport(List<UserModel> users, List<CircleModel> circles, List<AuditLogModel> logs) async {
    final db = context.read<FirestoreService>();
    final firestore = FirebaseFirestore.instance;
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''); 
    setState(() => _isGeneratingAI = true);
    try {
      // 1. Fetch recent records from both 'logs' and 'med_logs' collections in parallel to optimize runtimes
      final systemLogsFuture = firestore.collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();

      final medLogsFuture = firestore.collection('med_logs')
          .orderBy('takenAt', descending: true)
          .limit(15)
          .get();

      final snapshots = await Future.wait([systemLogsFuture, medLogsFuture]);
      final List<UnifiedLog> combinedLogs = [];

      // 2. Parse and adapt documents from standard administrative logs collection
      for (var doc in snapshots[0].docs) {
        final data = doc.data();
        final Timestamp? ts = data['timestamp'] as Timestamp?;
        if (ts != null) {
          combinedLogs.add(UnifiedLog(
            timestamp: ts.toDate(),
            content: 'Admin Event | ${data['action'] ?? ''}: ${data['details'] ?? ''}',
          ));
        }
      }

      // 3. Parse and adapt documents from medical adherence compliance tracker logs
      for (var doc in snapshots[1].docs) {
        final data = doc.data();
        final Timestamp? ts = data['takenAt'] as Timestamp?;
        if (ts != null) {
          combinedLogs.add(UnifiedLog(
            timestamp: ts.toDate(),
            content: 'Medical Tracker | Medication ID: ${data['medId'] ?? 'Unknown'} status marked as [${data['status'] ?? ''}] (Scheduled Time: ${data['scheduledTime'] ?? ''})',
          ));
        }
      }

      // 4. Chronologically organize the complete merged timeline (Newest entries first)
      combinedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 5. Clean layout mapping to flatten text context strings and save operational prompt tokens
      final formattedLogsString = combinedLogs.take(20).map((log) {
        final timeStr = "${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}";
        return '$timeStr | ${log.content}';
      }).join('\n');

      final activeAlerts = users.where((u) => u.sosActive).length;
      
      final systemContext = '''
You are an AI assistant for the Carely Admin Console. 
Analyze the following multi-source real-time database state variables and logs timeline to generate a structured system summary report.
---
TOTAL REGISTERED USERS: ${users.length}
ACTIVE CARE CIRCLES: ${circles.length}
ACTIVE CRITICAL SOS ALERTS: $activeAlerts

INTEGRATED AUDIT LOGS TIMELINE (HH:mm format):
${formattedLogsString.isEmpty ? 'No recent logs tracking dataset entries available.' : formattedLogsString}
---
ADMIN PROMPT: Please generate a comprehensive operational report. Highlight core usage activity trends, critical medical adherence compliance observation counts, any active SOS tracking anomalies, and global platform security status.
''';

      // 6. Use the production-ready flash model safe for clean unbilled free-trial accounts
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final content = [Content.text(systemContext)];
      final response = await model.generateContent(content);
      
      setState(() {
        _aiReport = response.text ?? 'No cohesive response generated by model endpoint.';
        _isGeneratingAI = false;
      });
      
      await db.logSystemEvent('AI Report Generated', 'Successfully generated hybrid operational metrics report.');
    } catch (e) {
      setState(() {
        _aiReport = 'Error generating report parameters: $e';
        _isGeneratingAI = false;
      });
      
      await db.logSystemEvent('AI Report Failed', 'Error context execution: $e');
    }
  }

  void _showEditUserDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.username);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email);
    bool elderMode = user.elderMode;
    bool locationSharing = user.locationSharing;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                SwitchListTile(
                  title: const Text('Elder Mode'),
                  value: elderMode,
                  onChanged: (v) => setDialogState(() => elderMode = v),
                ),
                SwitchListTile(
                  title: const Text('Location Sharing'),
                  value: locationSharing,
                  onChanged: (v) => setDialogState(() => locationSharing = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                context.read<FirestoreService>().updateUser(user.uid, {
                  'username': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  'elderMode': elderMode,
                  'locationSharing': locationSharing,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserActionSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final db = context.read<FirestoreService>();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E2F0), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Manage ${user.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFF6B5CD1)),
                title: const Text('Edit User Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditUserDialog(user);
                },
              ),
              ListTile(
                leading: Icon(user.accountStatus == 'ACTIVE' ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: const Color(0xFFF2994A)),
                title: Text(user.accountStatus == 'ACTIVE' ? 'Deactivate User' : 'Reactivate User'),
                onTap: () {
                  final newStatus = user.accountStatus == 'ACTIVE' ? 'DEACTIVATED' : 'ACTIVE';
                  db.updateUserStatus(user.uid, newStatus);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User status changed to $newStatus')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4B55)),
                title: const Text('Delete User Data', style: TextStyle(color: Color(0xFFFF4B55))),
                onTap: () {
                  db.deleteUserProfile(user.uid);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User profile deleted')));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 90,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE5E2F0), width: 1)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5CD1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Console',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                Text(
                  'SYSTEM ROOT • V1.0.4',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6B5CD1).withValues(alpha: 0.6),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFA09DB0)),
            tooltip: 'Sign Out',
            onPressed: () {
              FocusScope.of(context).unfocus();
              auth.signOut();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: MultiStreamBuilder(
        usersStream: _usersStream,
        circlesStream: _circlesStream,
        logsStream: _logsStream,
        builder: (context, users, circles, logs) {
          final activeAlerts = users.where((u) => u.sosActive).length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Metrics Grid
              Row(
                children: [
                  Expanded(child: _buildMetricCard(icon: Icons.people_outline_rounded, value: '${users.length}', label: 'TOTAL USERS', color: const Color(0xFF6B5CD1))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(icon: Icons.warning_amber_rounded, value: '$activeAlerts', label: 'ALERTS', color: const Color(0xFFFF4B55))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricCard(icon: Icons.show_chart_rounded, value: '99.9%', label: 'UPTIME', color: const Color(0xFF00C48C))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(icon: Icons.verified_user_outlined, value: '${circles.length}', label: 'ACTIVE CIRCLES', color: const Color(0xFF2D9CDB))),
                ],
              ),
              const SizedBox(height: 32),

              // Tab Bar
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B5CD1).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildTab(0, 'Users', Icons.people_outline_rounded)),
                    Expanded(child: _buildTab(1, 'Logs', Icons.storage_rounded)),
                    Expanded(child: _buildTab(2, 'AI Reports', Icons.auto_awesome_rounded)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Contents
              if (_currentTab == 0) _buildUsersTab(users),
              if (_currentTab == 1) _buildLogsTab(logs),
              if (_currentTab == 2) _buildAITab(users, circles, logs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E1E2D),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFA09DB0),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6B5CD1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0xFFA09DB0),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : const Color(0xFFA09DB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(List<UserModel> users) {
    final filtered = users.where((u) => u.username.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B5CD1).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: const TextStyle(color: Color(0xFFA09DB0), fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA09DB0)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded, color: Color(0xFFA09DB0)),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B5CD1).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    const Expanded(flex: 3, child: Text('USER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF555266), letterSpacing: 1.5))),
                    const Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF555266), letterSpacing: 1.5), textAlign: TextAlign.center)),
                    const Expanded(flex: 1, child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF555266), letterSpacing: 1.5), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0EFF5)),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No users found', style: TextStyle(color: Color(0xFFA09DB0)))),
                )
              else
                ...filtered.map((u) {
                  final status = u.accountStatus.toUpperCase();
                  final statusColor = status == 'ACTIVE' ? const Color(0xFF00C48C) : status == 'PENDING' ? const Color(0xFFF2994A) : const Color(0xFFFF4B55);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  u.buildAvatar(radius: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('MEMBER', style: const TextStyle(fontSize: 10, color: Color(0xFFA09DB0), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFFA09DB0)),
                                  onPressed: () => _showUserActionSheet(u),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0EFF5)),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab(List<AuditLogModel> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5CD1).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('SYSTEM AUDIT LOGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D), letterSpacing: 1.0)),
          ),
          const Divider(height: 1, color: Color(0xFFF0EFF5)),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No logs available.', style: TextStyle(color: Color(0xFFA09DB0)))),
            )
          else
            ...logs.map((log) => Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF4F3FA), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.history_rounded, color: Color(0xFF6B5CD1), size: 20),
                  ),
                  title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E1E2D))),
                  subtitle: Text(log.details, style: const TextStyle(color: Color(0xFFA09DB0), fontSize: 12)),
                  trailing: Text(DateFormat('MMM d, hh:mm a').format(log.timestamp), style: const TextStyle(color: Color(0xFFA09DB0), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1, color: Color(0xFFF0EFF5)),
              ],
            )),
        ],
      ),
    );
  }

  Widget _buildAITab(List<UserModel> users, List<CircleModel> circles, List<AuditLogModel> logs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5CD1).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI REPORT GENERATOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D), letterSpacing: 1.0)),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingAI ? null : () => _generateAiReport(users, circles, logs),
              icon: _isGeneratingAI ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGeneratingAI ? 'Generating...' : 'Generate Contextual AI Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5CD1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          

          if (_aiReport.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF0EFF5)),
            const SizedBox(height: 16),
            const Text('GENERATED REPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFA09DB0), letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _aiReport,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E2D), height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── MultiStreamBuilder Helper ──────────────────────────────────────────────

class MultiStreamBuilder extends StatelessWidget {
  final Stream<List<UserModel>> usersStream;
  final Stream<List<CircleModel>> circlesStream;
  final Stream<List<AuditLogModel>> logsStream;
  final Widget Function(BuildContext context, List<UserModel> users, List<CircleModel> circles, List<AuditLogModel> logs) builder;

  const MultiStreamBuilder({
    super.key,
    required this.usersStream,
    required this.circlesStream,
    required this.logsStream,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: usersStream,
      builder: (context, usersSnap) {
        return StreamBuilder<List<CircleModel>>(
          stream: circlesStream,
          builder: (context, circlesSnap) {
            return StreamBuilder<List<AuditLogModel>>(
              stream: logsStream,
              builder: (context, logsSnap) {
                if (usersSnap.connectionState == ConnectionState.waiting || 
                    circlesSnap.connectionState == ConnectionState.waiting || 
                    logsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6B5CD1)));
                }
                return builder(context, usersSnap.data ?? [], circlesSnap.data ?? [], logsSnap.data ?? []);
              },
            );
          },
        );
      },
    );
  }
}