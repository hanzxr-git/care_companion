// services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

enum AuthStatus {
  unknown,      // app just started, checking auth state
  unauthenticated, // not logged in
  loading,      // logged in, fetching profile from Firestore
  authenticated,   // logged in + profile loaded, ready to show app
}

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirestoreService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  String? _verificationId;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  // Called once at startup — check if already logged in
  Future<void> _init() async {
    final user = _auth.currentUser;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    // Already logged in — load profile
    await _loadProfile(user.uid);
  }

  // Load user profile from Firestore and update status
  Future<void> _loadProfile(String uid) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      _userModel = await _db.getUser(uid);

      if (_userModel != null) {
        _status = AuthStatus.authenticated;
      } else {
        // Profile doesn't exist somehow — sign out to be safe
        await _auth.signOut();
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      await _auth.signOut();
      _userModel = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── STEP 1: Send OTP ────────────────────────────────────
  Future<void> sendOtp({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required Function(String) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto sign-in (Android only) — handle same as manual verify
        await _handleCredential(credential, 'Auto', onError: (e) {});
      },

      verificationFailed: (FirebaseAuthException e) {
        final msg = '${_friendlyError(e.code)}\n[Debug: ${e.code}]';
        _isLoading = false;
        notifyListeners();
        onError(msg);
      },

      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _isLoading = false;
        notifyListeners();
        onCodeSent();
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ─── STEP 2: Verify OTP ──────────────────────────────────
  Future<bool> verifyOtp({
    required String otp,
    required String displayName,
    required Function(String) onError,
  }) async {
    if (_verificationId == null) {
      onError('Session expired. Please request a new code.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    return await _handleCredential(
      credential,
      displayName,
      onError: onError,
    );
  }

  // ─── Core: sign in + create/load profile ─────────────────
  Future<bool> _handleCredential(
    PhoneAuthCredential credential,
    String displayName, {
    required Function(String) onError,
  }) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        _isLoading = false;
        notifyListeners();
        onError('Sign in failed. Please try again.');
        return false;
      }

      // Check if profile exists
      final exists = await _db.userExists(user.uid);

      if (!exists) {
        // NEW USER — create profile
        final phone = user.phoneNumber ?? '';
        final newUser = UserModel(
          uid: user.uid,
          phone: phone,
          displayName: displayName,
          avatarInitials: UserModel.initialsFrom(displayName),
          avatarColorValue: UserModel.colorFrom(phone),
          createdAt: DateTime.now(),
        );
        await _db.createUser(newUser);
        _userModel = newUser;
      } else {
        // RETURNING USER — load profile
        _userModel = await _db.getUser(user.uid);
      }

      _isLoading = false;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      onError('${_friendlyError(e.code)}\n[Debug: ${e.code}]');
      return false;
    } catch (e) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      onError('Unexpected error: $e');
      return false;
    }
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────
  Future<void> updateProfile({String? displayName, String? email}) async {
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['displayName'] = displayName;
      updates['avatarInitials'] = UserModel.initialsFrom(displayName);
    }
    if (email != null) updates['email'] = email;
    await _db.updateUser(uid!, updates);
    _userModel = _userModel?.copyWith(displayName: displayName, email: email);
    notifyListeners();
  }

  // ─── SETTINGS ────────────────────────────────────────────
  Future<void> setElderMode(bool value) async {
    if (uid == null) return;
    await _db.updateUser(uid!, {'elderMode': value});
    _userModel = _userModel?.copyWith(elderMode: value);
    notifyListeners();
  }

  Future<void> setLocationSharing(bool value) async {
    if (uid == null) return;
    await _db.updateUser(uid!, {'locationSharing': value});
    await _db.setLocationSharing(uid!, value);
    _userModel = _userModel?.copyWith(locationSharing: value);
    notifyListeners();
  }

  Future<void> updateAvatar(String base64Image) async {
    if (uid == null) return;
    await _db.updateUser(uid!, {'avatarUrl': base64Image});
    _userModel = _userModel?.copyWith(avatarUrl: base64Image);
    notifyListeners();
  }

  // ─── SIGN OUT ────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    _userModel = null;
    _verificationId = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── ERROR MESSAGES ──────────────────────────────────────
  String _friendlyError(String code) => switch (code) {
    'invalid-phone-number'      => 'Invalid phone number format.',
    'invalid-verification-code' => 'Wrong OTP code. Please try again.',
    'session-expired'           => 'OTP expired. Request a new one.',
    'too-many-requests'         => 'Too many attempts. Please wait.',
    'network-request-failed'    => 'No internet connection.',
    'app-not-authorized'        => 'App not authorized. Check SHA-1 fingerprint.',
    'operation-not-allowed'     => 'Phone sign-in not enabled in Firebase.',
    _                           => 'Something went wrong. Please try again.',
  };
}