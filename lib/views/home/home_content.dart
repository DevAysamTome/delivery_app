import 'package:delivery_app/controller/order_controller.dart';
import 'package:delivery_app/controller/delivery_person_controller.dart';
import 'package:delivery_app/models/delivery_person.dart';
import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_app/services/api_service.dart';
import 'package:delivery_app/res/constants/app_strings.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final OrderController _orderController = OrderController();
  final DeliveryPersonController _deliveryPersonController =
      DeliveryPersonController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _deliveryPersonController.getDeliveryPersonStatus();
    _getCurrentDeliveryWorkerId();
  }

  Future<String?> _getCurrentDeliveryWorkerId() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final deliveryWorker = await ApiService.getDeliveryWorker(userId);
        return deliveryWorker?.id;
      }
    } catch (e) {
      print('Error getting delivery worker ID: $e');
    }
    return null;
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
                        AppStrings.presenceStatus,
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: isAvailable,
                        onChanged: (bool value) async {
                          print('Switch toggled to: $value');
                          try {
                            await _deliveryPersonController
                                .updateAvailabilityStatus(value);
                            print('Availability status updated successfully');
                          } catch (e) {
                            print('Error updating availability status: $e');
                            // Show error message to user
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ في تحديث حالة التواجد: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildCard(
                              AppStrings.newOrders, AppStrings.loading);
                        } else if (snapshot.hasError) {
                          print(
                              'Error in new orders stream: ${snapshot.error}');
                          return _buildCard(AppStrings.newOrders, AppStrings.error);
                        } else if (!snapshot.hasData) {
                          return _buildCard(AppStrings.newOrders, '0');
                        } else {
                          return _buildCard(
                              AppStrings.newOrders, snapshot.data.toString());
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<int>(
                      stream:
                          _orderController.getOnGoingInProgressOrdersCount(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildCard(
                              AppStrings.ongoingOrders, AppStrings.loading);
                        } else if (snapshot.hasError) {
                          print(
                              'Error in ongoing orders stream: ${snapshot.error}');
                          return _buildCard(AppStrings.ongoingOrders, AppStrings.error);
                        } else if (!snapshot.hasData) {
                          return _buildCard(AppStrings.ongoingOrders, '0');
                        } else {
                          return _buildCard(
                              AppStrings.ongoingOrders, snapshot.data.toString());
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              AppStrings.recentOrders,
              style: const TextStyle(
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
            child: Text('${AppStrings.orderError}${snapshot.error}'),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!['mainOrders'] == null ||
            (snapshot.data!['mainOrders'] as List<Map<String, dynamic>>)
                .isEmpty) {
          return Center(
            child: Text(
              AppStrings.noOrdersAvailable,
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        final allOrders =
            snapshot.data!['mainOrders'] as List<Map<String, dynamic>>;

        // Sort orders by timestamp in descending order
        allOrders.sort((a, b) {
          final timestampA = a['mainOrder']['createdAt'] != null
              ? DateTime.parse(a['mainOrder']['createdAt'])
              : DateTime(0);
          final timestampB = b['mainOrder']['createdAt'] != null
              ? DateTime.parse(b['mainOrder']['createdAt'])
              : DateTime(0);
          return timestampB.compareTo(timestampA);
        });

        return RefreshIndicator(
          onRefresh: () async {
            // Force a refresh by triggering a rebuild
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: allOrders.length,
            itemBuilder: (context, index) {
              final orderData = allOrders[index];
              final mainOrder = orderData['mainOrder'] as Map<String, dynamic>;
              final storeOrders =
                  orderData['storeOrders'] as List<Map<String, dynamic>>;

              return Column(
                children: storeOrders.map((storeOrder) {
                  final userId = mainOrder['userId'] as String? ?? '';
                  final deliveryDetails =
                      storeOrder['deliveryDetails'] as Map<String, dynamic>?;
                  final address =
                      deliveryDetails?['address'] as String? ?? 'غير متوفر';
                  final deliveryCost = deliveryDetails?['cost'] as num? ?? 0;
                  final location =
                      deliveryDetails?['location'] as Map<String, dynamic>?;
                  final time = deliveryDetails?['time'] as num? ?? 0;
                  final totalPrice = storeOrder['totalPrice'] as num? ?? 0;
                  final orderCost = totalPrice;
                  final totalCost = totalPrice + deliveryCost;
                  final orderId = mainOrder['orderId'].toString();
                  return FutureBuilder<String>(
                    future: _orderController.getCustomerName(userId),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildOrderCard(
                          AppStrings.loading,
                          '${AppStrings.address}$address\n${AppStrings.deliveryCost}$deliveryCost${AppStrings.shekel}\n${AppStrings.orderCost}$orderCost${AppStrings.shekel}\n${AppStrings.totalCost}$totalCost${AppStrings.shekel}\n${AppStrings.expectedTime}$time${AppStrings.minutes}',
                          Colors.grey,
                          orderId: mainOrder['orderId'].toString() ,
                          userId: userId,
                        );
                      }

                      if (userSnapshot.hasError) {
                        return _buildOrderCard(
                          AppStrings.customerNameError,
                          '${AppStrings.address}$address\n${AppStrings.deliveryCost}$deliveryCost${AppStrings.shekel}\n${AppStrings.orderCost}$orderCost${AppStrings.shekel}\n${AppStrings.totalCost}$totalCost${AppStrings.shekel}\n${AppStrings.expectedTime}$time${AppStrings.minutes}',
                          Colors.redAccent,
                          orderId: mainOrder['orderId'].toString() ,
                          userId: userId,
                        );
                      }

                      final customerName = userSnapshot.data ?? AppStrings.unknownCustomer;

                                              return _buildOrderCard(
                          customerName,
                          '${AppStrings.address}$address\n${AppStrings.deliveryCost}$deliveryCost${AppStrings.shekel}\n${AppStrings.orderCost}$orderCost${AppStrings.shekel}\n${AppStrings.totalCost}$totalCost${AppStrings.shekel}\n${AppStrings.expectedTime}$time${AppStrings.minutes}',
                          Colors.white,
                          orderId: mainOrder['orderId'].toString() ,
                          userId: userId,
                          onAccept: () async {
                            final deliveryWorkerId = await _getCurrentDeliveryWorkerId();
                            if (deliveryWorkerId != null) {
                              await _orderController.acceptOrder(
                                  mainOrder['orderId'].toString() , deliveryWorkerId);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppStrings.deliveryWorkerNotFound)),
                              );
                            }
                          },
                        );
                    },
                  );
                }).toList(),
              );
            },
          ),
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: Stream.periodic(const Duration(seconds: 8), (_) async {
        try {
          final order = await ApiService.getOrderById(orderId);
          return order.toJson();
        } catch (e) {
          print('Error fetching order: $e');
          return null;
        }
      }).asyncMap((future) => future),
      builder: (context, snapshot) {
        final String orderStatus = snapshot.hasData
            ? (snapshot.data?['orderStatus'] as String? ?? '')
            : '';

        final bool isAccepted = orderStatus == AppStrings.orderAccepted;
        final bool isReceived = orderStatus == AppStrings.orderReceived;
        final bool isInDelivery = orderStatus == AppStrings.orderInDelivery;
        final bool isDelivered = orderStatus == AppStrings.orderDeliveredStatus;

        // Check if order is assigned by admin
        final bool isAssignedByAdmin = snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.containsKey('assignedTo') &&
            snapshot.data!['assignedTo'] == _auth.currentUser?.uid;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppStrings.orderNumber}$orderId',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    if (isAssignedByAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          AppStrings.assignedByAdmin,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${AppStrings.customerName}$customerName',
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  address,
                  style: const TextStyle(fontSize: 14.0),
                ),
                if (isAssignedByAdmin) ...[
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Colors.blue,
                          size: 16.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          AppStrings.assignedByAdminMessage,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!isAccepted && !isReceived && !isInDelivery && !isDelivered && (isAssignedByAdmin || onAccept != null))
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAssignedByAdmin ? Colors.blue : Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 12.0),
                        ),
                        child: Text(
                          isAssignedByAdmin ? AppStrings.assignedByAdmin : AppStrings.acceptOrder,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    if (isAccepted && !isReceived && !isInDelivery && !isDelivered)
                      ElevatedButton(
                        onPressed: () async {
                          await _orderController.confirmOrderReceived(orderId);
                          // Force immediate refresh after action
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 12.0),
                        ),
                        child: Text(
                          AppStrings.confirmReceipt,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    if (isReceived && !isInDelivery && !isDelivered)
                      ElevatedButton(
                        onPressed: () async {
                          await _orderController.completeDelivery(orderId);
                          // Force immediate refresh after action
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 12.0),
                        ),
                        child: Text(
                          AppStrings.confirmDelivery,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    if (isDelivered)
                      Text(
                        AppStrings.orderDelivered,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
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
