import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../data/repositories/expenses_repository.dart';
import '../../data/services/bill_ocr_parser.dart';
import '../../data/services/expense_split_calculator.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/payment.dart';

import '../../data/services/receipt_preprocessor.dart';

final billsStreamProvider = StreamProvider<List<Bill>>((ref) {
  final activeGroupId = ref.watch(activeGroupIdProvider);
  if (activeGroupId == null) return Stream.value([]);
  return ref.watch(expensesRepositoryProvider).watchBills(activeGroupId);
});

final paymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final activeGroupId = ref.watch(activeGroupIdProvider);
  if (activeGroupId == null) return Stream.value([]);
  return ref.watch(expensesRepositoryProvider).watchPayments(activeGroupId);
});

final billItemsStreamProvider =
    StreamProvider.family<List<BillItem>, String>((ref, billId) {
  final activeGroupId = ref.watch(activeGroupIdProvider);
  if (activeGroupId == null) return Stream.value([]);
  return ref
      .watch(expensesRepositoryProvider)
      .watchBillItems(activeGroupId, billId);
});

final expensesControllerProvider =
    StateNotifierProvider<ExpensesController, AsyncValue<void>>((ref) {
  return ExpensesController(ref);
});

class ExpensesController extends StateNotifier<AsyncValue<void>> {
  ExpensesController(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  ExpensesRepository get _repo => _ref.read(expensesRepositoryProvider);

  /// Process an uploaded bill image or PDF via on-device ML Kit OCR
  Future<Bill?> processBillFile({
    required String filePath,
    required String fileName,
    required String groupId,
    required String uploadedBy,
  }) async {
    state = const AsyncLoading();
    try {
      final parsedItems = <ParsedBillLine>[];
      double? detectedGrandTotal;

      final isPdf = ReceiptPreprocessor.isPdf(fileName);

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          if (isPdf) {
            final pageBytesList = await ReceiptPreprocessor.renderPdfPages(filePath);
            for (int i = 0; i < pageBytesList.length; i++) {
              final tempFile = File('${Directory.systemTemp.path}/ocr_page_$i.jpg');
              await tempFile.writeAsBytes(pageBytesList[i]);

              final inputImage = InputImage.fromFilePath(tempFile.path);
              final recognized = await textRecognizer.processImage(inputImage);
              final rows = BillOcrParser.rebuildRowsFromMlKit(recognized);
              final pageResult = BillOcrParser.parseText(recognized.text, prebuiltRows: rows);

              parsedItems.addAll(pageResult.items);
              if (pageResult.detectedGrandTotal != null) {
                detectedGrandTotal = pageResult.detectedGrandTotal;
              }

              if (await tempFile.exists()) {
                await tempFile.delete();
              }
            }
          } else {
            // Preprocess image
            final rawBytes = await File(filePath).readAsBytes();
            final preprocessed = ReceiptPreprocessor.preprocessImageBytes(rawBytes);
            final tempFile = File('${Directory.systemTemp.path}/ocr_temp.jpg');
            await tempFile.writeAsBytes(preprocessed);

            final inputImage = InputImage.fromFilePath(tempFile.path);
            final recognized = await textRecognizer.processImage(inputImage);
            final rows = BillOcrParser.rebuildRowsFromMlKit(recognized);
            final result = BillOcrParser.parseText(recognized.text, prebuiltRows: rows);

            parsedItems.addAll(result.items);
            detectedGrandTotal = result.detectedGrandTotal;

            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        } catch (e) {
          debugPrint('ML Kit recognition notice: $e');
        } finally {
          await textRecognizer.close();
        }
      }

      final items = parsedItems.map((line) {
        return BillItem(
          id: '',
          billId: '',
          itemName: line.itemName,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          totalPrice: line.totalPrice,
        );
      }).toList();

      final computedSum = items.fold<double>(0.0, (sum, i) => sum + i.totalPrice);
      final finalTotal = detectedGrandTotal != null && detectedGrandTotal > 0
          ? detectedGrandTotal
          : ((computedSum * 100).round() / 100);

      final bill = await _repo.createBillWithItems(
        groupId: groupId,
        uploadedBy: uploadedBy,
        fileName: fileName,
        items: items,
        totalAmount: finalTotal,
      );

      state = const AsyncData(null);
      return bill;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Convenience wrapper for XFile
  Future<Bill?> processBillImage({
    required XFile file,
    required String groupId,
    required String uploadedBy,
  }) =>
      processBillFile(
        filePath: file.path,
        fileName: file.name,
        groupId: groupId,
        uploadedBy: uploadedBy,
      );

  /// Create a bill manually without OCR
  Future<Bill?> createManualBill({
    required String groupId,
    required String uploadedBy,
    required String title,
    required double totalAmount,
    required List<BillItem> items,
  }) async {
    state = const AsyncLoading();
    try {
      final bill = await _repo.createBillWithItems(
        groupId: groupId,
        uploadedBy: uploadedBy,
        fileName: title,
        items: items,
        totalAmount: totalAmount,
      );
      state = const AsyncData(null);
      return bill;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Update item assignment or details
  Future<void> updateItem({
    required String groupId,
    required String billId,
    required BillItem item,
  }) async {
    try {
      await _repo.updateBillItem(
        groupId: groupId,
        billId: billId,
        item: item,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete line item
  Future<void> deleteItem({
    required String groupId,
    required String billId,
    required String itemId,
  }) async {
    try {
      await _repo.deleteBillItem(
        groupId: groupId,
        billId: billId,
        itemId: itemId,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Add line item to bill
  Future<void> addItem({
    required String groupId,
    required String billId,
    required String itemName,
    required double quantity,
    required double unitPrice,
    required double totalPrice,
    String? assignedUserId,
  }) async {
    try {
      await _repo.addBillItem(
        groupId: groupId,
        billId: billId,
        itemName: itemName,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        assignedUserId: assignedUserId,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Confirm equal or member-wise split
  Future<bool> confirmSplit({
    required String groupId,
    required Bill bill,
    required List<SplitShare> shares,
    required String splitType,
    Map<String, String>? memberNames,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.confirmBillSplit(
        groupId: groupId,
        bill: bill,
        shares: shares,
        splitType: splitType,
        memberNames: memberNames,
      );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Payee settles payment
  Future<bool> settlePayment({
    required String groupId,
    required String paymentId,
  }) async {
    try {
      await _repo.settlePayment(
        groupId: groupId,
        paymentId: paymentId,
      );
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
