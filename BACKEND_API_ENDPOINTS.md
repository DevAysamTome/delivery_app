# Backend API Endpoints Documentation

This document outlines the required backend API endpoints for the MongoDB migration of the Flutter delivery app.

## Base URL
```
http://localhost:3000/api
```

## 1. Orders API (`/orders`)

### GET /orders
Get all orders
- **Response**: `200 OK` - Array of Order objects
- **Example**: `GET /api/orders`

### GET /orders/:id
Get order by MongoDB _id
- **Parameters**: `id` (string) - MongoDB ObjectId
- **Response**: `200 OK` - Order object or `404 Not Found`
- **Example**: `GET /api/orders/507f1f77bcf86cd799439011`

### GET /orders/byOrderId/:orderId
Get order by sequential order number
- **Parameters**: `orderId` (number) - Sequential order ID
- **Response**: `200 OK` - Order object or `404 Not Found`
- **Example**: `GET /api/orders/byOrderId/12345`

### POST /orders
Create new order
- **Body**: Order object
- **Response**: `201 Created` - Created Order object
- **Example**: `POST /api/orders`

### PUT /orders/:id
Update order
- **Parameters**: `id` (string) - MongoDB ObjectId
- **Body**: Order object
- **Response**: `200 OK` - Updated Order object
- **Example**: `PUT /api/orders/507f1f77bcf86cd799439011`

### DELETE /orders/:id
Delete order
- **Parameters**: `id` (string) - MongoDB ObjectId
- **Response**: `200 OK` - Success message
- **Example**: `DELETE /api/orders/507f1f77bcf86cd799439011`

### GET /orders/user/:userId
Get orders by user ID
- **Parameters**: `userId` (string) - User ID
- **Response**: `200 OK` - Array of Order objects
- **Example**: `GET /api/orders/user/user123`

## 2. Store Orders API (`/store-orders`)

### GET /store-orders
Get all store orders
- **Response**: `200 OK` - Array of StoreOrder objects
- **Example**: `GET /api/store-orders`

### POST /store-orders
Create new store order
- **Body**: StoreOrder object (must include `mainOrderId` as number)
- **Response**: `201 Created` - Created StoreOrder object
- **Example**: `POST /api/store-orders`

### GET /store-orders/users/:userId
Get store orders by user ID
- **Parameters**: `userId` (string) - User ID
- **Response**: `200 OK` - Array of StoreOrder objects
- **Example**: `GET /api/store-orders/users/user123`

### GET /store-orders/main-orders/:mainOrderId
Get store orders by main order ID
- **Parameters**: `mainOrderId` (number) - Main order sequential ID
- **Response**: `200 OK` - Array of StoreOrder objects
- **Example**: `GET /api/store-orders/main-orders/12345`

## 3. Delivery Workers API (`/deliveryworkers`)

### GET /deliveryworkers
Get all delivery workers
- **Response**: `200 OK` - Array of DeliveryWorker objects with user info
- **Example**: `GET /api/deliveryworkers`

### GET /deliveryworkers/:id
Get delivery worker by ID
- **Parameters**: `id` (string) - Delivery worker ID
- **Response**: `200 OK` - DeliveryWorker object with user info or `404 Not Found`
- **Example**: `GET /api/deliveryworkers/507f1f77bcf86cd799439011`

### POST /deliveryworkers/create
Create new delivery worker
- **Body**: 
  ```json
  {
    "_id": "string", // optional: if not provided, new ID will be generated
    "email": "string",
    "fullName": "string",
    "phoneNumber": "string",
    "fcmToken": "string", // optional
    "latitude": "number", // optional
    "longitude": "number" // optional
  }
  ```
- **Response**: `201 Created` - Created user and delivery worker objects
- **Example**: `POST /api/deliveryworkers/create`

### PUT /deliveryworkers/:id
Update delivery worker
- **Parameters**: `id` (string) - Delivery worker ID
- **Body**: 
  ```json
  {
    "status": "string", // optional
    "latitude": "number", // optional
    "longitude": "number", // optional
    "fcmToken": "string" // optional
  }
  ```
- **Response**: `200 OK` - Updated DeliveryWorker object
- **Example**: `PUT /api/deliveryworkers/507f1f77bcf86cd799439011`

### DELETE /deliveryworkers/:id
Delete delivery worker
- **Parameters**: `id` (string) - Delivery worker ID
- **Response**: `200 OK` - Success message
- **Example**: `DELETE /api/deliveryworkers/507f1f77bcf86cd799439011`

## 4. Users API (`/users`)

### GET /users/:userId
Get user by ID
- **Parameters**: `userId` (string) - User ID
- **Response**: `200 OK` - User object or `404 Not Found`
- **Example**: `GET /api/users/user123`

## 5. Stores API (`/stores`)

### GET /stores/:storeType/:storeId
Get store details by type and ID
- **Parameters**: 
  - `storeType` (string) - Type of store (restaurants, beverageStores, sweetStore)
  - `storeId` (string) - Store ID
