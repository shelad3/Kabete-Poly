import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import 'push_notification_service.dart';
import 'analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserProfile? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get currentUserId => _auth.currentUser?.uid ?? '';

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _fetchUserProfile(user);
      } else {
        _currentUser = null;
        _isAuthenticated = false;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _fetchUserProfile(User user) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser = UserProfile.fromJson(doc.data() as Map<String, dynamic>);
        
        // Automatic Admin Check (Runtime Override just in case)
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
        // Document doesn't exist (e.g., mid-registration or early Google Sign-In)
        // Set a highly temporary in-memory session only. NEVER write to Firestore here.
        // Wait for register() to complete its own structured Firestore payload.
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
      // Fallback if Firestore fails completely
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
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      AnalyticsService().logLogin('google');
      // _fetchUserProfile will handle creating doc if new
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


  Future<void> register(UserProfile profile, String password) async {
    try {
      // 1. Create a user account in Firebase Auth
      // This MUST happen before checking Firestore, so the user passes the isAuthenticated() rule
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: profile.email,
        password: password,
      );

      final regNo = profile.registrationNumber.toUpperCase();
      
      try {
        // Now that the user is authenticated, we can read the users collection
        final query = await _firestore
            .collection('users')
            .where('registrationNumber', isEqualTo: regNo)
            .get();
            
        if (query.docs.isNotEmpty) {
          throw Exception('Registration number already in use');
        }

        bool isActuallyAdmin = profile.email.toLowerCase() == 'sheldonramu8@gmail.com';

        // 2. Prepare the expanded User Profile data
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

        // 3. Save the profile data to Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set(newUserProfile.toJson());

        // 4. Auto-Generate Class Cohort if needed
        if (profile.enrolledClasses.isNotEmpty) {
          for (String classId in profile.enrolledClasses) {
            final classRef = _firestore.collection('classes').doc(classId);
            final classDoc = await classRef.get();
            
            if (!classDoc.exists) {
              // Create the class cohort infrastructure
              await classRef.set({
                'id': classId,
                'createdAt': FieldValue.serverTimestamp(),
                'members': [credential.user!.uid],
                'createdBy': credential.user!.uid,
              });
            } else {
              // Just add the user to the existing members list
              await classRef.update({
                'members': FieldValue.arrayUnion([credential.user!.uid])
              });
            }
          }
        }

        // 5. Reload profile from Firestore (race condition: auth listener may have
        //    loaded a fallback before Firestore write completed)
        await _fetchUserProfile(credential.user!);
        AnalyticsService().logSignUp('email');
      } catch (e) {
        // Rollback Firebase Auth creation if any Firestore requirement fails
        await credential.user?.delete();
        rethrow; // Pass error up
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
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
