import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapView extends StatelessWidget {
  final LatLng destination;

  const MapView({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: destination,
        zoom: 14.0,
      ),
      markers: {
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
        ),
      },
    );
  }
}
