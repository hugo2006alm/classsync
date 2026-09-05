class SecretRedactor {
  static final _bearer = RegExp(
    r'Bearer\s+[A-Za-z0-9._~+\-/]+=*',
    caseSensitive: false,
  );
  static final _credentialPair = RegExp(
    r'((?:api[_-]?key|token|secret)["\s:=]{1,8})([^\s",}]+)',
    caseSensitive: false,
  );
  static final _knownTokens = <RegExp>[
    RegExp(r'secret_[A-Za-z0-9]+'),
    RegExp(r'ntn_[A-Za-z0-9]+'),
  ];

  static String redact(String input) {
    var output = input.replaceAll(_bearer, 'Bearer [REDACTED]');
    output = output.replaceAllMapped(
      _credentialPair,
      (match) => '${match.group(1)}[REDACTED]',
    );
    for (final pattern in _knownTokens) {
      output = output.replaceAll(pattern, '[REDACTED]');
    }
    return output;
  }
}
