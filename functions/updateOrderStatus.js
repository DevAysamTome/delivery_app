module.exports.updateOrderStatus = (functions, admin, pubsub) =>
    functions.firestore
      .document('orders/{orderId}')
      .onUpdate(async (change, context) => {
        const after = change.after.data();
        const before = change.before.data();
        const orderId = context.params.orderId;
  
        const orderItemsSnapshot = await admin.firestore()
          .collection('orders')
          .doc(orderId)
          .collection('storeOrders')
          .get();
  
        const allItemsCompleted = orderItemsSnapshot.docs.every(doc =>
          doc.data().orderStatus === 'تم تجهيز الطلب'
        );
  
        if (allItemsCompleted && after.orderStatus !== 'تم تجهيز الطلب') {
          await admin.firestore().collection('orders').doc(orderId).update({ orderStatus: 'تم تجهيز الطلب' });
  
          try {
            const message = JSON.stringify({ orderId });
            await pubsub.topic('orderCompleted').publish(Buffer.from(message));
            console.log('Published to orderCompleted topic:', message);
          } catch (error) {
            console.error('PubSub error:', error);
          }
        }
      });
  