import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get Firebase Auth token
  static Future<String?> getFirebaseToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        print('[AuthService] Firebase token obtained: ${token != null ? 'Yes' : 'No'}');
        return token;
      } else {
        print('[AuthService] No Firebase user found');
        return null;
      }
    } catch (e) {
      print('[AuthService] Error getting Firebase token: $e');
      return null;
    }
  }

  // Get custom token from SharedPreferences (for future use)
  static Future<String?> getCustomToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('custom_token');
      print('[AuthService] Custom token found: ${token != null ? 'Yes' : 'No'}');
      return token;
    } catch (e) {
      print('[AuthService] Error getting custom token: $e');
      return null;
    }
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('[AuthService] User signed out successfully');
    } catch (e) {
      print('[AuthService] Error signing out: $e');
    }
  }
} 