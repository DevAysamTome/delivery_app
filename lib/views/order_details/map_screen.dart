import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  final LatLng destination;
  final LatLng? initialLocation;

  const MapScreen({
    Key? key,
    required this.destination,
    this.initialLocation,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LocationData? currentLocation;
  Location location = Location();
  bool _isTracking = false;
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      currentLocation = LocationData.fromMap({
        'latitude': widget.initialLocation!.latitude,
        'longitude': widget.initialLocation!.longitude,
      });
    } else {
      getCurrentLocation();
    }
    // Start location updates
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isTracking && mounted) {
        setState(() {
          this.currentLocation = currentLocation;
          updateMapCamera();
        });
      }
    });
  }

  void updateMapCamera() {
    if (currentLocation != null && mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              currentLocation!.latitude!,
              currentLocation!.longitude!,
            ),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void centerOnCurrentLocation() {
    if (currentLocation != null && mapController != null) {
      setState(() {
        _isTracking = true;
      });
      updateMapCamera();
    }
  }

  void getCurrentLocation() async {
    Location location = Location();
    location.getLocation().then((locationData) {
      setState(() {
        currentLocation = locationData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خريطة التوصيل',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      currentLocation!.latitude!,
                      currentLocation!.longitude!,
                    ),
                    zoom: 15.0,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('currentLocation'),
                      position: LatLng(
                        currentLocation!.latitude!,
                        currentLocation!.longitude!,
                      ),
                      infoWindow: const InfoWindow(title: 'موقعي الحالي'),
                    ),
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: widget.destination,
                      infoWindow: const InfoWindow(title: 'موقع التوصيل'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: polylineCoordinates,
                      color: Colors.blue,
                      width: 5,
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'tracking',
                        onPressed: () {
                          setState(() {
                            _isTracking = !_isTracking;
                            if (_isTracking) {
                              updateMapCamera();
                            }
                          });
                        },
                        backgroundColor: _isTracking ? Colors.green : Colors.grey,
                        child: Icon(
                          _isTracking ? Icons.location_searching : Icons.location_disabled,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'center',
                        onPressed: centerOnCurrentLocation,
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
} 