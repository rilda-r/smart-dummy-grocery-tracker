import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalExpense {
  const PersonalExpense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? description;
  final DateTime createdAt;

  factory PersonalExpense.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PersonalExpense(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] as String? ?? 'General',
      expenseDate:
          (data['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'amount': amount,
        'category': category,
        'expenseDate': Timestamp.fromDate(expenseDate),
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  PersonalExpense copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    DateTime? expenseDate,
    String? description,
    DateTime? createdAt,
  }) =>
      PersonalExpense(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        expenseDate: expenseDate ?? this.expenseDate,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
      );
}
