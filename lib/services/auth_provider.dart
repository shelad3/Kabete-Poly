import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_profile.dart';
import '../models/user_session.dart';
import 'push_notification_service.dart';
import 'analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  StreamSubscription<User?>? _authSubscription;

  UserProfile? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isGuest = false;
  String? _currentSessionId;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  String? get currentSessionId => _currentSessionId;

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _fetchUserProfile(user);
        if (_isAuthenticated) {
          await _createSession(user.uid);
        }
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _currentSessionId = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return {
          'name': '${info.brand} ${info.model}',
          'type': 'Android ${info.version.release}',
        };
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return {
          'name': '${info.name} (${info.model})',
          'type': 'iOS ${info.systemVersion}',
        };
      }
    } catch (_) {}
    return {'name': 'Unknown Device', 'type': 'Unknown'};
  }

  Future<void> _createSession(String userId) async {
    try {
      final device = await _getDeviceInfo();
      final session = UserSession(
        id: '',
        userId: userId,
        deviceName: device['name']!,
        deviceType: device['type']!,
        loginAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isCurrentDevice: true,
      );
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .add(session.toJson());
      _currentSessionId = doc.id;
    } catch (e) {
      debugPrint('Session creation failed (non-fatal): $e');
    }
  }

  Future<void> terminateSession(String sessionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(sessionId)
        .delete();
  }

  Future<void> terminateOtherSessions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      if (doc.id != _currentSessionId) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  Stream<List<UserSession>> getSessionsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('loginAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
          final s = UserSession.fromJson(d.data(), d.id);
          return UserSession(
            id: s.id,
            userId: s.userId,
            deviceName: s.deviceName,
            deviceType: s.deviceType,
            ipAddress: s.ipAddress,
            location: s.location,
            loginAt: s.loginAt,
            lastActiveAt: s.lastActiveAt,
            isCurrentDevice: d.id == _currentSessionId,
          );
        }).toList());
  }

  Future<void> _fetchUserProfile(User user) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser = UserProfile.fromJson(doc.data() as Map<String, dynamic>);

        if (_currentUser?.email.toLowerCase() == 'sheldonramu8@gmail.com') {
           _currentUser = UserProfile(
            registrationNumber: _currentUser!.registrationNumber,
            fullName: _currentUser!.fullName,
            profilePhotoUrl: _currentUser!.profilePhotoUrl,
            mobileNumber: _currentUser!.mobileNumber,
            email: _currentUser!.email,
            isHostelResident: _currentUser!.isHostelResident,
            role: 'Official',
          );
        }

      } else {
        _currentUser = UserProfile(
          registrationNumber: 'PENDING-${user.uid.substring(0, 5)}',
          fullName: user.displayName ?? 'Student',
          profilePhotoUrl: user.photoURL ?? '',
          mobileNumber: '',
          email: user.email ?? '',
          isHostelResident: false,
          role: (user.email?.toLowerCase() == 'sheldonramu8@gmail.com') ? 'Official' : 'Student',
          enrolledClasses: [],
        );
      }
      _isAuthenticated = true;
      PushNotificationService().saveTokenToFirestore(user.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _currentUser = UserProfile(
        registrationNumber: 'UNKNOWN',
        fullName: 'Offline User',
        profilePhotoUrl: '',
        mobileNumber: '',
        email: user.email ?? '',
        isHostelResident: false,
        enrolledClasses: [],
      );
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isGuest = false;
      AnalyticsService().logLogin('email');
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception(e.message ?? 'Login failed');
      }
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isGuest = false;
      AnalyticsService().logLogin('google');
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email. Please verify if the email is correct.');
    }
  }

  void enterGuestMode() {
    _currentUser = null;
    _isAuthenticated = true;
    _isGuest = true;
    _isLoading = false;
    notifyListeners();
  }

  void exitGuestMode() {
    _isGuest = false;
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _reserveField(String prefix, String value, String uid) async {
    await _firestore.collection('field_indices').doc('${prefix}_$value').set({
      'uid': uid,
      'value': value,
      'type': prefix,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _releaseField(String prefix, String value) async {
    try {
      await _firestore.collection('field_indices').doc('${prefix}_$value').delete();
    } catch (_) {}
  }

  Future<void> register(UserProfile profile, String password) async {
    try {
      final regNo = profile.registrationNumber.toUpperCase().trim();
      final phone = profile.mobileNumber.trim();
      final email = profile.email.trim().toLowerCase();

      if (regNo.isEmpty) throw Exception('Registration number is required');
      if (phone.isEmpty) throw Exception('Mobile number is required');

      // Atomic uniqueness check via field_indices collection
      final regNoKey = 'regNo_$regNo';
      final phoneKey = 'phone_$phone';
      final emailKey = 'email_$email';

      await _firestore.runTransaction((transaction) async {
        final regNoRef = _firestore.collection('field_indices').doc(regNoKey);
        final phoneRef = _firestore.collection('field_indices').doc(phoneKey);
        final emailRef = _firestore.collection('field_indices').doc(emailKey);

        final regNoSnap = await transaction.get(regNoRef);
        if (regNoSnap.exists) {
          throw Exception('Registration number "$regNo" is already registered');
        }

        final phoneSnap = await transaction.get(phoneRef);
        if (phoneSnap.exists) {
          throw Exception('Phone number "$phone" is already registered');
        }

        final emailSnap = await transaction.get(emailRef);
        if (emailSnap.exists) {
          throw Exception('Email "$email" is already registered');
        }

        // Reserve all three in the transaction
        transaction.set(regNoRef, {
          'uid': '__pending__',
          'value': regNo,
          'type': 'regNo',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(phoneRef, {
          'uid': '__pending__',
          'value': phone,
          'type': 'phone',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(emailRef, {
          'uid': '__pending__',
          'value': email,
          'type': 'email',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Create Firebase Auth user
      UserCredential credential;
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // Auth failed — release reserved indices
        await _releaseField('regNo', regNo);
        await _releaseField('phone', phone);
        await _releaseField('email', email);
        rethrow;
      }

      final uid = credential.user!.uid;

      try {
        bool isActuallyAdmin = email == 'sheldonramu8@gmail.com';

        final newUserProfile = UserProfile(
          registrationNumber: regNo,
          fullName: profile.fullName,
          profilePhotoUrl: profile.profilePhotoUrl,
          mobileNumber: phone,
          email: email,
          isHostelResident: profile.isHostelResident,
          role: isActuallyAdmin ? 'Official' : profile.role,
          designation: profile.designation,
          enrolledClasses: profile.enrolledClasses,
        );

        await _firestore.collection('users').doc(uid).set(newUserProfile.toJson());

        // Update reserved indices with actual UID
        await _firestore.collection('field_indices').doc(regNoKey).update({'uid': uid});
        await _firestore.collection('field_indices').doc(phoneKey).update({'uid': uid});
        await _firestore.collection('field_indices').doc(emailKey).update({'uid': uid});

        if (profile.enrolledClasses.isNotEmpty) {
          for (String classId in profile.enrolledClasses) {
            final classRef = _firestore.collection('classes').doc(classId);
            final classDoc = await classRef.get();

            if (!classDoc.exists) {
              await classRef.set({
                'id': classId,
                'createdAt': FieldValue.serverTimestamp(),
                'members': [uid],
                'createdBy': uid,
              });
            } else {
              await classRef.update({
                'members': FieldValue.arrayUnion([uid])
              });
            }
          }
        }

        await _fetchUserProfile(credential.user!);
        _isGuest = false;
        AnalyticsService().logSignUp('email');
      } catch (e) {
        // Cleanup on failure
        try { await credential.user?.delete(); } catch (_) {}
        await _releaseField('regNo', regNo);
        await _releaseField('phone', phone);
        await _releaseField('email', email);
        rethrow;
      }

    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception(e.message ?? 'Registration failed');
      }
      rethrow;
    }
  }

  Future<void> refreshUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _fetchUserProfile(user);
    }
  }

  Future<void> logout() async {
    final userId = _auth.currentUser?.uid;
    if (_currentSessionId != null && userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('sessions')
            .doc(_currentSessionId)
            .delete();
      } catch (_) {}
    }
    _currentSessionId = null;
    _isGuest = false;
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