- **Response**: `200 OK` - Store object or `404 Not Found`
- **Example**: `GET /api/stores/restaurants/store123`

## Data Models

### Order Model
```javascript
{
  _id: ObjectId,
  orderId: Number, // Sequential order number
  userId: String,
  items: [{
    mealId: String,
    quantity: Number,
    additions: [String],
    price: Number,
    storeId: String,
    imageUrl: String
  }],
  totalPrice: Number,
  deliveryCost: Number,
  deliveryTime: Number,
  deliveryOption: String,
  paymentOption: String,
  orderStatus: String,
  storeId: String,
  placeName: String,
  userLocation: {
    latitude: Number,
    longitude: Number
  },
  restaurantLocation: {
    latitude: Number,
    longitude: Number
  },
  deliveryLocation: {
    latitude: Number,
    longitude: Number
  },
  deliveryAddress: String,
  assignedTo: String, // Delivery worker user ID
  createdAt: Date,
  updatedAt: Date
}
```

### StoreOrder Model
```javascript
{
  _id: ObjectId,
  mainOrderObjectId: ObjectId, // Reference to main order
  mainOrderId: Number, // Sequential order number
  userId: String,
  storeId: String,
  notes: String,
  orderStatus: String,
  totalPrice: Number,
  paymentOption: String,
  deliveryOption: String,
  deliveryAddress: String,
  items: [{
    mealId: String,
    mealName: String,
    imageUrl: String,
    mealPrice: Number,
    quantity: Number,
    storeId: String
  }],
  deliveryDetails: {
    address: String,
    cost: Number,
    location: {
      latitude: Number,
      longitude: Number
    },
    time: Number
  },
  restaurantLocation: {
    latitude: Number,
    longitude: Number
  },
  remainingTime: Number,
  createdAt: Date,
  updatedAt: Date
}
```

### DeliveryWorker Model
```javascript
{
  _id: ObjectId,
  email: String,
  phoneNumber: String,
  fullName: String,
  fcmToken: String,
  latitude: Number,
  longitude: Number,
  status: String, // 'متاح' or 'غير متاح'
  currentOrders: [String], // Array of order IDs
  createdAt: Date,
  updatedAt: Date
}
```

### User Model (for delivery workers)
```javascript
{
  _id: ObjectId,
  email: String,
  fullName: String,
  phoneNumber: String,
  role: String, // 'delivery'
  createdAt: Date,
  updatedAt: Date
}
```

### User Model
```javascript
{
  _id: ObjectId,
  userId: String,
  name: String,
  email: String,
  phoneNumber: String,
  address: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Counter Model (for sequential IDs)
```javascript
{
  _id: String, // Collection name (e.g., "orders")
  seq: Number // Current sequence number
}
```

## Implementation Notes

### 1. Counter Collection
- Used for generating sequential order IDs
- Collection name: `counters`
- Document ID: `"orders"` for main orders, `"storeOrders"` for store orders
- Field: `seq` (number)

### 2. Environment Variables
```bash
MONGODB_URI=mongodb://localhost:27017/delivery_app
PORT=3000
NODE_ENV=development
```

### 3. Error Handling
- All endpoints should return appropriate HTTP status codes
- Error responses should include descriptive messages
- Use try-catch blocks for database operations

### 4. Validation
- Validate required fields in request bodies
- Check data types (especially for `mainOrderId` as number)
- Sanitize user inputs

### 5. Testing
- Test all endpoints with Postman or curl
- Verify error handling with invalid inputs
- Test with real data scenarios

## Example Usage

### Create a main order
```bash
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "items": [{"mealId": "meal1", "quantity": 2, "price": 25.0}],
    "totalPrice": 50.0,
    "deliveryCost": 5.0,
    "deliveryAddress": "123 Main St"
  }'
```

### Create a store order
```bash
curl -X POST http://localhost:3000/api/store-orders \
  -H "Content-Type: application/json" \
  -d '{
    "mainOrderId": 12345,
    "userId": "user123",
    "storeId": "store1",
    "items": [{"mealId": "meal1", "mealName": "Burger", "quantity": 2, "mealPrice": 25.0}],
    "totalPrice": 50.0
  }'
```

### Create a delivery worker
```bash
curl -X POST http://localhost:3000/api/deliveryworkers/create \
  -H "Content-Type: application/json" \
  -d '{
    "email": "driver@example.com",
    "fullName": "John Doe",
    "phoneNumber": "+1234567890",
    "fcmToken": "fcm_token_here",
    "latitude": 31.9539,
    "longitude": 35.9106
  }'
```

### Update delivery worker status
```bash
curl -X PUT http://localhost:3000/api/deliveryworkers/507f1f77bcf86cd799439011 \
  -H "Content-Type: application/json" \
  -d '{"status": "متاح", "latitude": 31.9539, "longitude": 35.9106}'
```

### Get all delivery workers
```bash
curl -X GET http://localhost:3000/api/deliveryworkers
``` 