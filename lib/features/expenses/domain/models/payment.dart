import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, settled }

extension PaymentStatusExt on PaymentStatus {
  String get value => this == PaymentStatus.pending ? 'pending' : 'settled';

  static PaymentStatus fromString(String? s) =>
      s == 'settled' ? PaymentStatus.settled : PaymentStatus.pending;
}

class Payment {
  const Payment({
    required this.id,
    required this.groupId,
    required this.billId,
    required this.payerUserId,
    required this.payeeUserId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.settledAt,
    this.payerName,
    this.payeeName,
  });

  final String id;
  final String groupId;
  final String billId;
  final String payerUserId; // the debtor
  final String payeeUserId; // the bill uploader (paid at shop)
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? payerName; // denormalized display
  final String? payeeName;

  bool get isPending => status == PaymentStatus.pending;

  factory Payment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Payment(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      billId: data['billId'] as String? ?? '',
      payerUserId: data['payerUserId'] as String? ?? '',
      payeeUserId: data['payeeUserId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: PaymentStatusExt.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
      payerName: data['payerName'] as String?,
      payeeName: data['payeeName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'billId': billId,
        'payerUserId': payerUserId,
        'payeeUserId': payeeUserId,
        'amount': amount,
        'status': status.value,
        'createdAt': Timestamp.fromDate(createdAt),
        'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
        'payerName': payerName,
        'payeeName': payeeName,
      };
}
