import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:delivery_app/firebase_options.dart';
import 'package:delivery_app/res/components/notification_handler.dart';
import 'package:delivery_app/views/home/home_screen.dart';
import 'package:delivery_app/views/login_views/login_view.dart';
import 'package:delivery_app/views/profile/profile_screen.dart';
import 'package:delivery_app/views/weclome_screen/welcome_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestTrackingPermission();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Notification handler instance
  NotificationHandler notificationHandler = NotificationHandler();

  if (!kIsWeb && Platform.isIOS) {
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

    if (apnsToken != null) {
      print("APNs Token: $apnsToken");
    } else {
      await Future<void>.delayed(const Duration(seconds: 5));

      apnsToken = await FirebaseMessaging.instance.getAPNSToken();

      if (apnsToken != null) {
        print("APNs Token after retry: $apnsToken");
      } else {
        print("Failed to retrieve APNs token after second attempt.");
      }
    }
  } else {
    print("This platform does not support APNs.");
  }

  runApp(MyApp(notificationHandler: notificationHandler)); // Pass the handler
}

Future<void> requestTrackingPermission() async {
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  if (status == TrackingStatus.notDetermined) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
  // Only proceed with tracking if the user grants permission
  if (status == TrackingStatus.authorized) {
    // Start tracking as per your app logic
  }
}

class MyApp extends StatelessWidget {
  final NotificationHandler notificationHandler;

  MyApp(
      {super.key,
      required this.notificationHandler}); // Constructor to pass handler

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery App',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Elmassry'),
      initialRoute: '/home',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
