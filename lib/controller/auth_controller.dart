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
        await _checkLocationPermission();

        await _updateLocation(user.uid);
        _startLocationUpdates(user.uid);
        // الحصول على مستند المستخدم من قاعدة البيانات
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // التحقق من دور المستخدم
          if (userData['role'] == 'delivery') {
            // الحصول على رمز FCM وتخزينه
            final String? token = await _firebaseMessaging.getToken();

            if (token != null) {
              await _firestore.collection('deliveryWorkers').doc(user.uid).set({
                'fcmToken': token,
              }, SetOptions(merge: true));
            }

            return user;
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
              content: Text('User document does not exist.'),
            ),
          );
          return null;
        }
      }
    } catch (e) {
      print(e);
      // إظهار رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
        ),
      );
      return null;
    }
    return null;
  }

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        throw Exception(
            "User denied permissions to access the device's location.");
      }
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
