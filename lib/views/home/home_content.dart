import 'package:delivery_app/controller/order_controller.dart';
import 'package:delivery_app/controller/delivery_person_controller.dart';
import 'package:delivery_app/models/delivery_person.dart';
import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final OrderController _orderController = OrderController();
  final DeliveryPersonController _deliveryPersonController = DeliveryPersonController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Availability Toggle Button
        StreamBuilder<DeliveryPerson>(
          stream: _deliveryPersonController.getDeliveryPersonStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final isAvailable = snapshot.data?.isAvailable ?? false;
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'حالة التواجد',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: isAvailable,
                        onChanged: (bool value) {
                          _deliveryPersonController.updateAvailabilityStatus(value);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Statistics Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: _orderController.getNewInProgressOrdersCount(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildCard('الطلبات الجديدة', 'جاري التحميل...');
                        } else if (snapshot.hasError) {
                          print('Error in new orders stream: ${snapshot.error}');
                          return _buildCard('الطلبات الجديدة', 'خطأ');
                        } else if (!snapshot.hasData) {
                          return _buildCard('الطلبات الجديدة', '0');
                        } else {
                          return _buildCard('الطلبات الجديدة', snapshot.data.toString());
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: _orderController.getOnGoingInProgressOrdersCount(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildCard('الطلبات قيد التوصيل', 'جاري التحميل...');
                        } else if (snapshot.hasError) {
                          print('Error in ongoing orders stream: ${snapshot.error}');
                          return _buildCard('الطلبات قيد التوصيل', 'خطأ');
                        } else if (!snapshot.hasData) {
                          return _buildCard('الطلبات قيد التوصيل', '0');
                        } else {
                          return _buildCard('الطلبات قيد التوصيل', snapshot.data.toString());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Recent Orders Section
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الطلبات الحديثة',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildOrdersList(),
        ),
      ],
    );
  }

  Widget _buildCard(String title, String value) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _orderController.getOrdersDetailsWithMainFields(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error in orders stream: ${snapshot.error}');
          return Center(
            child: Text('حدث خطأ: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || 
            snapshot.data == null || 
            snapshot.data!['mainOrder'] == null || 
            (snapshot.data!['storeOrders'] as List<Map<String, dynamic>>).isEmpty) {
          return const Center(
            child: Text(
              'لا توجد طلبات متاحة حالياً',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final mainOrder = snapshot.data!['mainOrder'] as Map<String, dynamic>;
        final storeOrders = snapshot.data!['storeOrders'] as List<Map<String, dynamic>>;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: storeOrders.length,
          itemBuilder: (context, index) {
            final storeOrder = storeOrders[index];
            final userId = mainOrder['userId'] as String? ?? '';
            final deliveryDetails = storeOrder['deliveryDetails'] as Map<String, dynamic>?;
            final address = deliveryDetails?['address'] as String? ?? 'غير متوفر';
            final deliveryCost = deliveryDetails?['cost'] as num? ?? 0;
            final location = deliveryDetails?['location'] as Map<String, dynamic>?;
            final time = deliveryDetails?['time'] as num? ?? 0;
            final totalPrice = storeOrder['totalPrice'] as num? ?? 0;
            final orderCost = totalPrice ;
            final totalCost = totalPrice + deliveryCost;
            return FutureBuilder<String>(
              future: _orderController.getCustomerName(userId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildOrderCard(
                    'جاري التحميل...',
                    'العنوان: $address\nتكلفة التوصيل: $deliveryCost شيكل\nتكلفة الطلب: $orderCost شيكل\nالتكلفة الإجمالية: $totalCost شيكل\nالوقت المتوقع: $time دقيقة',
                    Colors.grey,
                    orderId: mainOrder['orderId'] as String,
                    userId: userId,
                  );
                }

                if (userSnapshot.hasError || !userSnapshot.hasData) {
                  return _buildOrderCard(
                    'خطأ في جلب اسم العميل',
                    'العنوان: $address\nتكلفة التوصيل: $deliveryCost شيكل\nتكلفة الطلب: $orderCost شيكل\nالتكلفة الإجمالية: $totalCost شيكل\nالوقت المتوقع: $time دقيقة',
                    Colors.redAccent,
                    orderId: mainOrder['orderId'] as String,
                    userId: userId,
                  );
                }

                final customerName = userSnapshot.data ?? 'غير معروف';

                return _buildOrderCard(
                  customerName,
                  'العنوان: $address\nتكلفة التوصيل: $deliveryCost شيكل\nتكلفة الطلب: $orderCost شيكل\nالتكلفة الإجمالية: $totalCost شيكل\nالوقت المتوقع: $time دقيقة',
                  Colors.white,
                  orderId: mainOrder['orderId'] as String,
                  userId: userId,
                  onAccept: () async {
                    await _orderController.acceptOrder(
                        mainOrder['orderId'] as String, userId);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
    String customerName,
    String address,
    Color cardColor, {
    required String orderId,
    required String userId,
    VoidCallback? onAccept,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        final String orderStatus = snapshot.hasData ? 
            (snapshot.data?.get('orderStatus') as String? ?? '') : '';
        
        final bool isAccepted = orderStatus == 'تم اخذ الطلب';
        final bool isReceived = orderStatus == 'عامل التوصيل قد استلم الطلب';
        final bool isInDelivery = orderStatus == 'جاري التوصيل';
        final bool isDelivered = orderStatus == 'تم التوصيل';
        
        // Check if order is assigned by admin
        final bool isAssignedByAdmin = snapshot.hasData && 
            snapshot.data!.exists && 
            snapshot.data!.data() != null && 
            (snapshot.data!.data() as Map<String, dynamic>).containsKey('assignedTo') &&
            snapshot.data!.get('assignedTo') == _auth.currentUser?.uid;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
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
                  address,
                  style: const TextStyle(fontSize: 16),
                ),
                if (isAssignedByAdmin && orderStatus == 'تم تجهيز الطلب')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'تم تعيين هذا الطلب لك من قبل الإدارة',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetailsScreen(
                              orderId: orderId,
                              userId: userId,
                              onAccept: onAccept,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('عرض التفاصيل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    if (!isAccepted && !isReceived && !isInDelivery && !isDelivered && onAccept != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          _orderController.acceptOrder(orderId, _auth.currentUser!.uid);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('قبول الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    if (isAccepted && !isReceived && !isInDelivery && !isDelivered)
                      ElevatedButton.icon(
                        onPressed: () {
                          _orderController.confirmOrderReceived(orderId);
                        },
                        icon: const Icon(Icons.shopping_bag),
                        label: const Text('تم استلام الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    if (isInDelivery && !isDelivered)
                      ElevatedButton.icon(
                        onPressed: () {
                          _orderController.completeDelivery(orderId);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('تم التوصيل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    if (isDelivered)
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
  }
}
