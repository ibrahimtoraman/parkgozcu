String formatUserTag(String userId) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  var seed = userId.hashCode.abs();
  if (seed == 0) seed = 1;

  final chars = <String>[
    letters[seed % letters.length],
    digits[(seed ~/ letters.length) % digits.length],
    letters[(seed ~/ 97) % letters.length],
    digits[(seed ~/ 131) % digits.length],
    letters[(seed ~/ 17) % letters.length],
    digits[(seed ~/ 23) % digits.length],
  ];

  for (var index = chars.length - 1; index > 0; index--) {
    seed = (seed * 1103515245 + userId.length + index) & 0x7fffffff;
    final swapIndex = seed % (index + 1);
    final temp = chars[index];
    chars[index] = chars[swapIndex];
    chars[swapIndex] = temp;
  }

  return '#${chars.join()}';
}
