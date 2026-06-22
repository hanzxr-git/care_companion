// cc_profile.dart — with gallery image picker, Elderly Mode, and synced location sharing

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'cc_theme.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';

class ProfileTab extends StatefulWidget {
  final Function(bool) onToggleElder;
  const ProfileTab({super.key, required this.onToggleElder});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  bool _notif = true;
  bool _isUploadingAvatar = false;
  bool _isUpdatingLocation = false;
  late AnimationController _avatarPulse;

  @override
  void initState() {
    super.initState();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _avatarPulse.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    _avatarPulse.repeat(reverse: true);

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final uid = auth.uid;
      if (uid == null) return;
      
      final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();
      
      if (!mounted) return;
      await auth.updateAvatar(downloadUrl);
      if (mounted) C.showSuccess(context, 'Photo Updated', 'Profile photo changed successfully!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update photo. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _avatarPulse.stop();
        _avatarPulse.reset();
      }
    }
  }

  Future<void> _refreshLocation(AuthService auth) async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);

    final locService = context.read<LocationService>();
    final result = await locService.updateCurrentLocation(
      auth.uid!,
      sharing: auth.userModel!.locationSharing,
    );

    if (mounted) {
      setState(() => _isUpdatingLocation = false);
      if (result.success) {
        C.showSuccess(context, 'Location Updated', result.label ?? 'Current location refreshed.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message.isEmpty ? 'Could not get location.' : result.message),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final auth = context.watch<AuthService>();
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.primary)),
      );
    }
    final color = Color(user.avatarColorValue);
    final avatarRadius = e ? 50.0 : 42.0;

    // Avatar handling is now fully encapsulated inside user.buildAvatar()

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── Gradient Hero Header ──────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, e ? 40 : 32, 20, e ? 36 : 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    C.primary.withValues(alpha: 0.85),
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow ring
                      AnimatedBuilder(
                        animation: _avatarPulse,
                        builder: (_, child) => Container(
                          width: avatarRadius * 2 + (_isUploadingAvatar ? 16 + _avatarPulse.value * 12 : 16),
                          height: avatarRadius * 2 + (_isUploadingAvatar ? 16 + _avatarPulse.value * 12 : 16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: _isUploadingAvatar ? 0.15 + _avatarPulse.value * 0.1 : 0.15),
                          ),
                        ),
                      ),
                      // Avatar circle
                      GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAvatar,
                        child: user.buildAvatar(radius: avatarRadius),
                      ),
                      // Edit badge
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isUploadingAvatar
                                ? SizedBox(
                                    width: e ? 16 : 14,
                                    height: e ? 16 : 14,
                                    child: const CircularProgressIndicator(
                                      color: C.primary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt_rounded,
                                    color: C.primary,
                                    size: e ? 18 : 14,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: e ? 18 : 14),

                  // Display Name
                  Text(
                    user.username,
                    style: TextStyle(
                      fontSize: context.fs(C.fH2),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Phone
                  Text(
                    user.phone,
                    style: TextStyle(
                      fontSize: context.fs(C.fSub),
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email!,
                      style: TextStyle(
                        fontSize: context.fs(C.fSub),
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: e ? 16 : 12),

                  // Edit profile button
                  GestureDetector(
                    onTap: () => _showEditProfile(context, auth),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: e ? 22 : 18,
                        vertical: e ? 12 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.white, size: e ? 18 : 14),
                          SizedBox(width: e ? 8 : 6),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: context.fs(C.fSub),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: e ? 28 : 22),

            // ── APPEARANCE SECTION ───────────────────────────────
            _sectionLabel('APPEARANCE', context),
            SizedBox(height: e ? 10 : 8),
            _switchTile(
              icon: Icons.elderly_rounded,
              title: 'Elderly Mode',
              subtitle: 'Makes text and icons larger',
              value: e,
              onChanged: (v) {
                widget.onToggleElder(v);
                auth.setElderMode(v);
              },
              e: e,
              context: context,
            ),

            SizedBox(height: e ? 24 : 18),

            // ── SAFETY & PRIVACY SECTION ────────────────────────
            _sectionLabel('SAFETY & PRIVACY', context),
            SizedBox(height: e ? 10 : 8),
            _switchTile(
              icon: Icons.location_on_outlined,
              title: 'Share Location',
              subtitle: 'Let circle members see your location',
              value: user.locationSharing,
              onChanged: (v) => auth.setLocationSharing(v),
              e: e,
              context: context,
            ),
            SizedBox(height: e ? 10 : 8),

            // Refresh location button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _isUpdatingLocation ? null : () => _refreshLocation(auth),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: e ? 18 : 16,
                    vertical: e ? 16 : 13,
                  ),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: C.textDark.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: C.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isUpdatingLocation
                              ? Icons.hourglass_top_rounded
                              : Icons.my_location_rounded,
                          color: C.primary,
                          size: e ? 22 : 18,
                        ),
                      ),
                      SizedBox(width: e ? 16 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refresh My Location',
                              style: TextStyle(
                                fontSize: context.fs(C.fBody),
                                fontWeight: FontWeight.w700,
                                color: C.textDark,
                              ),
                            ),
                            Text(
                              _isUpdatingLocation
                                  ? 'Getting your location...'
                                  : 'Update your live location now',
                              style: TextStyle(
                                fontSize: context.fs(C.fSub),
                                color: C.textMid,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isUpdatingLocation)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: C.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      else
                        Icon(Icons.chevron_right_rounded,
                            color: C.textLight, size: e ? 24 : 20),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: e ? 24 : 18),

            // ── NOTIFICATIONS SECTION ────────────────────────────
            _sectionLabel('NOTIFICATIONS', context),
            SizedBox(height: e ? 10 : 8),
            _switchTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Receive check-in and SOS alerts',
              value: _notif,
              onChanged: (v) => setState(() => _notif = v),
              e: e,
              context: context,
            ),

            SizedBox(height: e ? 24 : 18),

            // ── SUPPORT SECTION ──────────────────────────────────
            _sectionLabel('SUPPORT', context),
            SizedBox(height: e ? 10 : 8),
            _infoTile(
              icon: Icons.info_outline_rounded,
              title: 'Carely',
              subtitle: 'Family circle wellness app',
              e: e,
              context: context,
            ),
            SizedBox(height: e ? 10 : 8),
            _infoTile(
              icon: Icons.school_outlined,
              title: 'UTeM FTMK — BITU 3973',
              subtitle: 'Final Year Project',
              e: e,
              context: context,
            ),

            SizedBox(height: e ? 32 : 24),

            // ── SIGN OUT BUTTON ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => _confirmSignOut(context, auth),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: e ? 18 : 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.red.withValues(alpha: 0.4)),
                    color: C.red.withValues(alpha: 0.04),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: C.red, size: e ? 24 : 20),
                      SizedBox(width: e ? 10 : 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: context.fs(C.fBody),
                          fontWeight: FontWeight.w800,
                          color: C.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: e ? 40 : 32),
          ],
        ),
      ),
    );
  }

  // ── Edit Profile Bottom Sheet ─────────────────────────────
  void _showEditProfile(BuildContext context, AuthService auth) {
    final nameCtrl = TextEditingController(text: auth.userModel?.username);
    final emailCtrl = TextEditingController(text: auth.userModel?.email ?? '');
    String? gender = auth.userModel?.gender;
    DateTime? birthDate = auth.userModel?.birthDate;
    final e = context.elder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: EdgeInsets.fromLTRB(22, 20, 22, e ? 40 : 32),
              decoration: const BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Drag handle
                Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: e ? 22 : 18),

              Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: context.fs(C.fH2),
                  fontWeight: FontWeight.w900,
                  color: C.textDark,
                ),
              ),
              SizedBox(height: e ? 22 : 18),

              // Pick photo option
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: e ? 18 : 14,
                    vertical: e ? 14 : 11,
                  ),
                  decoration: BoxDecoration(
                    color: C.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded, color: C.primary, size: e ? 22 : 18),
                      SizedBox(width: e ? 12 : 10),
                      Text(
                        'Change Profile Photo',
                        style: TextStyle(
                          fontSize: context.fs(C.fBody),
                          fontWeight: FontWeight.w700,
                          color: C.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: e ? 18 : 14),

              // Display name field label
              Text(
                'USERNAME',
                style: TextStyle(
                  fontSize: context.fs(C.fCap),
                  fontWeight: FontWeight.w800,
                  color: C.textMid,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: e ? 10 : 8),
              TextField(
                controller: nameCtrl,
                style: TextStyle(
                  fontSize: context.fs(C.fBody),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Your full name',
                  filled: true,
                  fillColor: C.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: e ? 18 : 14,
                    vertical: e ? 16 : 12,
                  ),
                ),
              ),
              SizedBox(height: e ? 16 : 12),

              // Email field label
              Text(
                'EMAIL',
                style: TextStyle(
                  fontSize: context.fs(C.fCap),
                  fontWeight: FontWeight.w800,
                  color: C.textMid,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: e ? 10 : 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontSize: context.fs(C.fBody),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'you@email.com',
                  filled: true,
                  fillColor: C.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: e ? 18 : 14,
                    vertical: e ? 16 : 12,
                  ),
                ),
              ),
              SizedBox(height: e ? 16 : 12),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'GENDER',
                    style: TextStyle(
                      fontSize: context.fs(C.fCap),
                      fontWeight: FontWeight.w800,
                      color: C.textMid,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: e ? 10 : 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text('Select', style: TextStyle(color: C.textLight, fontSize: context.fs(C.fBody))),
                        value: gender,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: C.textMid),
                        items: ['Male', 'Female', 'Other'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: C.textDark, fontSize: context.fs(C.fBody))),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setSheetState(() {
                            gender = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ])),
                SizedBox(width: e ? 16 : 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'BIRTH DATE',
                    style: TextStyle(
                      fontSize: context.fs(C.fCap),
                      fontWeight: FontWeight.w800,
                      color: C.textMid,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: e ? 10 : 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: birthDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(data: C.theme, child: child!),
                      );
                      if (picked != null) {
                        setSheetState(() => birthDate = picked);
                      }
                    },
                    child: Container(
                      height: e ? 56 : 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        birthDate == null 
                            ? 'Select date' 
                            : '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}',
                        style: TextStyle(
                          color: birthDate == null ? C.textLight : C.textDark,
                          fontSize: context.fs(C.fBody),
                          fontWeight: birthDate == null ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ])),
              ]),
              SizedBox(height: e ? 26 : 20),

              SizedBox(
                width: double.infinity,
                height: e ? 60 : 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await auth.updateProfile(
                      username: nameCtrl.text.trim().isEmpty
                          ? null
                          : nameCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      gender: gender,
                      birthDate: birthDate,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      C.showSuccess(context, 'Profile Updated', 'Your profile details have been saved successfully.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: context.fs(C.fBody),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService auth) async {
    final e = context.elder;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: context.fs(C.fH2),
            color: C.textDark,
          ),
        ),
        content: Text(
          'You will need to verify your phone number again to sign back in.',
          style: TextStyle(fontSize: context.fs(C.fBody), color: C.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: C.textMid, fontSize: context.fs(C.fBody)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: EdgeInsets.symmetric(
                horizontal: e ? 22 : 18,
                vertical: e ? 14 : 10,
              ),
            ),
            child: Text(
              'Sign Out',
              style: TextStyle(fontSize: context.fs(C.fBody)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Future.delayed(const Duration(milliseconds: 250)); // let dialog close
      await auth.signOut();
      C.showLogOut(messenger, 'Logged Out', 'Hope to see you soon!');
    }
  }

  // ── Reusable UI helpers ───────────────────────────────────

  Widget _sectionLabel(String text, BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: ctx.fs(C.fCap),
        fontWeight: FontWeight.w800,
        color: C.primary,
        letterSpacing: 1.3,
      ),
    ),
  );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool e,
    required BuildContext context,
    bool highlight = false,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    padding: EdgeInsets.symmetric(
      horizontal: e ? 18 : 16,
      vertical: e ? 16 : 13,
    ),
    decoration: BoxDecoration(
      color: highlight ? C.primarySoft : C.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: C.textDark.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlight ? C.primary.withValues(alpha: 0.15) : C.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: highlight ? C.primary : C.textMid,
            size: e ? 22 : 18,
          ),
        ),
        SizedBox(width: e ? 16 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: context.fs(C.fBody),
                  fontWeight: FontWeight.w700,
                  color: C.textDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: context.fs(C.fSub),
                  color: C.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: C.primarySoft,
          activeThumbColor: C.primary,
          inactiveThumbColor: C.textLight,
          inactiveTrackColor: C.divider,
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ],
    ),
  );

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool e,
    required BuildContext context,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    padding: EdgeInsets.symmetric(
      horizontal: e ? 18 : 16,
      vertical: e ? 16 : 13,
    ),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: C.textDark.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: C.textMid, size: e ? 22 : 18),
        ),
        SizedBox(width: e ? 16 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: context.fs(C.fBody),
                  fontWeight: FontWeight.w700,
                  color: C.textDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: context.fs(C.fSub),
                  color: C.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}