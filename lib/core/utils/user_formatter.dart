String formatUserTag(String userId) {
  var seed = userId.hashCode.abs();
  if (seed == 0) seed = 1;

  final digits = List<String>.generate(6, (index) {
    seed = (seed * 1103515245 + userId.length + index) & 0x7fffffff;
    return '${seed % 10}';
  });

  return '#${digits.join()}';
}
