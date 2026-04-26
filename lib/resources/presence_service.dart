import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  Timer? _heartbeatTimer;
  String? _activeUid;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen((user) async {
      final previousUid = _activeUid;
      if (previousUid != null && previousUid != user?.uid) {
        await setOffline(previousUid);
      }
      _activeUid = user?.uid;
      if (user != null) {
        await setOnline(user.uid);
      }
    });
  }

  Future<void> setOnline([String? uid]) async {
    final targetUid = uid ?? _activeUid ?? _auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return;
    await _firestore.collection('users').doc(targetUid).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _startHeartbeat(targetUid);
  }

  Future<void> setOffline([String? uid]) async {
    final targetUid = uid ?? _activeUid ?? _auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return;
    _stopHeartbeat();
    await _firestore.collection('users').doc(targetUid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _startHeartbeat(String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(
        _firestore.collection('users').doc(uid).set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(setOnline());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(setOffline());
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await setOffline();
    await _authSubscription?.cancel();
    _stopHeartbeat();
    _authSubscription = null;
    _started = false;
  }
}
