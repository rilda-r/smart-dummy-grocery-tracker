import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  const Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.monthlyLimit,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String category;
  final double monthlyLimit;
  final DateTime updatedAt;

  factory Budget.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Budget(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      monthlyLimit: (data['monthlyLimit'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'category': category,
        'monthlyLimit': monthlyLimit,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Budget copyWith({
    String? id,
    String? userId,
    String? category,
    double? monthlyLimit,
    DateTime? updatedAt,
  }) =>
      Budget(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        category: category ?? this.category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class BudgetUsage {
  const BudgetUsage({
    required this.category,
    required this.monthlyLimit,
    required this.spent,
    required this.remaining,
    required this.percentageUsed,
    required this.exceeded,
  });

  final String category;
  final double monthlyLimit;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final bool exceeded;

  static BudgetUsage compute({
    required String category,
    required double limit,
    required double spent,
  }) {
    final remaining = limit > spent ? limit - spent : 0.0;
    final percentage = limit > 0 ? (spent * 100.0 / limit) : 0.0;
    return BudgetUsage(
      category: category,
      monthlyLimit: limit,
      spent: spent,
      remaining: remaining,
      percentageUsed: percentage,
      exceeded: spent > limit,
    );
  }
}
