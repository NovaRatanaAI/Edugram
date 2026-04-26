import 'package:flutter/material.dart';
import 'package:edugram/model/users.dart';
import 'package:edugram/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final AuthMethods _authMethods = AuthMethods();

  // Null-safe getter — callers that need a non-null user should check first
  User? get user => _user;

  // Kept for backward compatibility but now asserts clearly if called before login
  User get getUser {
    assert(_user != null, 'getUser called before refreshUser() completed');
    return _user!;
  }

  Future<void> refreshUser() async {
    try {
      _user = await _authMethods.getUserDetails();
    } catch (_) {
      _user = null;
    }
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}

