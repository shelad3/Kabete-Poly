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
      debugPrint("Error fetching user profile: $e");
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

  Future<void> register(UserProfile profile, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: profile.email,
        password: password,
      );

      final regNo = profile.registrationNumber.toUpperCase();

      try {
        final query = await _firestore
            .collection('users')
            .where('registrationNumber', isEqualTo: regNo)
            .get();

        if (query.docs.isNotEmpty) {
          throw Exception('Registration number already in use');
        }

        bool isActuallyAdmin = profile.email.toLowerCase() == 'sheldonramu8@gmail.com';

        final newUserProfile = UserProfile(
          registrationNumber: regNo,
          fullName: profile.fullName,
          profilePhotoUrl: profile.profilePhotoUrl,
          mobileNumber: profile.mobileNumber,
          email: profile.email,
          isHostelResident: profile.isHostelResident,
          role: isActuallyAdmin ? 'Official' : profile.role,
          designation: profile.designation,
          enrolledClasses: profile.enrolledClasses,
        );

        await _firestore.collection('users').doc(credential.user!.uid).set(newUserProfile.toJson());

        if (profile.enrolledClasses.isNotEmpty) {
          for (String classId in profile.enrolledClasses) {
            final classRef = _firestore.collection('classes').doc(classId);
            final classDoc = await classRef.get();

            if (!classDoc.exists) {
              await classRef.set({
                'id': classId,
                'createdAt': FieldValue.serverTimestamp(),
                'members': [credential.user!.uid],
                'createdBy': credential.user!.uid,
              });
            } else {
              await classRef.update({
                'members': FieldValue.arrayUnion([credential.user!.uid])
              });
            }
          }
        }

        await _fetchUserProfile(credential.user!);
        _isGuest = false;
        AnalyticsService().logSignUp('email');
      } catch (e) {
        await credential.user?.delete();
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
