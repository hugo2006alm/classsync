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
  static final _paymentReference = RegExp(
    r'(?:refer[eéê]ncia(?:\s+multibanco|\s+pagamento)?|entidade)\s*[:=]\s*[0-9\s-]{5,}',
    caseSensitive: false,
  );

  static String redact(String input) {
    var output = input.replaceAll(_bearer, 'Bearer [REDACTED]');
    output = output.replaceAllMapped(
      _credentialPair,
      (match) => '${match.group(1)}[REDACTED]',
    );
    for (final pattern in _knownTokens) {
      output = output.replaceAll(pattern, '[REDACTED]');
    }
    output = output.replaceAllMapped(
      _paymentReference,
      (match) => '${match.group(0)!.split(RegExp(r'[:=]')).first}=[REDACTED]',
    );
    return output;
  }
}
