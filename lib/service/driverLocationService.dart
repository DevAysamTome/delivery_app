import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class DriverLocationService {

  DriverLocationService();

  Location location = Location();

  void updateDriverLocation() async {
    try {
      location.onLocationChanged.listen((LocationData currentLocation) {
        FirebaseFirestore.instance.collection('deliveryWorkers').doc().set({
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }
}
