class SplitShare {
  const SplitShare({
    required this.userId,
    required this.amount,
    this.itemsSubtotal,
  });

  final String userId;
  final double amount;
  final double? itemsSubtotal;
}

class BillSplitResult {
  const BillSplitResult({
    required this.billId,
    required this.splitType,
    required this.totalAmount,
    required this.paidBy,
    required this.shares,
  });

  final String billId;
  final String splitType;
  final double totalAmount;
  final String paidBy;
  final List<SplitShare> shares;
}

class ExpenseSplitCalculator {
  static int _toCents(double amount) => (amount * 100).round();
  static double _fromCents(int cents) => cents / 100.0;

  /// Proportional split of [total] among weights using the largest remainder method.
  /// Guarantees that sum(shares) == total exactly with 0 rounding errors.
  static Map<String, double> allocateProportionally(
    double total,
    Map<String, double> weights,
  ) {
    final totalCents = _toCents(total);
    final w = <String, int>{};
    for (final entry in weights.entries) {
      if (entry.value > 0) {
        w[entry.key] = _toCents(entry.value);
      }
    }

    final weightSum = w.values.fold<int>(0, (sum, val) => sum + val);
    if (totalCents <= 0 || weightSum <= 0) {
      return {};
    }

    final base = <String, int>{};
    final remainder = <String, int>{};

    for (final entry in w.entries) {
      final product = totalCents * entry.value;
      base[entry.key] = product ~/ weightSum;
      remainder[entry.key] = product % weightSum;
    }

    var allocatedCents = base.values.fold<int>(0, (sum, val) => sum + val);
    var leftover = totalCents - allocatedCents;

    // Distribute leftover cents to largest remainders first, tiebreak alphabetically
    final sortedKeys = remainder.keys.toList()
      ..sort((a, b) {
        final cmp = remainder[b]!.compareTo(remainder[a]!);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });

    for (int i = 0; i < leftover && i < sortedKeys.length; i++) {
      base[sortedKeys[i]] = (base[sortedKeys[i]] ?? 0) + 1;
    }

    return base.map((k, cents) => MapEntry(k, _fromCents(cents)));
  }

  /// Equal split across a list of member IDs
  static BillSplitResult calculateEqualSplit({
    required String billId,
    required double totalAmount,
    required String paidBy,
    required List<String> memberIds,
  }) {
    if (memberIds.isEmpty || totalAmount <= 0) {
      return BillSplitResult(
        billId: billId,
        splitType: 'equal',
        totalAmount: totalAmount,
        paidBy: paidBy,
        shares: [],
      );
    }

    final weights = {for (final m in memberIds) m: 1.0};
    final sharesMap = allocateProportionally(totalAmount, weights);

    final shares = sharesMap.entries
        .map((e) => SplitShare(userId: e.key, amount: e.value))
        .toList();

    return BillSplitResult(
      billId: billId,
      splitType: 'equal',
      totalAmount: totalAmount,
      paidBy: paidBy,
      shares: shares,
    );
  }

  /// Member-wise split based on user-assigned item subtotals
  static BillSplitResult calculateMemberWiseSplit({
    required String billId,
    required double totalAmount,
    required String paidBy,
    required Map<String, double> memberSubtotals,
  }) {
    final sharesMap = allocateProportionally(totalAmount, memberSubtotals);

    final shares = sharesMap.entries
        .map((e) => SplitShare(
              userId: e.key,
              amount: e.value,
              itemsSubtotal: memberSubtotals[e.key],
            ))
        .toList();

    return BillSplitResult(
      billId: billId,
      splitType: 'member_wise',
      totalAmount: totalAmount,
      paidBy: paidBy,
      shares: shares,
    );
  }
}
