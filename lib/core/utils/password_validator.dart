class PasswordValidator {
  const PasswordValidator._();

  static const int minimumLength = 8;

  static bool hasMinimumLength(String password) {
    return password.length >= minimumLength;
  }

  static bool hasUppercase(String password) {
    return RegExp(r'[A-Z]').hasMatch(password);
  }

  static bool hasLowercase(String password) {
    return RegExp(r'[a-z]').hasMatch(password);
  }

  static bool hasNumber(String password) {
    return RegExp(r'[0-9]').hasMatch(password);
  }

  static bool hasSpecialCharacter(String password) {
    return RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);
  }

  static bool hasNoSpaces(String password) {
    return !RegExp(r'\s').hasMatch(password);
  }

  static bool isValid(String password) {
    return hasMinimumLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasNumber(password) &&
        hasSpecialCharacter(password) &&
        hasNoSpaces(password);
  }

  static String? validationMessage(String password) {
    if (password.isEmpty) {
      return 'Informe uma senha.';
    }

    if (!hasMinimumLength(password)) {
      return 'A senha deve possuir pelo menos 8 caracteres.';
    }

    if (!hasUppercase(password)) {
      return 'Inclua pelo menos uma letra maiúscula.';
    }

    if (!hasLowercase(password)) {
      return 'Inclua pelo menos uma letra minúscula.';
    }

    if (!hasNumber(password)) {
      return 'Inclua pelo menos um número.';
    }

    if (!hasSpecialCharacter(password)) {
      return 'Inclua pelo menos um caractere especial.';
    }

    if (!hasNoSpaces(password)) {
      return 'A senha não pode conter espaços.';
    }

    return null;
  }
}
