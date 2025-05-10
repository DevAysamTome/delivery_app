import 'package:delivery_app/controller/order_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  final VoidCallback? onAccept;
  const OrderDetailsScreen({
    super.key, 
    required this.orderId, 
    required this.userId,
    this.onAccept,
  });

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderController orderController = OrderController();
  late GoogleMapController mapController;
  LocationData? currentLocation;
  List<LatLng> polylineCoordinates = [];
  late LatLng destination;
  bool isOrderAccepted = false;
  bool isOrderReceived = false;
  Location location = Location();
  bool _isTracking = true;
  bool _isManualControl = false;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    checkOrderStatus();
    // Start location updates
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isTracking && !_isManualControl && mounted) {
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
        _isManualControl = false;
        _isTracking = true;
      });
      updateMapCamera();
    }
  }

  @override
  void dispose() {
    location.enableBackgroundMode(enable: false);
    super.dispose();
  }

  Future<void> checkOrderStatus() async {
    try {
      DocumentSnapshot orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (orderDoc.exists) {
        setState(() {
          final orderStatus = orderDoc['orderStatus'] as String? ?? '';
          isOrderAccepted = orderStatus == 'تم التوصيل';
          isOrderReceived = orderStatus == 'تم التوصيل';
        });
      }
    } catch (e) {
      print('Error checking order status: $e');
    }
  }

  void getCurrentLocation() async {
    Location location = Location();
    location.getLocation().then((locationData) {
      setState(() {
        currentLocation = locationData;
        if (currentLocation != null) {
          getPolyline();
        }
      });
    });
  }

  void getPolyline() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(
            currentLocation!.latitude!, currentLocation!.longitude!),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
      googleApiKey: "AIzaSyBzdajHgG7xEXtoglNS42Jbh8NdMUj2DXk",
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
      setState(() {});
    }
  }

  void acceptOrder() async {
    try {
      await orderController.completeDelivery(widget.orderId);
      
      setState(() {
        isOrderAccepted = true;
        isOrderReceived = true;
      });
      
      // Call the onAccept callback if provided
      if (widget.onAccept != null) {
        widget.onAccept!();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب إلى تم التوصيل')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة الطلب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'تفاصيل الطلب',
                style: TextStyle(color: Colors.white),
              ),
              centerTitle: true,
              backgroundColor: Colors.redAccent,
            ),
            body: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .collection('storeOrders')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('الطلب غير موجود'));
                }

                // استرداد مستندات storeOrders
                final storeOrdersDocs = snapshot.data!.docs;
                final firstStoreOrder = storeOrdersDocs.first;
                final storeId = firstStoreOrder['storeId'];
                final orderStatus = firstStoreOrder['orderStatus'] as String? ?? '';

                // التعامل مع بيانات أخرى حسب الحاجة
                final deliveryDetails = firstStoreOrder['deliveryDetails'] as Map<String, dynamic>?;
                final location = deliveryDetails?['location'] as Map<String, dynamic>?;
                final latitude = location?['latitude'] as double? ?? 0.0;
                final longitude = location?['longitude'] as double? ?? 0.0;
                destination = LatLng(latitude, longitude);
                final items = firstStoreOrder['items'] as List<dynamic>? ?? [];

                // يمكن عرض البيانات الآن
                return FutureBuilder<String>(
                  future: orderController.getCustomerName(widget.userId),
                  builder: (context, nameSnapshot) {
                    if (nameSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (nameSnapshot.hasError) {
                      return Center(
                          child: Text(
                              'حدث خطأ أثناء جلب اسم العميل: ${nameSnapshot.error}'));
                    }

                    final customerName =
                        nameSnapshot.data ?? 'Unknown Customer';

                    return FutureBuilder<String>(
                      future: orderController.getCustomerPhone(widget.userId),
                      builder: (context, phoneSnapshot) {
                        if (phoneSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final customerPhone = phoneSnapshot.data ?? 'غير متوفر';

                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Card(
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'رقم الطلب: ${widget.orderId}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'اسم العميل: $customerName',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'رقم الهاتف: $customerPhone',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final Uri phoneUri = Uri(
                                              scheme: 'tel',
                                              path: customerPhone,
                                            );
                                            if (await canLaunchUrl(phoneUri)) {
                                              await launchUrl(phoneUri);
                                            } else {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('لا يمكن فتح تطبيق الهاتف'),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.phone),
                                          label: const Text('اتصال'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'العنوان: ${deliveryDetails?['address'] ?? 'غير متوفر'}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'تكلفة التوصيل: ${deliveryDetails?['cost'] ?? 0} شيكل',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'التكلفة الإجمالية: ${firstStoreOrder['totalPrice'] + deliveryDetails?['cost'] ?? 0} شيكل',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        if ((firstStoreOrder.data() as Map<String, dynamic>?)?.containsKey('notes') == true && 
                                            firstStoreOrder['notes'] != null && 
                                            firstStoreOrder['notes'].toString().isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text(
                                                'ملاحظات العميل:',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.all(8.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                child: Text(
                                                  firstStoreOrder['notes'],
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'تفاصيل الطلب:',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 10),
                                Card(
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: items.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item['mealName']} (${item['quantity']})',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text('سعر: ${item['mealPrice']}'),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'موقع التوصيل:',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 300,
                                  child: Card(
                                    elevation: 4,
                                    child: currentLocation == null
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
                                                    position: destination,
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
                                                  updateMapCamera();
                                                },
                                                onCameraMove: (_) {
                                                  if (_isTracking) {
                                                    setState(() {
                                                      _isManualControl = true;
                                                      _isTracking = false;
                                                    });
                                                  }
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
                                                            _isManualControl = false;
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
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    
                                    if (!isOrderAccepted && !isOrderReceived )
                                      ElevatedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('تم التوصيل'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            )));
  }
}
