import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
        // الحصول على مستند المستخدم من قاعدة البيانات
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // التحقق من دور المستخدم
          print("User role: ${userData['role']}");
          if (userData['role'] == 'delivery') {
            // الحصول على رمز FCM وتخزينه
            final String? token = await _firebaseMessaging.getToken();
            if (token != null) {
              print("FCM Token: $token");
              await _checkLocationPermission(context);
              await _updateLocation(user.uid);
              _startLocationUpdates(user.uid);

              await _firestore.collection('deliveryWorkers').doc(user.uid).set({
                'fcmToken': token,
              }, SetOptions(merge: true));

              return user;
            } else {
              print("Failed to retrieve FCM token.");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to retrieve FCM token.'),
                ),
              );
              return null;
            }
          } else {
            // إظهار رسالة خطأ
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. User is not a delivery worker.'),
              ),
            );
            await _auth.signOut(); // تسجيل خروج المستخدم
            return null;
          }
        } else {
          // إظهار رسالة خطأ
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

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // تسجيل تفاصيل المستخدم في Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': 'delivery',
        });

        // الحصول على رمز FCM وتخزينه
        final String? token = await _firebaseMessaging.getToken();

        if (token != null) {
          await _firestore.collection('deliveryWorkers').doc(user.uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }
      }

      return user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
