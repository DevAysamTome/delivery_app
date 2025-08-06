const geofire = require('geofire-common');
const { MongoClient, ObjectId } = require('mongodb');

module.exports.findNearestDeliveryWorker = (functions, admin) =>
  functions.pubsub
    .topic('orderCompleted')
    .onPublish(async (message) => {
      let payloadData;

      try {
        const decoded = Buffer.from(message.data, 'base64').toString();
        console.log('PubSub Message:', decoded);
        payloadData = JSON.parse(decoded);
      } catch (e) {
        console.error('Invalid message payload:', e);
        return;
      }

      const orderId = payloadData.orderId;
      if (!orderId) return console.error('Missing orderId in payload');

      try {
        // Connect to MongoDB
        const mongoClient = new MongoClient(process.env.MONGODB_URI);
        await mongoClient.connect();
        const db = mongoClient.db();

        // Build query conditions
        const queryConditions = [
          { orderId: parseInt(orderId) },
          { orderId: orderId }
        ];

        // Only add ObjectId condition if it's a valid ObjectId format
        if (ObjectId.isValid(orderId)) {
          queryConditions.push({ _id: new ObjectId(orderId) });
        }

        // Get order from MongoDB
        const order = await db.collection('orders').findOne({ 
          $or: queryConditions
        });
        
        if (!order) {
          console.error('Order not found:', orderId);
          await mongoClient.close();
          return;
        }

        const customerLocation = order.customer?.location;
        if (!customerLocation || typeof customerLocation.latitude !== 'number' || typeof customerLocation.longitude !== 'number') {
          console.error('Invalid customer location');
          await mongoClient.close();
          return;
        }

        // Get available delivery workers from MongoDB
        const deliveryWorkers = await db.collection('deliveryworkers')
          .find({ status: 'متاح' })
          .toArray();

        const workersWithDistance = deliveryWorkers
          .map(worker => {
            if (typeof worker.latitude === 'number' && typeof worker.longitude === 'number') {
              const distance = geofire.distanceBetween(
                [customerLocation.latitude, customerLocation.longitude],
                [worker.latitude, worker.longitude]
              );
              return { ...worker, distance };
            }
            return null;
          })
          .filter(Boolean);

        if (!workersWithDistance.length) {
          console.log('No valid delivery workers');
          await mongoClient.close();
          return;
        }

        const nearestWorker = workersWithDistance.reduce((a, b) => a.distance < b.distance ? a : b);

        if (nearestWorker?.fcmToken) {
          await admin.messaging().sendToDevice(nearestWorker.fcmToken, {
            notification: {
              title: 'SARIE APP',
              body: 'لديك طلب جديد بالقرب منك!',
            },
          });
          console.log('Notification sent to:', nearestWorker._id);
        } else {
          console.log('No FCM token for nearest worker');
        }

        await mongoClient.close();

      } catch (error) {
        console.error('Delivery assignment error:', error);
      }
    });
