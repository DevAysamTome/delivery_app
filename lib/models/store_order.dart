import 'dart:convert';

class StoreOrder {
  final String? id; // MongoDB _id
  final String? mainOrderObjectId; // Reference to main order
  final int mainOrderId; // Sequential order number
  final String userId;
  final String storeId;
  final String? notes;
  final String? orderStatus;
  final double totalPrice;
  final String? paymentOption;
  final String? deliveryOption;
  final String? deliveryAddress;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? deliveryDetails;
  final Map<String, dynamic>? restaurantLocation;
  final int? remainingTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StoreOrder({
    this.id,
    this.mainOrderObjectId,
    required this.mainOrderId,
    required this.userId,
    required this.storeId,
    this.notes,
    this.orderStatus,
    required this.totalPrice,
    this.paymentOption,
    this.deliveryOption,
    this.deliveryAddress,
    required this.items,
    this.deliveryDetails,
    this.restaurantLocation,
    this.remainingTime,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    return StoreOrder(
      id: json['_id'] as String?,
      mainOrderObjectId: json['mainOrderObjectId'] as String?,
      mainOrderId: json['mainOrderId'] as int,
      userId: json['userId'] as String,
      storeId: json['storeId'] as String,
      notes: json['notes'] as String?,
      orderStatus: json['orderStatus'] as String?,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      paymentOption: json['paymentOption'] as String?,
      deliveryOption: json['deliveryOption'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      deliveryDetails: json['deliveryDetails'] as Map<String, dynamic>?,
      restaurantLocation: json['restaurantLocation'] as Map<String, dynamic>?,
      remainingTime: json['remainingTime'] as int?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (mainOrderObjectId != null) 'mainOrderObjectId': mainOrderObjectId,
      'mainOrderId': mainOrderId,
      'userId': userId,
      'storeId': storeId,
      if (notes != null) 'notes': notes,
      if (orderStatus != null) 'orderStatus': orderStatus,
      'totalPrice': totalPrice,
      if (paymentOption != null) 'paymentOption': paymentOption,
      if (deliveryOption != null) 'deliveryOption': deliveryOption,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      'items': items,
      if (deliveryDetails != null) 'deliveryDetails': deliveryDetails,
      if (restaurantLocation != null) 'restaurantLocation': restaurantLocation,
      if (remainingTime != null) 'remainingTime': remainingTime,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  StoreOrder copyWith({
    String? id,
    String? mainOrderObjectId,
    int? mainOrderId,
    String? userId,
    String? storeId,
    String? notes,
    String? orderStatus,
    double? totalPrice,
    String? paymentOption,
    String? deliveryOption,
    String? deliveryAddress,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? deliveryDetails,
    Map<String, dynamic>? restaurantLocation,
    int? remainingTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreOrder(
      id: id ?? this.id,
      mainOrderObjectId: mainOrderObjectId ?? this.mainOrderObjectId,
      mainOrderId: mainOrderId ?? this.mainOrderId,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      notes: notes ?? this.notes,
      orderStatus: orderStatus ?? this.orderStatus,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentOption: paymentOption ?? this.paymentOption,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      deliveryDetails: deliveryDetails ?? this.deliveryDetails,
      restaurantLocation: restaurantLocation ?? this.restaurantLocation,
      remainingTime: remainingTime ?? this.remainingTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 