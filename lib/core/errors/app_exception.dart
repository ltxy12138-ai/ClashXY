class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class PanelException extends AppException {
  const PanelException(super.message, {super.cause});
}

class ProvisioningException extends AppException {
  const ProvisioningException(super.message, {super.cause});
}

class MihomoException extends AppException {
  const MihomoException(super.message, {super.cause});
}
