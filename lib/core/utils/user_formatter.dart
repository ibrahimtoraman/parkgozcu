String formatUserNumber(String userId) {
  final normalized = userId.replaceAll('-', '').toUpperCase();
  if (normalized.length <= 8) return normalized;
  return normalized.substring(normalized.length - 8);
}
