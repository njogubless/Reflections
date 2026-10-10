/// Builds the lowercased `keywords` array used for bounded Firestore search
/// (`array-contains`). Firestore has no full-text search.
List<String> buildKeywords(Iterable<String?> fields) {
  final out = <String>{};
  for (final field in fields) {
    if (field == null) continue;
    for (final token in tokenize(field)) {
      out.add(token);
    }
  }
  // Firestore array size is generous, but keep documents compact.
  return out.take(60).toList()..sort();
}

Iterable<String> tokenize(String input) => input
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.length >= 2);

/// Normalizes a user search query into the single token used in queries.
/// Returns null when the query has no searchable token.
String? searchToken(String query) {
  final tokens = tokenize(query).toList();
  if (tokens.isEmpty) return null;
  // Use the longest token: it is the most selective.
  tokens.sort((a, b) => b.length.compareTo(a.length));
  return tokens.first;
}
