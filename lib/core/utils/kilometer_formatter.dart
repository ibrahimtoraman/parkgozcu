import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class KilometerFormatter {
  static final _displayFormat = NumberFormat('#,###', 'tr_TR');

  static String formatForInput(int? kilometer) {
    if (kilometer == null) return '';
    return _displayFormat.format(kilometer);
  }

  static String formatForDisplay(int kilometer) {
    return '${_displayFormat.format(kilometer)} KM';
  }

  static int? parse(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}

class KilometerInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.parse(digits);
    final formatted = KilometerFormatter.formatForInput(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
