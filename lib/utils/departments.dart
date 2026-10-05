import 'text_utils.dart';

/// Nombres de departamento (y variantes) -> nombre oficial.
const _departments = <String, String>{
  'valle del cauca': 'Valle del Cauca', 'valle': 'Valle del Cauca',
  'bogota': 'Bogotá', 'bogota d c': 'Bogotá', 'bogota dc': 'Bogotá', 'distrito capital': 'Bogotá',
  'cundinamarca': 'Cundinamarca',
  'antioquia': 'Antioquia',
  'atlantico': 'Atlántico',
  'bolivar': 'Bolívar',
  'santander': 'Santander',
  'norte de santander': 'Norte de Santander',
  'risaralda': 'Risaralda',
  'caldas': 'Caldas',
  'quindio': 'Quindío',
  'tolima': 'Tolima',
  'huila': 'Huila',
  'narino': 'Nariño',
  'cauca': 'Cauca',
  'meta': 'Meta',
  'magdalena': 'Magdalena',
  'cordoba': 'Córdoba',
  'cesar': 'Cesar',
  'boyaca': 'Boyacá',
  'sucre': 'Sucre',
  'la guajira': 'La Guajira', 'guajira': 'La Guajira',
  'choco': 'Chocó',
  'caqueta': 'Caquetá',
  'casanare': 'Casanare',
  'putumayo': 'Putumayo',
  'arauca': 'Arauca',
  'san andres': 'San Andrés', 'san andres y providencia': 'San Andrés',
  'amazonas': 'Amazonas',
  'guaviare': 'Guaviare',
  'vaupes': 'Vaupés',
  'vichada': 'Vichada',
  'guainia': 'Guainía',
};

/// Ciudades -> departamento. También se buscan en el nombre y etiquetas de la emisora.
const _cities = <String, String>{
  'cali': 'Valle del Cauca', 'santiago de cali': 'Valle del Cauca',
  'palmira': 'Valle del Cauca', 'tulua': 'Valle del Cauca', 'buenaventura': 'Valle del Cauca',
  'buga': 'Valle del Cauca', 'cartago': 'Valle del Cauca', 'jamundi': 'Valle del Cauca',
  'yumbo': 'Valle del Cauca',
  'soacha': 'Cundinamarca', 'zipaquira': 'Cundinamarca', 'girardot': 'Cundinamarca',
  'fusagasuga': 'Cundinamarca', 'facatativa': 'Cundinamarca',
  'medellin': 'Antioquia', 'envigado': 'Antioquia', 'itagui': 'Antioquia', 'rionegro': 'Antioquia',
  'barranquilla': 'Atlántico',
  'cartagena': 'Bolívar', 'cartagena de indias': 'Bolívar',
  'bucaramanga': 'Santander', 'floridablanca': 'Santander', 'barrancabermeja': 'Santander',
  'cucuta': 'Norte de Santander',
  'pereira': 'Risaralda', 'dosquebradas': 'Risaralda',
  'manizales': 'Caldas',
  'armenia': 'Quindío',
  'ibague': 'Tolima',
  'neiva': 'Huila',
  'pasto': 'Nariño', 'ipiales': 'Nariño', 'tumaco': 'Nariño',
  'popayan': 'Cauca',
  'villavicencio': 'Meta',
  'santa marta': 'Magdalena',
  'monteria': 'Córdoba',
  'valledupar': 'Cesar',
  'tunja': 'Boyacá', 'duitama': 'Boyacá', 'sogamoso': 'Boyacá',
  'sincelejo': 'Sucre',
  'riohacha': 'La Guajira',
  'quibdo': 'Chocó',
  'yopal': 'Casanare',
  'mocoa': 'Putumayo',
  'leticia': 'Amazonas',
};

// Las claves más largas primero: "norte de santander" antes que "santander".
final _stateKeys = [..._departments.keys, ..._cities.keys]
  ..sort((a, b) => b.length.compareTo(a.length));
final _cityKeys = _cities.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

String _clean(String text) => normalize(text).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String? _match(String text, List<String> keys) {
  if (text.isEmpty) return null;
  final padded = ' $text ';
  for (final key in keys) {
    if (padded.contains(' $key ')) return _departments[key] ?? _cities[key];
  }
  return null;
}

/// Deduce el departamento a partir de la ubicación declarada, el nombre o las etiquetas.
/// Devuelve '' si no se puede saber.
String findDepartment({
  required String state,
  required String name,
  required List<String> tags,
}) {
  return _match(_clean(state), _stateKeys) ??
      _match(_clean(name), _cityKeys) ??
      _match(_clean(tags.join(' ')), _cityKeys) ??
      '';
}
