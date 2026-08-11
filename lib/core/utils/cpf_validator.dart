class CpfValidator {
  const CpfValidator._();

  static String normalize(String cpf) {
    return cpf.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValid(String cpf) {
    final digits = normalize(cpf);

    if (digits.length != 11) {
      return false;
    }

    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }

    final numbers = digits.split('').map(int.parse).toList();

    final firstDigit = _calculateDigit(numbers.sublist(0, 9), 10);

    if (numbers[9] != firstDigit) {
      return false;
    }

    final secondDigit = _calculateDigit(numbers.sublist(0, 10), 11);

    return numbers[10] == secondDigit;
  }

  static int _calculateDigit(List<int> numbers, int initialWeight) {
    var sum = 0;
    var weight = initialWeight;

    for (final number in numbers) {
      sum += number * weight;
      weight--;
    }

    final remainder = sum % 11;

    if (remainder < 2) {
      return 0;
    }

    return 11 - remainder;
  }
}
