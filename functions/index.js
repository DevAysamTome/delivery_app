const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { MongoClient, ObjectId } = require('mongodb');

// Function to handle the initial timer creation
exports.handleDeliveryTimer = functions.firestore
    .document('delivery_timers/{timerId}')
    .onCreate(async (snap, context) => {
        const timerData = snap.data();
        const orderId = timerData.orderId;
        const scheduledTime = timerData.scheduledTime.toDate();

        try {
            // Connect to MongoDB
            const mongoClient = new MongoClient(process.env.MONGODB_URI);
            await mongoClient.connect();
            const db = mongoClient.db();

            // Schedule the status update in MongoDB
            await db.collection('scheduled_updates').insertOne({
                'orderId': orderId,
                'scheduledTime': scheduledTime,
                'status': 'pending'
            });

            await mongoClient.close();
        } catch (error) {
            console.error('Error creating scheduled update:', error);
        }

        return null;
    });

// Function to check and process scheduled updates
exports.processScheduledUpdates = functions.pubsub
    .schedule('every 1 minutes')
    .onRun(async (context) => {
        try {
            // Connect to MongoDB
            const mongoClient = new MongoClient(process.env.MONGODB_URI);
            await mongoClient.connect();
            const db = mongoClient.db();

            const now = new Date();
            
            // Get all pending updates that are due
            const updates = await db.collection('scheduled_updates')
                .find({ 
                    status: 'pending',
                    scheduledTime: { $lte: now }
                })
                .toArray();

            // Process each update
            for (const update of updates) {
                const orderId = update.orderId;

                // Build query conditions
                const queryConditions = [
                  { orderId: parseInt(orderId) },
                  { orderId: orderId }
                ];

                // Only add ObjectId condition if it's a valid ObjectId format
                if (ObjectId.isValid(orderId)) {
                  queryConditions.push({ _id: new ObjectId(orderId) });
                }

                // Update the order status in MongoDB
                await db.collection('orders').updateOne(
                  { 
                    $or: queryConditions
                  },
                  {
                    $set: {
                      'orderStatus': 'جاري التوصيل',
                      'deliveryStartedAt': now
                    }
                  }
                );

                // Mark the scheduled update as completed
                await db.collection('scheduled_updates').updateOne(
                    { _id: update._id },
                    {
                        $set: {
                            'status': 'completed',
                            'processedAt': now
                        }
                    }
                );
            }

            await mongoClient.close();
        } catch (error) {
            console.error('Error processing scheduled updates:', error);
        }
        
        return null;
    }); 