import 'package:delivery_app/controller/order_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_app/views/order_details/map_screen.dart';
import '../../services/api_service.dart';

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
  GoogleMapController? mapController;
  LocationData? currentLocation;
  List<LatLng> polylineCoordinates = [];
  late LatLng destination;
  bool isOrderAccepted = false;
  bool isOrderReceived = false;
  Location location = Location();
  bool _isTracking = true;
  bool _isManualControl = false;
  Map<String, String> storeNames = {};

  @override
  void initState() {
    super.initState();
    print('OrderDetailsScreen initialized with orderId: ${widget.orderId}');
    print('OrderDetailsScreen initialized with userId: ${widget.userId}');
    getCurrentLocation();
    // Remove checkOrderStatus() call since we're using StreamBuilder now
    // Start location updates with throttling
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isTracking && !_isManualControl && mounted) {
        // Only update every 5 seconds to reduce unnecessary refreshes
        setState(() {
          this.currentLocation = currentLocation;
          // Don't update map camera on every location change to reduce CPU usage
        });
      }
    });
  }

  void updateMapCamera() {
    if (currentLocation != null && mapController != null && _isTracking) {
      mapController!.animateCamera(
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
      // Use ApiService to get store order details
      final storeOrders = await ApiService.getStoreOrdersByMainOrderIdRaw(int.parse(widget.orderId));
      if (storeOrders.isNotEmpty) {
        final orderStatus = storeOrders.first['orderStatus'] as String? ?? '';
        setState(() {
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
      print('Error completing delivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة الطلب')),
      );
    }
  }

  Future<Map<String, dynamic>?> getStoreById(String storeId) async {
    // Try restaurant
    final restaurant = await ApiService.getStoreDetails(storeId, 'restaurants');
    if (restaurant != null) return restaurant;
    // Try beverage store
    final beverage = await ApiService.getStoreDetails(storeId, 'beveragestores');
    if (beverage != null) return beverage;
    // Try sweet store
    final sweet = await ApiService.getStoreDetails(storeId, 'sweetstores');
    if (sweet != null) return sweet;
    return null;
  }

  Future<String> getStoreName(String storeId) async {
    if (storeNames.containsKey(storeId)) {
      return storeNames[storeId]!;
    }
    try {
      final store = await getStoreById(storeId);
      if (store != null) {
        String storeName = store['name'] as String? ?? 'متجر غير معروف';
        storeNames[storeId] = storeName;
        return storeName;
      }
      return 'متجر غير معروف';
    } catch (e) {
      print('Error fetching store name: $e');
      return 'متجر غير معروف';
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      // Force refresh by triggering a rebuild
                    });
                  },
                  tooltip: 'تحديث',
                ),
              ],
            ),
            body: FutureBuilder<List<Map<String, dynamic>>>(
              future: () async {
                print('Fetching order details for orderId: ${widget.orderId}');
                try {
                  // Try the store orders API first
                  final result = await ApiService.getStoreOrdersByMainOrderIdRaw(int.parse(widget.orderId));
                  print('Order details result: ${result.length} items');
                  if (result.isNotEmpty) {
                    print('First item: ${result.first}');
                    return result;
                  } else {
                    print('No store orders found, trying main order API...');
                    // Fallback: try to get the main order
                    final order = await ApiService.getOrderById(widget.orderId);
                    print('Main order found: ${order.toJson()}');
                    
                    // Convert to store order format
                    return [{
                      'storeId': order.storeId,
                      'items': order.items,
                      'totalPrice': order.totalPrice,
                      'status': order.orderStatus,
                      'deliveryDetails': {
                        'address': order.deliveryAddress,
                        'cost': order.deliveryCost,
                        'location': order.deliveryLocation,
                      },
                    }];
                  }
                } catch (e) {
                  print('Error in FutureBuilder: $e');
                  rethrow;
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('[OrderDetailsScreen] Error loading order details: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'حدث خطأ في تحميل تفاصيل الطلب',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'رقم الطلب: ${widget.orderId}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'الطلب غير موجود',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'رقم الطلب: ${widget.orderId}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // Force refresh
                            });
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                // Get store orders data
                final storeOrdersData = snapshot.data!;
                
                // Get delivery details from the first store order (since delivery details are the same for all)
                final firstStoreOrder = storeOrdersData.first;
                final deliveryDetails = firstStoreOrder['deliveryDetails'] as Map<String, dynamic>?;
                final location = deliveryDetails?['location'] as Map<String, dynamic>?;
                final latitude = location?['latitude'] as double? ?? 0.0;
                final longitude = location?['longitude'] as double? ?? 0.0;
                destination = LatLng(latitude, longitude);

                // Calculate total price from all store orders
                double totalPrice = 0;
                for (var storeOrder in storeOrdersData) {
                  totalPrice += (storeOrder['totalPrice'] as num?)?.toDouble() ?? 0;
                }
                // Add delivery cost
                totalPrice += (deliveryDetails?['cost'] as num?)?.toDouble() ?? 0;

                // Get delivery address
                final deliveryAddress = deliveryDetails?['address'] as String? ?? 'غير متوفر';
                final deliveryCost = (deliveryDetails?['cost'] as num?)?.toDouble() ?? 0.0;

                // يمكن عرض البيانات الآن
                return FutureBuilder<String>(
                  future: orderController.getCustomerName(widget.userId),
                  builder: (context, nameSnapshot) {
                    if (nameSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (nameSnapshot.hasError) {
                      return Center(
                          child: Text(
                              'حدث خطأ أثناء جلب اسم العميل: ${nameSnapshot.error}'));
                    }

                    final customerName = nameSnapshot.data ?? 'Unknown Customer';

                    return FutureBuilder<String>(
                      future: orderController.getCustomerPhone(widget.userId),
                      builder: (context, phoneSnapshot) {
                        if (phoneSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final customerPhone = phoneSnapshot.data ?? 'غير متوفر';

                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Info Card
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
                                          'العنوان: $deliveryAddress',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'تكلفة التوصيل: ${deliveryCost.toStringAsFixed(2)} شيكل',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'التكلفة الإجمالية: ${totalPrice.toStringAsFixed(2)} شيكل',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
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
                                // Store Orders
                                ...storeOrdersData.map((storeOrder) {
                                  final items = storeOrder['items'] as List<dynamic>? ?? [];
                                  final storeTotal = (storeOrder['totalPrice'] as num?)?.toDouble() ?? 0;
                                  final storeId = storeOrder['storeId'] as String? ?? '';
                                  
                                  return Card(
                                    elevation: 4,
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FutureBuilder<String>(
                                            future: getStoreName(storeId),
                                            builder: (context, storeSnapshot) {
                                              return Text(
                                                storeSnapshot.data ?? 'جاري التحميل...',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.redAccent,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          ...items.map((item) {
                                            print( item['mealName']);
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${item['mealName']} (${item['quantity']})',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text('سعر: ${(item['mealPrice'] as num?)?.toDouble() ?? 0} شيكل'),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          const Divider(),
                                          Text(
                                            'المجموع الفرعي: ${storeTotal.toStringAsFixed(2)} شيكل',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 10),
                                Text(
                                  'موقع التوصيل:',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 10),
                                Card(
                                  elevation: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'العنوان: $deliveryAddress',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => MapScreen(
                                                    destination: destination,
                                                    initialLocation: currentLocation != null
                                                        ? LatLng(
                                                            currentLocation!.latitude!,
                                                            currentLocation!.longitude!,
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.map),
                                            label: const Text('فتح الخريطة'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
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
                                    if (!isOrderAccepted && !isOrderReceived)
                                      ElevatedButton.icon(
                                        onPressed: acceptOrder,
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('تم التوصيل'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
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

