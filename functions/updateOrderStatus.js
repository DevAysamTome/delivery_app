const { MongoClient, ObjectId } = require('mongodb');

module.exports.updateOrderStatus = (functions, admin, pubsub) =>
    functions.firestore
      .document('orders/{orderId}')
      .onUpdate(async (change, context) => {
        const after = change.after.data();
        const before = change.before.data();
        const orderId = context.params.orderId;

        try {
          // Connect to MongoDB
          const mongoClient = new MongoClient(process.env.MONGODB_URI);
          await mongoClient.connect();
          const db = mongoClient.db();

          // Build query conditions for store orders
          const storeOrderQueryConditions = [
            { mainOrderId: parseInt(orderId) },
            { mainOrderId: orderId }
          ];

          // Only add ObjectId condition if it's a valid ObjectId format
          if (ObjectId.isValid(orderId)) {
            storeOrderQueryConditions.push({ _id: new ObjectId(orderId) });
          }

          // Get store orders from MongoDB
          const storeOrders = await db.collection('storeOrders')
            .find({ 
              $or: storeOrderQueryConditions
            })
            .toArray();

          const allItemsCompleted = storeOrders.every(storeOrder =>
            storeOrder.orderStatus === 'تم تجهيز الطلب'
          );

          if (allItemsCompleted && after.orderStatus !== 'تم تجهيز الطلب') {
            // Build query conditions for orders update
            const orderQueryConditions = [
              { orderId: parseInt(orderId) },
              { orderId: orderId }
            ];

            // Only add ObjectId condition if it's a valid ObjectId format
            if (ObjectId.isValid(orderId)) {
              orderQueryConditions.push({ _id: new ObjectId(orderId) });
            }

            // Update order status in MongoDB
            await db.collection('orders').updateOne(
              { 
                $or: orderQueryConditions
              },
              { $set: { orderStatus: 'تم تجهيز الطلب' } }
            );

            try {
              const message = JSON.stringify({ orderId });
              await pubsub.topic('orderCompleted').publish(Buffer.from(message));
              console.log('Published to orderCompleted topic:', message);
            } catch (error) {
              console.error('PubSub error:', error);
            }
          }

          await mongoClient.close();
        } catch (error) {
          console.error('Error updating order status:', error);
        }
      });
  