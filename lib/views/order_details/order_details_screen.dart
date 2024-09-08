import 'package:delivery_app/controller/order_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  const OrderDetailsScreen({super.key, required this.orderId, required this.userId});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderController orderController = OrderController();
  late GoogleMapController mapController;
  LocationData? currentLocation;
  List<LatLng> polylineCoordinates = [];
  late LatLng destination;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
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
      googleApiKey: "AIzaSyCZvw0hbzT_UthEhywmtjiRk4jssJ1U-zI",
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
      setState(() {});
    }
  }

  void markOrderAsDelivered() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'orderStatus': 'تم التوصيل'});
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

                // الوصول إلى أول مستند (يمكنك التعديل حسب الحاجة)
                final firstStoreOrder = storeOrdersDocs.first;

                // استرداد storeId من المستند
                final storeId = firstStoreOrder['storeId'];

                // التعامل مع بيانات أخرى حسب الحاجة
                final deliveryLocation =
                    firstStoreOrder['userLocation'] as List<dynamic>;
                destination = LatLng(deliveryLocation[0] as double,
                    deliveryLocation[1] as double);
                final items = firstStoreOrder['items'] as List<dynamic>;

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
                                      'اسم العميل: $customerName',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'العنوان: ${firstStoreOrder['placeName'] ?? 'غير متوفر'}',
                                      style: const TextStyle(fontSize: 16),
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
                                    // No need to access item[0] since item is already the map
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
                                    : GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(
                                            currentLocation!.latitude!,
                                            currentLocation!.longitude!,
                                          ),
                                          zoom: 15.0,
                                        ),
                                        markers: {
                                          Marker(
                                            markerId:
                                                const MarkerId('currentLocation'),
                                            position: LatLng(
                                              currentLocation!.latitude!,
                                              currentLocation!.longitude!,
                                            ),
                                            infoWindow: const InfoWindow(
                                                title: 'موقعي الحالي'),
                                          ),
                                          Marker(
                                            markerId: const MarkerId('destination'),
                                            position: destination,
                                            infoWindow: const InfoWindow(
                                                title: 'موقع التوصيل'),
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
                                        onMapCreated:
                                            (GoogleMapController controller) {
                                          mapController = controller;
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton(
                                onPressed: markOrderAsDelivered,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 50.0, vertical: 15.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text(
                                  'تم التوصيل',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            )));
  }
}
