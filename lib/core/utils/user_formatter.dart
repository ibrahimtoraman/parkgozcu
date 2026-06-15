String formatUserTag(String userId) {
  const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  var seed = userId.hashCode.abs();
  if (seed == 0) seed = 1;

  final buffer = StringBuffer('#');
  for (var index = 0; index < 6; index++) {
    buffer.write(chars[seed % chars.length]);
    seed ~/= chars.length;
    if (seed == 0) seed = userId.length + index + 1;
  }
  return buffer.toString();
}
