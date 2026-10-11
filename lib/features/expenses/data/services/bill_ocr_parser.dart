import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };
}

class ParsedBillResult {
  const ParsedBillResult({
    required this.items,
    this.detectedGrandTotal,
    required this.rawText,
  });

  final List<ParsedBillLine> items;
  final double? detectedGrandTotal;
  final String rawText;

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  ParsedBillLine get first => items.first;
  ParsedBillLine operator [](int index) => items[index];

  double get computedTotal =>
      items.fold<double>(0.0, (sum, i) => sum + i.totalPrice);

  double get effectiveTotal =>
      detectedGrandTotal != null && detectedGrandTotal! > 0
          ? detectedGrandTotal!
          : computedTotal;
}

class BillOcrParser {
  static final RegExp _amountRegex =
      RegExp(r'^(?:(?:\d{1,3}(?:,\d{3})+|\d+)[.,]\d{2})$');
  static final RegExp _currencyPrefixRegex =
      RegExp(r'^(?:rs\.?|inr|usd|cad|aud|\$|€|£|₹)', caseSensitive: false);
  static const Set<String> _separators = {'x', 'X', '\u00d7', '@', '*'};

  // Quantity patterns: e.g. "2 x", "2 @", "2 pcs", "2pc", "2pk", "1.5 kg", "500 g", "1 l", "750 ml", "2"
  static final RegExp _qtyPrefixRegex = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(?:[xX\u00d7@]\s*|(?:pcs|pc|pk|pkg|kg|g|l|ml)\b\s*|\s+)(.+)$',
    caseSensitive: false,
  );

  static final RegExp _qtyTokenRegex =
      RegExp(r'^(\d+(?:\.\d+)?)(?:[xX\u00d7]|pcs|pc|pk)?$', caseSensitive: false);

  // Phone numbers, dates, times, tax IDs
  static final RegExp _noisePatternRegex = RegExp(
    r'(?:\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b)|'
    r'(?:\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b)|'
    r'(?:\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?\b)|'
    r'(?:\b(?:gstin|gst|vat|tin|tax\s*id|pan|fssai|cin|trn)\b)',
    caseSensitive: false,
  );

  // Lines to strictly ignore (headers & non-item noise)
  static final RegExp _skipRegex = RegExp(
    r'\b(tax\s*invoice|cash\s*memo|retail\s*invoice|sales\s*receipt|store|counter|cashier|terminal|'
    r'sub\s*-?\s*total|tax|gst|cgst|sgst|igst|vat|discount|change|cash|card|'
    r'visa|mastercard|amex|upi|round(?:ing)?\s*off|invoice|receipt|bill\s*(?:no|number)|'
    r'date|time|phone|tel|thank\s*you|visit\s*again|balance|tender|tendered|paid|savings|'
    r'items?\s*count|order\s*#|token\s*#)\b',
    caseSensitive: false,
  );

  // Grand total lines: used to capture the final bill total
  static final RegExp _grandTotalRegex = RegExp(
    r'\b(grand\s*total|net\s*(?:amount|total|payable)|amount\s*(?:due|payable)|'
    r'total\s*(?:amount|due|payable|bill)|balance\s*due)\b',
    caseSensitive: false,
  );

  /// Spatial line reconstruction from ML Kit bounding boxes
  static List<String> rebuildRowsFromMlKit(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // Sort by Y coordinate (top)
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <List<TextLine>>[];

    for (final line in allLines) {
      final lineBox = line.boundingBox;
      final lineCenterY = (lineBox.top + lineBox.bottom) / 2;

      bool placed = false;
      for (final row in rows) {
        final rowCenterY = row.fold<double>(
                0.0, (s, l) => s + (l.boundingBox.top + l.boundingBox.bottom) / 2) /
            row.length;
        final avgHeight = row.fold<double>(
                0.0, (s, l) => s + l.boundingBox.height) /
            row.length;
        final tolerance = (avgHeight * 0.6).clamp(8.0, 30.0);

        if ((lineCenterY - rowCenterY).abs() < tolerance) {
          row.add(line);
          placed = true;
          break;
        }
      }

      if (!placed) {
        rows.add([line]);
      }
    }

    // Sort rows from top to bottom
    rows.sort((r1, r2) => r1.first.boundingBox.top.compareTo(r2.first.boundingBox.top));

    // Sort lines inside each row from left to right (X coordinate)
    final textRows = <String>[];
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowText = row.map((l) => l.text).join('   ').trim();
      if (rowText.isNotEmpty) {
        textRows.add(rowText);
      }
    }

    return textRows;
  }

  /// Parse text lines into a structured [ParsedBillResult]
  static ParsedBillResult parseText(String rawText, {List<String>? prebuiltRows}) {
    final lines = prebuiltRows ?? rawText.split(RegExp(r'[\r\n]+'));
    final items = <ParsedBillLine>[];
    double? grandTotal;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check if this line is the Grand Total line
      if (_grandTotalRegex.hasMatch(line)) {
        final totalAmount = _extractTrailingAmount(line);
        if (totalAmount != null && totalAmount > 0) {
          grandTotal = totalAmount;
        }
        continue;
      }

      // Check for noise lines to skip
      if (_skipRegex.hasMatch(line) || _noisePatternRegex.hasMatch(line)) {
        continue;
      }

      final parsed = _parseLine(line);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    return ParsedBillResult(
      items: items,
      detectedGrandTotal: grandTotal,
      rawText: rawText,
    );
  }

  static double? _extractTrailingAmount(String line) {
    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (int i = tokens.length - 1; i >= 0; i--) {
      final val = _parseAmount(tokens[i]);
      if (val != null) return val;
    }
    return null;
  }

  static ParsedBillLine? _parseLine(String line) {
    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2) return null;

    // Scan backwards from the end for up to two amounts (unit price, total price)
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
    var clean = token
        .replaceAll(_currencyPrefixRegex, '')
        .replaceAll(RegExp(r'[*:$]'), '')
        .trim();
    if (!_amountRegex.hasMatch(clean)) return null;

    if (clean.contains('.')) {
      clean = clean.replaceAll(',', '');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }

    return double.tryParse(clean);
  }
}
