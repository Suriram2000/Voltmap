class PlaceSuggestion {
  const PlaceSuggestion({
    required this.primaryText,
    required this.secondaryText,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.aliases = const [],
  });

  final String primaryText;
  final String secondaryText;
  final double latitude;
  final double longitude;
  final String type;
  final List<String> aliases;

  String get displayName =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';

  String get identity =>
      '${primaryText.toLowerCase()}|${latitude.toStringAsFixed(4)}|${longitude.toStringAsFixed(4)}';

  bool matches(String rawQuery) {
    final query = _normalize(rawQuery);
    if (query.isEmpty) return false;
    final searchable = <String>[
      primaryText,
      secondaryText,
      ...aliases,
    ].map(_normalize);
    return searchable.any(
      (candidate) => candidate.startsWith(query) || candidate.contains(query),
    );
  }
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
