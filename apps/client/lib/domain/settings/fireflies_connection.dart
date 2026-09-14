class FirefliesConnection {
  const FirefliesConnection({
    required this.id,
    required this.name,
    required this.apiKey,
    this.firefliesUserId,
    this.accountEmail,
    this.validatedAt,
  });

  static const legacyId = 'legacy-primary';
  static const maxConnections = 20;
  static const maxNameLength = 80;
  static const maxApiKeyLength = 4096;

  final String id;
  final String name;
  final String apiKey;
  final String? firefliesUserId;
  final String? accountEmail;
  final DateTime? validatedAt;

  FirefliesConnectionSummary get summary => FirefliesConnectionSummary(
    id: id,
    name: name,
    accountEmail: accountEmail,
    validatedAt: validatedAt,
  );

  FirefliesConnection copyWith({
    String? name,
    String? apiKey,
    String? firefliesUserId,
    String? accountEmail,
    DateTime? validatedAt,
  }) => FirefliesConnection(
    id: id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    firefliesUserId: firefliesUserId ?? this.firefliesUserId,
    accountEmail: accountEmail ?? this.accountEmail,
    validatedAt: validatedAt ?? this.validatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'apiKey': apiKey,
    if (firefliesUserId != null) 'firefliesUserId': firefliesUserId,
    if (accountEmail != null) 'accountEmail': accountEmail,
    if (validatedAt != null)
      'validatedAt': validatedAt!.toUtc().toIso8601String(),
  };

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
    if ((firefliesUserId?.trim().isEmpty ?? false) ||
        (firefliesUserId?.length ?? 0) > 256) {
      throw const FormatException('Invalid Fireflies account ID.');
    }
    if ((accountEmail?.trim().isEmpty ?? false) ||
        (accountEmail?.length ?? 0) > 320) {
      throw const FormatException('Invalid Fireflies account email.');
    }
  }

  factory FirefliesConnection.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final apiKey = json['apiKey']?.toString().trim() ?? '';
    final validatedAtValue = json['validatedAt']?.toString();
    final validatedAt = validatedAtValue == null
        ? null
        : DateTime.tryParse(validatedAtValue)?.toUtc();
    if (validatedAtValue != null && validatedAt == null) {
      throw const FormatException('Invalid Fireflies validation timestamp.');
    }
    final result = FirefliesConnection(
      id: id,
      name: name,
      apiKey: apiKey,
      firefliesUserId: _optionalString(json['firefliesUserId']),
      accountEmail: _optionalString(json['accountEmail']),
      validatedAt: validatedAt,
    );
    result.validate();
    return result;
  }
}

class FirefliesConnectionSummary {
  const FirefliesConnectionSummary({
    required this.id,
    required this.name,
    this.accountEmail,
    this.validatedAt,
  });

  final String id;
  final String name;
  final String? accountEmail;
  final DateTime? validatedAt;
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
