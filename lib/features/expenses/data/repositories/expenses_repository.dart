import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/payment.dart';
import '../services/expense_split_calculator.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(FirebaseFirestore.instance);
});

class MemberBalance {
  const MemberBalance({
    required this.userId,
    required this.balance, // positive: is owed money; negative: owes money
  });

  final String userId;
  final double balance;
}

class ExpensesRepository {
  ExpensesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _billsCol(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('bills');

  CollectionReference<Map<String, dynamic>> _billItemsCol(
          String groupId, String billId) =>
      _billsCol(groupId).doc(billId).collection('billItems');

  CollectionReference<Map<String, dynamic>> _paymentsCol(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('payments');

  /// Watch all bills in a group
  Stream<List<Bill>> watchBills(String groupId) {
    return _billsCol(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Bill.fromFirestore).toList());
  }

  /// Watch items of a specific bill
  Stream<List<BillItem>> watchBillItems(String groupId, String billId) {
    return _billItemsCol(groupId, billId).snapshots().map((snap) =>
        snap.docs.map(BillItem.fromFirestore).toList());
  }

  /// Watch all payments in a group
  Stream<List<Payment>> watchPayments(String groupId) {
    return _paymentsCol(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Payment.fromFirestore).toList());
  }

  /// Create a bill with its line items using a batched write
  Future<Bill> createBillWithItems({
    required String groupId,
    required String uploadedBy,
    required String fileName,
    required List<BillItem> items,
    required double totalAmount,
  }) async {
    final batch = _firestore.batch();
    final billDoc = _billsCol(groupId).doc();

    final bill = Bill(
      id: billDoc.id,
      groupId: groupId,
      uploadedBy: uploadedBy,
      fileName: fileName,
      ocrStatus: OcrStatus.completed,
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
      splitConfirmed: false,
    );

    batch.set(billDoc, bill.toFirestore());

    for (final item in items) {
      final itemDoc = _billItemsCol(groupId, billDoc.id).doc();
      final newItem = item.copyWith(id: itemDoc.id, billId: billDoc.id);
      batch.set(itemDoc, newItem.toFirestore());
    }

    await batch.commit();
    return bill;
  }

  /// Update an individual line item (e.g., assignment, name, or price)
  Future<void> updateBillItem({
    required String groupId,
    required String billId,
    required BillItem item,
  }) async {
    await _billItemsCol(groupId, billId).doc(item.id).update(item.toFirestore());
  }

  /// Delete a line item
  Future<void> deleteBillItem({
    required String groupId,
    required String billId,
    required String itemId,
  }) async {
    await _billItemsCol(groupId, billId).doc(itemId).delete();
  }

  /// Add a line item to an existing bill
  Future<BillItem> addBillItem({
    required String groupId,
    required String billId,
    required String itemName,
    required double quantity,
    required double unitPrice,
    required double totalPrice,
    String? assignedUserId,
  }) async {
    final doc = _billItemsCol(groupId, billId).doc();
    final item = BillItem(
      id: doc.id,
      billId: billId,
      itemName: itemName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      assignedUserId: assignedUserId,
    );
    await doc.set(item.toFirestore());
    return item;
  }

  /// Confirm bill split (Equal or Member-wise) and generate pending payments
  Future<void> confirmBillSplit({
    required String groupId,
    required Bill bill,
    required List<SplitShare> shares,
    required String splitType,
    Map<String, String>? memberNames,
  }) async {
    final batch = _firestore.batch();

    // 1. Delete existing pending payments for this bill
    final existingPending = await _paymentsCol(groupId)
        .where('billId', isEqualTo: bill.id)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in existingPending.docs) {
      batch.delete(doc.reference);
    }

    // 2. Insert new payment records for every debtor
    final now = DateTime.now();
    for (final share in shares) {
      if (share.userId == bill.uploadedBy || share.amount <= 0) continue;

      final pDoc = _paymentsCol(groupId).doc();
      final payment = Payment(
        id: pDoc.id,
        groupId: groupId,
        billId: bill.id,
        payerUserId: share.userId,
        payeeUserId: bill.uploadedBy,
        amount: share.amount,
        status: PaymentStatus.pending,
        createdAt: now,
        payerName: memberNames?[share.userId],
        payeeName: memberNames?[bill.uploadedBy],
      );
      batch.set(pDoc, payment.toFirestore());
    }

    // 3. Update bill status
    batch.update(_billsCol(groupId).doc(bill.id), {
      'splitConfirmed': true,
      'splitType': splitType,
    });

    await batch.commit();
  }

  /// Mark payment as settled
  Future<void> settlePayment({
    required String groupId,
    required String paymentId,
  }) async {
    await _paymentsCol(groupId).doc(paymentId).update({
      'status': PaymentStatus.settled.value,
      'settledAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Compute net balances across unsettled payments for group members
  static List<MemberBalance> computeBalances(
    List<Payment> payments,
    List<String> memberIds,
  ) {
    final net = <String, double>{for (final id in memberIds) id: 0.0};

    for (final p in payments) {
      if (p.isPending) {
        net[p.payeeUserId] = (net[p.payeeUserId] ?? 0.0) + p.amount;
        net[p.payerUserId] = (net[p.payerUserId] ?? 0.0) - p.amount;
      }
    }

    return net.entries
        .map((e) => MemberBalance(
              userId: e.key,
              balance: (e.value * 100).round() / 100,
            ))
        .toList();
  }
}
