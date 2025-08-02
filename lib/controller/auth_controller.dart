import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/delivery_person.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<User?> signIn(
      String email, String password, BuildContext context) async {
    try {
      print('[AuthController] Attempting Firebase sign-in for $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      print('[AuthController] Firebase sign-in result: user=${user?.uid}');

      if (user != null) {
        // Check if user is a delivery worker using MongoDB API
        try {
          print('[AuthController] Checking delivery worker in backend for UID: ${user.uid}');
          final deliveryWorker = await ApiService.getDeliveryWorker(user.uid);
          print('[AuthController] Delivery worker lookup result: $deliveryWorker');
          
          if (deliveryWorker != null) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('deliveryWorkerId', user.uid);
            await prefs.setBool('isLoggedIn', true);

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

            // Check location permission and update it
            await _checkLocationPermission(context);
            await _updateLocation(user.uid);

            // If location service is disabled, show error message
            if (!await _locationEnabled()) {
              _showLocationError(context);
              return null;
            }

            _startLocationUpdates(user.uid);

            // Store FCM or APNs token in MongoDB
            await ApiService.updateDeliveryWorkerToken(user.uid, token ?? '');

            // Navigate to home screen after successful login
            Navigator.pushReplacementNamed(context, '/home');
            return user;
          } else {
            print('[AuthController] Access denied: No delivery worker found for UID: ${user.uid}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. User is not a delivery worker.'),
              ),
            );
            await _auth.signOut();
            return null;
          }
        } catch (e) {
          print("[AuthController] Error checking delivery worker status: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking user permissions: $e'),
            ),
          );
          return null;
        }
      }
    } catch (e) {
      print("[AuthController] Error during sign-in: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return null;
    }
    print('[AuthController] signIn() reached end without returning user.');
    return null;
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
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await ApiService.updateDeliveryWorkerLocation(
        uid,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print("Error updating location: $e");
      rethrow;
    }
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
      distanceFilter: 10, // Distance in meters to update location
    )).listen((Position position) {
      ApiService.updateDeliveryWorkerLocation(
        uid,
        position.latitude,
        position.longitude,
      );
    });
  }
}
