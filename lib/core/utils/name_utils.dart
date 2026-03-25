/// Returns "FirstName FirstLastname" from a full name string.
/// Examples:
///   "Juan Sebastián Velásquez Rodríguez" → "Juan Velásquez"
///   "María" → "María"
///   null / empty → "N/A"
String shortName(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return 'N/A';
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
  return parts[0];
}
