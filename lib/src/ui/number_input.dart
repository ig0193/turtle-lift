import 'package:flutter/services.dart';

/// Keeps a number field holding a number this app can store.
///
/// **A comma is a decimal point.** In a region that writes "77,5" the iOS
/// decimal pad offers a comma and no full stop; dropping it stored 775 kg.
///
/// **An edit that would not be a number is refused whole**, rather than
/// filtered: filtering turned a pasted "12.5" in a reps field into 125, and
/// "-5" into 5. Refusing leaves the field as it was.
///
/// **At most [decimals] places and [maxIntegerDigits] whole digits.** The
/// steppers already work in those units; without the cap a pasted run of
/// digits parsed to infinity and the reps field threw on rounding it.
class UnsignedNumberFormatter extends TextInputFormatter {
  UnsignedNumberFormatter({required this.decimals, this.maxIntegerDigits = 5})
      : _pattern = RegExp(decimals == 0
            ? '^\\d{0,$maxIntegerDigits}\$'
            : '^\\d{0,$maxIntegerDigits}(\\.\\d{0,$decimals})?\$');

  final int decimals;
  final int maxIntegerDigits;
  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Same length, so the selection still points at the same characters.
    final text = newValue.text.replaceAll(',', '.');
    if (!_pattern.hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }
}
