import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/utils/password_validator.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sua senha deve conter:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        _Requirement(
          text: 'Mínimo de 8 caracteres',
          valid: PasswordValidator.hasMinimumLength(password),
        ),

        _Requirement(
          text: 'Uma letra maiúscula',
          valid: PasswordValidator.hasUppercase(password),
        ),

        _Requirement(
          text: 'Uma letra minúscula',
          valid: PasswordValidator.hasLowercase(password),
        ),

        _Requirement(
          text: 'Um número',
          valid: PasswordValidator.hasNumber(password),
        ),

        _Requirement(
          text: 'Um caractere especial',
          valid: PasswordValidator.hasSpecialCharacter(password),
        ),

        _Requirement(
          text: 'Sem espaços',
          valid: PasswordValidator.hasNoSpaces(password),
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final String text;
  final bool valid;

  const _Requirement({required this.text, required this.valid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: valid ? Colors.green : Colors.grey,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: valid ? Colors.green : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
