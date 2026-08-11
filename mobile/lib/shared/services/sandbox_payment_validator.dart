abstract final class SandboxPaymentValidator {
  static const approvedUpiIds = {'driver@upi', 'success@upi'};
  static const approvedCardNumber = '4242424242424242';

  static String? validateUpi(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$').hasMatch(trimmed)) {
      return 'Enter a valid sandbox UPI ID';
    }
    return approvedUpiIds.contains(trimmed)
        ? null
        : 'UPI ID could not be verified. Use driver@upi';
  }

  static String? validateCardholder(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Enter the cardholder name' : null;

  static String? validateCardNumber(String? value) {
    final cardDigits = digits(value ?? '');
    if (cardDigits.length != 16 || !passesLuhn(cardDigits)) {
      return 'Enter a valid 16-digit sandbox card';
    }
    return cardDigits == approvedCardNumber
        ? null
        : 'Card was declined. Use sandbox card 4242 4242 4242 4242';
  }

  static String? validateExpiry(String? value, {DateTime? currentDate}) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = currentDate ?? DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card is expired';
    }
    return null;
  }

  static String? validateCvv(String? value) =>
      RegExp(r'^\d{3,4}$').hasMatch(value ?? '') ? null : 'Enter 3 or 4 digits';

  static bool passesLuhn(String value) {
    final cardDigits = digits(value);
    if (cardDigits.isEmpty) return false;
    var sum = 0;
    var doubleDigit = false;
    for (var index = cardDigits.length - 1; index >= 0; index--) {
      var digit = int.parse(cardDigits[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  static String maskUpi(String value) {
    final parts = value.trim().toLowerCase().split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return 'UPI account';
    }
    final handle = parts.first;
    final masked = handle.length <= 2 ? '••' : '${handle.substring(0, 2)}••';
    return 'UPI $masked@${parts.last}';
  }

  static String maskCard(String value) {
    final cardDigits = digits(value);
    if (cardDigits.length < 4) return 'Card';
    return 'Card ending ${cardDigits.substring(cardDigits.length - 4)}';
  }

  static String digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
