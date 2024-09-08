import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingOrdersTab extends StatelessWidget {
  const PendingOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('orderStatus', isEqualTo: 'مكتمل')
                              .where('deliveryOption', isEqualTo: 'delivery')
 // فلترة الطلبات المكتملة
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var orders = snapshot.data!.docs;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            var order = orders[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Text('رقم الطلب: ${order['orderId']}',
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold)),
                subtitle: Text('الحالة: ${order['orderStatus']}'),
                trailing: Text('الإجمالي: \$${order['totalPrice']}',
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OrderDetailsScreen(orderId: order.id,userId:order['userId']),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
