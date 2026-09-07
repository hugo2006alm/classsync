class FirefliesConnection {
  const FirefliesConnection({
    required this.id,
    required this.name,
    required this.apiKey,
  });

  static const legacyId = 'legacy-primary';
  static const maxConnections = 20;
  static const maxNameLength = 80;
  static const maxApiKeyLength = 4096;

  final String id;
  final String name;
  final String apiKey;

  FirefliesConnectionSummary get summary =>
      FirefliesConnectionSummary(id: id, name: name);

  FirefliesConnection copyWith({String? name, String? apiKey}) =>
      FirefliesConnection(
        id: id,
        name: name ?? this.name,
        apiKey: apiKey ?? this.apiKey,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'apiKey': apiKey};

  void validate() {
    if (id.trim().isEmpty || id.length > 128) {
      throw const FormatException('Invalid Fireflies connection ID.');
    }
    if (name.trim().isEmpty || name.length > maxNameLength) {
      throw const FormatException(
        'Fireflies connection name must be 1–80 characters.',
      );
    }
    if (apiKey.trim().isEmpty || apiKey.length > maxApiKeyLength) {
      throw const FormatException('Invalid Fireflies API key length.');
    }
  }

  factory FirefliesConnection.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final apiKey = json['apiKey']?.toString().trim() ?? '';
    final result = FirefliesConnection(id: id, name: name, apiKey: apiKey);
    result.validate();
    return result;
  }
}

class FirefliesConnectionSummary {
  const FirefliesConnectionSummary({required this.id, required this.name});

  final String id;
  final String name;
}
