String? validateEmail(String value) {
  if (value.trim().isEmpty) return 'Email is required';
  final emailReg = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
  if (!emailReg.hasMatch(value.trim())) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) return 'Password is required';
  return null;
}

bool isFormValid(String email, String password) {
  return validateEmail(email) == null && validatePassword(password) == null;
}
