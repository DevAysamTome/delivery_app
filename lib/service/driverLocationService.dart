import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class DriverLocationService {
  DriverLocationService();

  Location location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void updateDriverLocation() async {
    try {
      location.onLocationChanged.listen((LocationData currentLocation) async {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          await ApiService.updateDeliveryWorkerLocation(
            userId,
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
        }
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Stop location updates
  void stopLocationUpdates() {
    location.enableBackgroundMode(enable: false);
  }

  // Start location updates
  void startLocationUpdates() {
    location.enableBackgroundMode(enable: true);
    updateDriverLocation();
  }
}
