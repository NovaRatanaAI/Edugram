import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:edugram/model/users.dart' as user_model;
import 'package:edugram/resources/presence_service.dart';
import 'package:edugram/resources/storage_methods.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<user_model.User> getUserDetails() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please log in again.',
      );
    }
    final snap =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final data = Map<String, dynamic>.from(snap.data() ?? {});
    data['uid'] = currentUser.uid;
    data['email'] ??= currentUser.email ?? '';
    return user_model.User.fromMap(data);
  }

  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
    required String bio,
    Uint8List? file,
  }) async {
    String res = 'Some error occurred';
    try {
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        return 'Please fill in all fields.';
      }
      if (file == null) return 'Please choose a profile image.';

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final photoUrl = await StorageMethods().uploadImageToStorage(
        'profilePics',
        file,
        false,
      );

      final user = user_model.User(
        email: email,
        uid: cred.user!.uid,
        photoUrl: photoUrl,
        username: username,
        bio: bio,
        followers: const [],
        following: const [],
      );

      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(user.toJson());
      res = 'success';
    } on FirebaseAuthException catch (err) {
      res = _friendlyAuthError(err);
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return 'Please enter all the fields.';
      }
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return 'success';
    } on FirebaseAuthException catch (err) {
      return _friendlyAuthError(err);
    } catch (err) {
      return err.toString();
    }
  }

  Future<void> signOut() async {
    await PresenceService.instance.setOffline();
    await _auth.signOut();
  }

  Future<void> updateProfilePhoto(String uid, Uint8List photo) async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please log in again.',
      );
    }
    final photoUrl = await StorageMethods().uploadImageToStorage(
      'profilePics',
      photo,
      false,
    );
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'photoUrl': photoUrl});
  }

  Future<String> updateProfile(String uid, String username, String bio) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'username': username,
        'bio': bio,
      });
      return 'success';
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> updateEmail(String uid, String newEmail) async {
    try {
      if (newEmail.isEmpty) return 'Email cannot be empty.';
      if (!newEmail.contains('@')) return 'Enter a valid email address.';
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'Please log in again.';
      await currentUser.verifyBeforeUpdateEmail(newEmail);
      await _firestore.collection('users').doc(uid).update({'email': newEmail});
      return 'success';
    } on FirebaseAuthException catch (err) {
      return _friendlyAuthError(err);
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> updatePassword(
    String uid,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      if (newPassword.length < 6) {
        return 'New password must be at least 6 characters.';
      }
      final user = _auth.currentUser;
      if (user == null) return 'Please log in again.';
      final email = user.email;
      if (email == null || email.isEmpty) return 'Please log in again.';
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return 'success';
    } on FirebaseAuthException catch (err) {
      return _friendlyAuthError(err);
    } catch (err) {
      return err.toString();
    }
  }

  String _friendlyAuthError(FirebaseAuthException err) {
    switch (err.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'requires-recent-login':
        return 'Please log in again before changing this.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

