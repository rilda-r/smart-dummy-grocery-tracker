import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/app_user.dart';
import '../../domain/models/grocery_item.dart';

final groceryRepositoryProvider = Provider<GroceryRepository>((ref) {
  return GroceryRepository(firestore: FirebaseFirestore.instance);
});

class GroceryRepository {
  GroceryRepository({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _itemsCol(String groupId) =>
      firestore.collection('groups').doc(groupId).collection('groceryItems');

  /// Real-time stream of all items in a group, ordered by createdAt
  Stream<List<GroceryItem>> watchItems(String groupId) {
    if (groupId.isEmpty) return Stream.value([]);
    return _itemsCol(groupId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GroceryItem.fromFirestore(d)).toList());
  }

  /// Add item with case-insensitive duplicate prevention (Firestore transaction).
  /// Returns the new item. Throws if duplicate found.
  Future<GroceryItem> addItem({
    required String groupId,
    required AppUser user,
    required String itemName,
    required int quantity,
  }) async {
    final cleanName = itemName.trim();
    if (cleanName.isEmpty || cleanName.length > 255) {
      throw Exception('Item name must be between 1 and 255 characters.');
    }
    if (quantity < 1 || quantity > 999) {
      throw Exception('Quantity must be between 1 and 999.');
    }
    final nameLower = cleanName.toLowerCase();

    final groupRef = firestore.collection('groups').doc(groupId);
    final itemsCol = groupRef.collection('groceryItems');
    final now = DateTime.now();

    return await firestore.runTransaction<GroceryItem>((tx) async {
      // Check for case-insensitive duplicates (pending or purchased items)
      final existing = await itemsCol
          .where('itemNameLower', isEqualTo: nameLower)
          .where('status', isEqualTo: GroceryStatus.pending.value)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('"$cleanName" is already in the list.');
      }

      final newRef = itemsCol.doc();
      final item = GroceryItem(
        id: newRef.id,
        groupId: groupId,
        addedBy: user.uid,
        itemName: cleanName,
        itemNameLower: nameLower,
        quantity: quantity,
        purchasedQuantity: 0,
        status: GroceryStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(newRef, item.toFirestore());
      return item;
    });
  }

  /// Owner-only: update name and/or quantity
  Future<void> updateItem({
    required String groupId,
    required String itemId,
    required String requesterId,
    String? itemName,
    int? quantity,
  }) async {
    final cleanName = itemName?.trim();
    if (cleanName != null) {
      if (cleanName.isEmpty || cleanName.length > 255) {
        throw Exception('Item name must be between 1 and 255 characters.');
      }
    }
    if (quantity != null && (quantity < 1 || quantity > 999)) {
      throw Exception('Quantity must be between 1 and 999.');
    }

    final itemRef = _itemsCol(groupId).doc(itemId);

    await firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(itemRef);
      if (!snap.exists) throw Exception('Item not found.');
      final item = GroceryItem.fromFirestore(snap);
      if (item.addedBy != requesterId) {
        throw Exception('You can only edit items you added.');
      }
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cleanName != null) {
        // Check for duplicate if name is changing
        if (cleanName.toLowerCase() != item.itemNameLower) {
          final dup = await _itemsCol(groupId)
              .where('itemNameLower', isEqualTo: cleanName.toLowerCase())
              .where('status', isEqualTo: GroceryStatus.pending.value)
              .limit(1)
              .get();
          if (dup.docs.isNotEmpty && dup.docs.first.id != itemId) {
            throw Exception('"$cleanName" is already in the list.');
          }
        }
        updates['itemName'] = cleanName;
        updates['itemNameLower'] = cleanName.toLowerCase();
      }
      if (quantity != null) {
        updates['quantity'] = quantity;
      }
      tx.update(itemRef, updates);
    });
  }

  /// Owner-only: delete item
  Future<void> deleteItem({
    required String groupId,
    required String itemId,
    required String requesterId,
  }) async {
    final itemRef = _itemsCol(groupId).doc(itemId);
    await firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(itemRef);
      if (!snap.exists) return;
      final item = GroceryItem.fromFirestore(snap);
      if (item.addedBy != requesterId) {
        throw Exception('You can only delete items you added.');
      }
      tx.delete(itemRef);
    });
  }

  /// Any member can update status (used during shopping).
  /// If marking purchased, also set purchasedQuantity.
  Future<void> updateStatus({
    required String groupId,
    required String itemId,
    required GroceryStatus newStatus,
    int? purchasedQuantity,
  }) async {
    final updates = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'lockedBy': null,
      'lockedAt': null,
    };
    if (purchasedQuantity != null) {
      updates['purchasedQuantity'] = purchasedQuantity;
    }
    await _itemsCol(groupId).doc(itemId).update(updates);
  }

  /// Lock an item for purchase — uses a transaction to prevent double-locking.
  Future<void> lockItem({
    required String groupId,
    required String itemId,
    required String userId,
  }) async {
    final itemRef = _itemsCol(groupId).doc(itemId);
    final now = DateTime.now();

    await firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(itemRef);
      if (!snap.exists) throw Exception('Item not found.');
      final item = GroceryItem.fromFirestore(snap);

      if (item.status != GroceryStatus.pending) {
        throw Exception('This item is no longer pending.');
      }
      // Allow locking if: no lock, or lock is stale, or same user
      if (item.isLocked && !item.isLockStale(now) && item.lockedBy != userId) {
        throw Exception('Another member is buying this item right now.');
      }
      tx.update(itemRef, {
        'lockedBy': userId,
        'lockedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Release a lock (cancel shopping for this item)
  Future<void> releaseItemLock({
    required String groupId,
    required String itemId,
    required String userId,
  }) async {
    final itemRef = _itemsCol(groupId).doc(itemId);
    await firestore.runTransaction<void>((tx) async {
      final snap = await tx.get(itemRef);
      if (!snap.exists) return;
      final item = GroceryItem.fromFirestore(snap);
      if (item.lockedBy != userId) return; // nothing to release
      tx.update(itemRef, {
        'lockedBy': null,
        'lockedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Smart basket: suggest items based on previously purchased items.
  /// Returns top 10 frequently purchased item names (case-insensitive dedup).
  Future<List<String>> getSuggestions(String groupId) async {
    try {
      final snap = await _itemsCol(groupId)
          .where('status', isEqualTo: GroceryStatus.purchased.value)
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final name = (doc.data()['itemName'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          counts[name.toLowerCase()] = (counts[name.toLowerCase()] ?? 0) + 1;
        }
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(10).map((e) {
        // Return the original casing of the first seen instance
        final original = snap.docs
            .firstWhere((d) =>
                (d.data()['itemName'] as String? ?? '').toLowerCase() == e.key)
            .data()['itemName'] as String;
        return original;
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
