import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<User?> signIn(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          print("User role: ${userData['role']}");
          if (userData['role'] == 'delivery') {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('deliveryWorkerId', user.uid);
            String? token;

            // For iOS, fetch the APNs token repeatedly until it's available
            if (Platform.isIOS) {
              await FirebaseMessaging.instance.requestPermission();
              NotificationSettings settings =
                  await FirebaseMessaging.instance.requestPermission(
                alert: true,
                badge: true,
                sound: true,
              );

              if (settings.authorizationStatus ==
                  AuthorizationStatus.authorized) {
                print('User granted permission for notifications');
              } else {
                print(
                    'User declined or has not accepted notification permission');
              }
              await Future.delayed(Duration(seconds: 2));

              const int maxAttempts = 5;
              const Duration delay = Duration(seconds: 3);
              int attempts = 0;

              while (token == null && attempts < maxAttempts) {
                token = await _firebaseMessaging.getToken();
                if (token == null) {
                  print("APNs token not available, retrying...");
                  attempts++;
                  await Future.delayed(delay);
                }
              }

              if (token == null) {
                print(
                    "Failed to retrieve APNs token after $maxAttempts attempts.");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to retrieve APNs token.'),
                  ),
                );
                return null;
              }
            } else {
              // For Android, simply get the FCM token
              token = await _firebaseMessaging.getToken();
            }

            print("Token used for push notifications: $token");

            // التحقق من إذن الموقع وتحديثه
            await _checkLocationPermission(context);
            await _updateLocation(user.uid);

            // إذا فشل الحصول على الموقع، إظهار رسالة توضيحية
            if (!await _locationEnabled()) {
              _showLocationError(context);
              return null;
            }

            _startLocationUpdates(user.uid);

            // Store FCM or APNs token in Firestore
            await _firestore.collection('deliveryWorkers').doc(user.uid).set({
              'fcmToken': token,
            }, SetOptions(merge: true));

            return user;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. User is not a delivery worker.'),
              ),
            );
            await _auth.signOut();
            return null;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User document does not exist or is empty.'),
            ),
          );
          return null;
        }
      }
    } catch (e) {
      print("Error during sign-in: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return null;
    }
  }

  Future<void> _checkLocationPermission(BuildContext context) async {
    try {
      PermissionStatus status = await Permission.locationWhenInUse.status;
      print("Current status: $status");

      if (!status.isGranted) {
        status = await Permission.locationWhenInUse.request();

        print("Requesting permission");
        status = await Permission.locationWhenInUse.request();
        print("Permission status after request: $status");
      }
    } catch (e) {
      print("Error checking location permission: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to get location permissions. Please check your settings.'),
        ),
      );
      rethrow;
    }
  }

  Future<void> _updateLocation(String uid) async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    await _firestore.collection('deliveryWorkers').doc(uid).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
    }, SetOptions(merge: true));
  }

  Future<bool> _locationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  void _showLocationError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'خدمات الموقع معطلة. لا يمكن إكمال تسجيل الدخول بدون تفعيل الموقع.'),
      ),
    );
  }

  void _startLocationUpdates(String uid) {
    Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // المسافة بالامتار لتحديث الموقع
    )).listen((Position position) {
      _firestore.collection('deliveryWorkers').doc(uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }, SetOptions(merge: true));
    });
  }
}
