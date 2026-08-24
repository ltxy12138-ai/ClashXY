class SecretRedactor {
  const SecretRedactor();

  static final RegExp _keyValueSecret = RegExp(
    r'(password|passwd|token|authorization|uuid|secret|private[_-]?key)\s*([:=])\s*([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _bearer = RegExp(
    r'bearer\s+[a-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _uriCredentials = RegExp(r'://[^/@\s]+@');

  String redact(Object? value) {
    var text = value?.toString() ?? '';
    text = text.replaceAllMapped(
      _keyValueSecret,
      (match) => '${match[1]}${match[2]}<redacted>',
    );
    text = text.replaceAll(_bearer, 'Bearer <redacted>');
    text = text.replaceAll(_uriCredentials, '://<redacted>@');
    return text;
  }
}
