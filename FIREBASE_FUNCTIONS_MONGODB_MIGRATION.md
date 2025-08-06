# Firebase Cloud Functions MongoDB Migration

## Overview
This document describes the changes made to migrate Firebase Cloud Functions from using Firebase Firestore to MongoDB while keeping Firebase notifications intact.

## Changes Made

### 1. `functions/findNearestWorker.js`
**Before**: Used Firebase Firestore to fetch orders and delivery workers
**After**: Uses MongoDB to fetch data while keeping Firebase Cloud Messaging for notifications

#### Key Changes:
- Added MongoDB driver import: `const { MongoClient } = require('mongodb');`
- Replaced Firestore queries with MongoDB queries:
  - `admin.firestore().collection('orders').doc(orderId).get()` → `db.collection('orders').findOne({ orderId: parseInt(orderId) })`
  - `admin.firestore().collection('deliveryWorkers').where('status', '==', 'متاح').get()` → `db.collection('deliveryWorkers').find({ status: 'متاح' }).toArray()`
- Added proper MongoDB connection management with `mongoClient.connect()` and `mongoClient.close()`
- Updated error handling to include MongoDB connection cleanup
- **Kept Firebase Cloud Messaging**: `admin.messaging().sendToDevice()` remains unchanged

### 2. `functions/index.js`
**Before**: Used Firebase Firestore for scheduled updates and timer management
**After**: Uses MongoDB for data storage while keeping Firebase Cloud Functions triggers

#### Key Changes:
- Added MongoDB driver import: `const { MongoClient } = require('mongodb');`
- Replaced Firestore operations with MongoDB operations:
  - `admin.firestore().collection('scheduled_updates').doc(orderId).set()` → `db.collection('scheduled_updates').insertOne()`
  - `admin.firestore().collection('scheduled_updates').where().where().get()` → `db.collection('scheduled_updates').find({ status: 'pending', scheduledTime: { $lte: now } }).toArray()`
  - `admin.firestore().batch()` → Individual MongoDB operations
- Updated timestamp handling: `admin.firestore.Timestamp.now()` → `new Date()`
- Added proper MongoDB connection management and error handling
- **Kept Firebase Cloud Functions triggers**: Functions still respond to Firestore document creation and PubSub scheduling

### 3. `functions/updateOrderStatus.js`
**Before**: Used Firebase Firestore to check store orders and update main order status
**After**: Uses MongoDB to check store orders and update main order status while keeping PubSub functionality

#### Key Changes:
- Added MongoDB driver import: `const { MongoClient } = require('mongodb');`
- Replaced Firestore subcollection query with MongoDB query:
  - `admin.firestore().collection('orders').doc(orderId).collection('storeOrders').get()` → `db.collection('storeOrders').find({ mainOrderId: parseInt(orderId) }).toArray()`
- Replaced Firestore update with MongoDB update:
  - `admin.firestore().collection('orders').doc(orderId).update()` → `db.collection('orders').updateOne({ orderId: parseInt(orderId) }, { $set: { orderStatus: 'تم تجهيز الطلب' } })`
- Added proper MongoDB connection management and error handling
- **Kept PubSub functionality**: `pubsub.topic('orderCompleted').publish()` remains unchanged
- **Kept Firebase Cloud Functions trigger**: Still responds to Firestore document updates

### 4. `functions/package.json`
**Added**: MongoDB driver dependency
```json
"mongodb": "^6.3.0"
```

## Environment Variables Required

Add the following environment variable to your Firebase Functions configuration:

```bash
MONGODB_URI=your_mongodb_connection_string
```

## Deployment

1. Install the new dependency:
   ```bash
   cd functions
   npm install
   ```

2. Set the MongoDB URI environment variable:
   ```bash
   firebase functions:config:set mongodb.uri="your_mongodb_connection_string"
   ```

3. Deploy the functions:
   ```bash
   firebase deploy --only functions
   ```

## What Remains Unchanged

### Firebase Cloud Messaging
- Push notifications continue to work exactly as before
- `admin.messaging().sendToDevice()` functionality is preserved
- FCM tokens are still stored and used from the MongoDB `deliveryWorkers` collection

### Firebase Cloud Functions Triggers
- Functions still respond to Firestore document creation (`functions.firestore.document().onCreate()`)
- Functions still respond to Firestore document updates (`functions.firestore.document().onUpdate()`)
- PubSub scheduling continues to work (`functions.pubsub.schedule()`)
- Only the data source has changed from Firestore to MongoDB

### Firebase Admin SDK
- Firebase Admin SDK is still used for messaging
- Only Firestore operations have been replaced with MongoDB operations

### PubSub Integration
- PubSub topic publishing continues to work exactly as before
- The `orderCompleted` topic is still used to trigger the nearest worker notification

## Benefits

1. **Unified Data Source**: All data now comes from MongoDB, providing consistency across your application
2. **Cost Reduction**: Reduced Firebase Firestore usage costs
3. **Flexibility**: MongoDB provides more flexibility for complex queries and data modeling
4. **Scalability**: MongoDB can handle larger datasets and more complex operations
5. **Preserved Functionality**: All existing notification and scheduling functionality remains intact

## Testing

After deployment, test the following scenarios:

1. **Order Completion**: Verify that when an order is completed, the nearest delivery worker receives a push notification
2. **Scheduled Updates**: Verify that order status updates are processed correctly at scheduled times
3. **Order Status Updates**: Verify that when all store orders are completed, the main order status is updated and triggers the notification system
4. **Error Handling**: Test with invalid data to ensure proper error handling and MongoDB connection cleanup

## Monitoring

Monitor the following in Firebase Functions logs:

1. MongoDB connection success/failure
2. Order lookup success/failure
3. Store orders queries
4. Delivery worker queries
5. Push notification delivery status
6. Scheduled update processing
7. Order status update processing

## Troubleshooting

### Common Issues:

1. **MongoDB Connection Failed**
   - Verify `MONGODB_URI` environment variable is set correctly
   - Check MongoDB network access and authentication

2. **Order Not Found**
   - Verify order ID format (should be integer for `orderId` field)
   - Check MongoDB collection name and data structure

3. **Store Orders Not Found**
   - Verify `mainOrderId` field in `storeOrders` collection matches the order ID
   - Check that store orders are properly linked to main orders

4. **No Delivery Workers Found**
   - Verify `status` field contains 'متاح' for available workers
   - Check that workers have valid `latitude` and `longitude` coordinates

5. **Push Notification Failed**
   - Verify `fcmToken` field exists in delivery worker documents
   - Check Firebase project configuration and messaging permissions

6. **PubSub Publishing Failed**
   - Verify PubSub topic exists and has proper permissions
   - Check that the message format is correct 