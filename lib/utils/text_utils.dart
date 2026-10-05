const _accents = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
};

/// Minúsculas y sin tildes, para buscar "bogota" y encontrar "Bogotá".
String normalize(String input) {
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().trim().split('')) {
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString();
}

/// Iniciales para el logo de respaldo ("La Mega" -> "LM").
String initials(String name) {
  final letter = RegExp(r'[A-Za-z0-9ÁÉÍÓÚÑáéíóúñ]');
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && letter.hasMatch(w[0]))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}
