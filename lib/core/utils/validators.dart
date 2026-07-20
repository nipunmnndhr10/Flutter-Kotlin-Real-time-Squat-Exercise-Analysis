const String _requiredEmailMessage = 'Email is required';
const String _requiredPasswordMessage = 'Password is required';
const String _invalidEmailMessage = 'Enter a valid email address';

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _lowercasePattern = RegExp(r'[a-z]');
final RegExp _uppercasePattern = RegExp(r'[A-Z]');
final RegExp _digitPattern = RegExp(r'\d');
const Set<String> _specialCharacters = {
  '!',
  '@',
  '#',
  r'$',
  '%',
  '^',
  '&',
  '*',
  '(',
  ')',
  ',',
  '.',
  '?',
  '"',
  ':',
  '{',
  '}',
  '|',
  '<',
  '>',
  '-',
  '_',
  '=',
  '+',
  '/',
  '[',
  ']',
  ';',
  '~',
  '`',
  "'",
};

bool _hasSpecialCharacter(String value) {
  for (final character in value.split('')) {
    if (_specialCharacters.contains(character)) {
      return true;
    }
  }
  return false;
}

String? validateEmail(String value) {
  final trimmedValue = value.trim();

  if (trimmedValue.isEmpty) return _requiredEmailMessage;
  if (!_emailPattern.hasMatch(trimmedValue)) return _invalidEmailMessage;

  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) return _requiredPasswordMessage;
  return null;
}

String? validateSignupPassword(String value) {
  if (value.isEmpty) return _requiredPasswordMessage;
  if (value.length < 8) return 'Use at least 8 characters';
  if (!_lowercasePattern.hasMatch(value)) return 'Add a lowercase letter';
  if (!_uppercasePattern.hasMatch(value)) return 'Add an uppercase letter';
  if (!_digitPattern.hasMatch(value)) return 'Add a number';
  if (!_hasSpecialCharacter(value)) {
    return 'Add a special character';
  }

  return null;
}

int passwordStrengthScore(String value) {
  if (value.isEmpty) return 0;

  var score = 0;

  if (value.length >= 8) score++;
  if (value.length >= 12) score++;
  if (_lowercasePattern.hasMatch(value) && _uppercasePattern.hasMatch(value)) {
    score++;
  }
  if (_digitPattern.hasMatch(value)) score++;
  if (_hasSpecialCharacter(value)) score++;

  return score.clamp(0, 4);
}

String passwordStrengthLabel(String value) {
  final score = passwordStrengthScore(value);

  if (score <= 1) return 'WEAK';
  if (score == 2) return 'MEDIUM';
  if (score == 3) return 'GOOD';
  return 'STRONG';
}

bool isFormValid(String email, String password) {
  return validateEmail(email) == null && validatePassword(password) == null;
}
