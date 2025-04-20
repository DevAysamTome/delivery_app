import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryPerson {
  final String id;
  final String name;
  final bool isAvailable;
  final String? currentOrderId;

  DeliveryPerson({
    required this.id,
    required this.name,
    required this.isAvailable,
    this.currentOrderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isAvailable': isAvailable,
      'currentOrderId': currentOrderId,
    };
  }

  factory DeliveryPerson.fromMap(Map<String, dynamic> map) {
    return DeliveryPerson(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
      currentOrderId: map['currentOrderId'],
    );
  }

  DeliveryPerson copyWith({
    String? id,
    String? name,
    bool? isAvailable,
    String? currentOrderId,
  }) {
    return DeliveryPerson(
      id: id ?? this.id,
      name: name ?? this.name,
      isAvailable: isAvailable ?? this.isAvailable,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }
} 