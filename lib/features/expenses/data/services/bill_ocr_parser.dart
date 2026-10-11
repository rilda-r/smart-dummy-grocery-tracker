import 'dart:math';

class ParsedBillLine {
  const ParsedBillLine({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String itemName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
}

class BillOcrParser {
  static final RegExp _amountRegex = RegExp(r'^(?:(?:\d{1,3}(?:,\d{3})+|\d+)[.,]\d{2})$');
  static final RegExp _currencyPrefixRegex = RegExp(r'^(?:rs\.?|inr|usd|\$|€|£|₹)', caseSensitive: false);
  static final RegExp _qtyTokenRegex = RegExp(r'^(\d{1,2})[xX\u00d7]?$');
  static final RegExp _qtyPrefixRegex = RegExp(r'^(\d{1,2})\s*(?:[xX\u00d7@]\s*|\s+)(.+)$');
  static const Set<String> _separators = {'x', 'X', '\u00d7', '@', '*'};

  static final RegExp _skipRegex = RegExp(
    r'\b(sub\s*-?\s*total|grand\s*total|total|tax|gst|cgst|sgst|igst|vat|discount|change|cash|card|'
    r'visa|mastercard|upi|round(?:ing)?\s*off|invoice|receipt|bill\s*(?:no|number)|date|time|phone|'
    r'tel|thank|balance|tender|paid|savings|items?\s*count)\b',
    caseSensitive: false,
  );

  /// Parse raw OCR text into structured line items.
  static List<ParsedBillLine> parseText(String rawText) {
    final lines = rawText.split(RegExp(r'[\r\n]+'));
    final results = <ParsedBillLine>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || _skipRegex.hasMatch(line)) continue;

      final parsed = _parseLine(line);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  static ParsedBillLine? _parseLine(String line) {
    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2) return null;

    // Scan backwards from the end for up to two amounts
    final amounts = <double>[];
    int i = tokens.length;

    while (i > 0 && amounts.length < 2) {
      final token = tokens[i - 1];
      if (_separators.contains(token) && amounts.isNotEmpty) {
        i--;
        continue;
      }
      final val = _parseAmount(token);
      if (val == null) break;
      amounts.add(val);
      i--;
    }

    if (amounts.isEmpty) return null;
    amounts.setAll(0, amounts.reversed.toList());

    double? qty;
    int j = i;
    while (j > 0 && _separators.contains(tokens[j - 1])) {
      j--;
    }
    if (j > 0) {
      final match = _qtyTokenRegex.firstMatch(tokens[j - 1]);
      if (match != null && j - 1 > 0) {
        qty = double.tryParse(match.group(1)!);
        i = j - 1;
      }
    }

    final nameTokens = tokens.sublist(0, max(0, i));
    var name = nameTokens.join(' ').replaceAll(RegExp(r'^[-:*.#\s]+|[-:*.#\s]+$'), '');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');

    if (qty == null) {
      final prefixMatch = _qtyPrefixRegex.firstMatch(name);
      if (prefixMatch != null) {
        qty = double.tryParse(prefixMatch.group(1)!);
        name = prefixMatch.group(2)!.trim();
      }
    }

    // Must have at least 2 chars and contain at least one letter
    if (name.length < 2 || !name.contains(RegExp(r'[a-zA-Z]'))) {
      return null;
    }

    double total;
    double unit;

    if (amounts.length == 2) {
      unit = amounts[0];
      total = amounts[1];
      if (qty == null) {
        if (unit > 0) {
          final ratio = total / unit;
          final rounded = ratio.roundToDouble();
          if (rounded >= 1 && rounded <= 99 && (ratio - rounded).abs() < 0.05) {
            qty = rounded;
          } else {
            qty = 1.0;
            unit = total;
          }
        } else {
          qty = 1.0;
        }
      } else {
        if ((qty * unit - total).abs() > 0.1 && qty > 0) {
          unit = (total / qty);
        }
      }
    } else {
      total = amounts[0];
      qty ??= 1.0;
      unit = qty > 0 ? (total / qty) : total;
    }

    // Round to 2 decimals
    unit = (unit * 100).round() / 100;
    total = (total * 100).round() / 100;

    return ParsedBillLine(
      itemName: name,
      quantity: qty,
      unitPrice: unit,
      totalPrice: total,
    );
  }

  static double? _parseAmount(String token) {
    var clean = token.replaceAll(_currencyPrefixRegex, '').replaceAll(RegExp(r'[*:$]'), '');
    if (!_amountRegex.hasMatch(clean)) return null;

    if (clean.contains('.')) {
      clean = clean.replaceAll(',', '');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }

    return double.tryParse(clean);
  }
}
