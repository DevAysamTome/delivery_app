# Firebase to MongoDB Migration Guide

This guide explains the changes made to migrate your Flutter delivery app from Firebase to MongoDB.

## What Has Been Changed

### 1. Models Updated

#### `lib/models/order.dart`
- ✅ Removed Firebase Firestore imports
- ✅ Updated model structure to match MongoDB schema
- ✅ Changed `fromFirestore()` to `fromJson()`
- ✅ Added `toJson()` method for API communication
- ✅ Added `copyWith()` method for immutable updates
- ✅ Updated field types to match MongoDB schema

#### `lib/models/delivery_person.dart`
- ✅ Removed Firebase Firestore imports
- ✅ Updated model structure to match MongoDB schema
- ✅ Changed `fromMap()` to `fromJson()`
- ✅ Added `toJson()` method for API communication
- ✅ Added `copyWith()` method for immutable updates
- ✅ Added location and token fields

### 2. Services Created/Updated

#### `lib/services/api_service.dart` (Completely Rewritten)
- ✅ Created comprehensive HTTP API service
- ✅ Added retry logic for network requests
- ✅ Implemented all CRUD operations for orders
- ✅ Implemented delivery worker management
- ✅ Added user data retrieval methods
- ✅ Proper error handling and status code management

#### `lib/services/realtime_service.dart` (New)
- ✅ Created polling-based real-time service
- ✅ Replaces Firebase real-time listeners
- ✅ Configurable polling intervals
- ✅ Stream management for multiple data types
- ✅ Memory leak prevention with proper disposal

### 3. Controllers Updated

#### `lib/controller/order_controller.dart`
- ✅ Removed Firebase Firestore dependencies
- ✅ Updated to use new API service
- ✅ Implemented polling-based streams
- ✅ Added proper error handling
- ✅ Maintained same public API for UI compatibility

#### `lib/controller/delivery_person_controller.dart`
- ✅ Removed Firebase Firestore dependencies
- ✅ Updated to use new API service
- ✅ Added location and token management
- ✅ Implemented polling-based streams
- ✅ Added proper error handling

#### `lib/controller/auth_controller.dart`
- ✅ Kept Firebase Auth for authentication
- ✅ Updated delivery worker verification to use MongoDB API
- ✅ Updated location tracking to use new API service
- ✅ Maintained same login flow

#### `lib/service/driverLocationService.dart`
- ✅ Updated to use new API service
- ✅ Added proper user identification
- ✅ Improved error handling

### 4. Dependencies Updated

#### `pubspec.yaml`
- ✅ Added `http: ^1.1.0` for API communication
- ✅ Kept Firebase Auth and Messaging for authentication and notifications

## What You Need to Do Next

### 1. Backend Implementation

You need to implement the backend API endpoints as outlined in `BACKEND_API_ENDPOINTS.md`. The key endpoints are:

#### Orders API
- `GET /api/orders` - Get all orders
- `GET /api/orders/:id` - Get order by ID
- `GET /api/orders/byOrderId/:orderId` - Get order by sequential number
- `POST /api/orders` - Create new order
- `PUT /api/orders/:id` - Update order
- `DELETE /api/orders/:id` - Delete order
- `GET /api/orders/user/:userId` - Get user orders

#### Delivery Workers API
- `GET /api/delivery-workers/user/:userId` - Get delivery worker
- `POST /api/delivery-workers` - Create/update delivery worker
- `GET /api/delivery-workers/available` - Get available workers

#### Users API
- `GET /api/users/:userId` - Get user data

### 2. Database Setup

#### MongoDB Collections
1. **orders** - Main orders collection
2. **deliveryWorkers** - Delivery worker profiles
3. **users** - User profiles
4. **counters** - For sequential order ID generation

#### Required Indexes
```javascript
// Orders collection
db.orders.createIndex({ "orderId": 1 }, { unique: true })
db.orders.createIndex({ "userId": 1 })
db.orders.createIndex({ "assignedTo": 1 })
db.orders.createIndex({ "orderStatus": 1 })

// Delivery workers collection
db.deliveryWorkers.createIndex({ "userId": 1 }, { unique: true })
db.deliveryWorkers.createIndex({ "status": 1 })

// Users collection
db.users.createIndex({ "userId": 1 }, { unique: true })
```

### 3. Environment Configuration

#### Backend Environment Variables
```
MONGODB_URI=your_mongodb_connection_string
PORT=3000
NODE_ENV=production
```

#### Flutter Environment
- Update the base URL in `lib/services/api_service.dart` if needed
- Ensure your backend is accessible from the Flutter app

### 4. Testing

#### Backend Testing
1. Test all API endpoints with Postman or curl
2. Verify data validation and error handling
3. Test CORS configuration
4. Test rate limiting (if implemented)

#### Flutter App Testing
1. Test login flow
2. Test order management
3. Test delivery worker status updates
4. Test location tracking
5. Test real-time updates (polling)

### 5. Deployment

#### Backend Deployment
1. Deploy your Node.js/Express backend to your hosting platform
2. Configure environment variables
3. Set up MongoDB connection
4. Test all endpoints in production

#### Flutter App Deployment
1. Update the API base URL to your production backend
2. Test the app with the production backend
3. Deploy the updated app

## Key Differences from Firebase

### 1. Real-time Updates
- **Firebase**: Real-time listeners with automatic updates
- **MongoDB**: Polling-based updates every 10 seconds

### 2. Data Structure
- **Firebase**: Document-based with subcollections
- **MongoDB**: Flattened document structure

### 3. Authentication
- **Firebase**: Firebase Auth (kept)
- **MongoDB**: Still uses Firebase Auth UID as userId

### 4. Notifications
- **Firebase**: Firebase Cloud Messaging (kept)
- **MongoDB**: Still uses FCM for push notifications

## Performance Considerations

### 1. Polling Frequency
- Current polling interval: 10 seconds
- Can be adjusted in `RealtimeService.pollingInterval`
- Consider battery usage vs. real-time requirements

### 2. API Optimization
- Implement pagination for large datasets
- Add caching headers
- Consider implementing WebSocket for real-time updates

### 3. Error Handling
- Implement exponential backoff for failed requests
- Add offline support with local caching
- Graceful degradation when API is unavailable

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure backend has proper CORS configuration
   - Check allowed origins and methods

2. **Authentication Issues**
   - Verify Firebase Auth is still working
   - Check if user IDs are being passed correctly

3. **Data Sync Issues**
   - Check polling intervals
   - Verify API responses match expected format
   - Check network connectivity

4. **Performance Issues**
   - Reduce polling frequency if needed
   - Implement request caching
   - Optimize API responses

## Support

If you encounter issues during migration:

1. Check the API documentation in `BACKEND_API_ENDPOINTS.md`
2. Verify all endpoints are implemented correctly
3. Test with Postman before integrating with Flutter
4. Check browser developer tools for network errors
5. Review Flutter console logs for detailed error messages

## Next Steps

1. ✅ **Completed**: Flutter app migration
2. 🔄 **In Progress**: Backend API implementation
3. ⏳ **Pending**: Database setup and testing
4. ⏳ **Pending**: Production deployment
5. ⏳ **Pending**: Performance optimization 