import '../../core/errors/app_exception.dart';
import '../../models/profile_models.dart';

class ProfileValidator {
  const ProfileValidator();

  void validate(ProxyProfile profile) {
    if (profile.name.trim().isEmpty || profile.server.trim().isEmpty) {
      throw const ProvisioningException(
        'Profile name and server are required.',
      );
    }
    if (profile.port < 1 || profile.port > 65535) {
      throw const ProvisioningException('Profile port is out of range.');
    }
    if (profile.authentication.trim().isEmpty) {
      throw const ProvisioningException('Profile credentials are missing.');
    }
    switch (profile.protocol) {
      case ProxyProtocol.vlessReality:
        for (final key in const <String>['pbk', 'sid', 'sni']) {
          if ((profile.options[key] ?? '').trim().isEmpty) {
            throw ProvisioningException(
              'VLESS REALITY option $key is missing.',
            );
          }
        }
      case ProxyProtocol.hysteria2:
        final sni = profile.options['sni'] ?? profile.options['server_name'];
        if (sni != null && sni.trim().isEmpty) {
          throw const ProvisioningException('Hysteria2 SNI is invalid.');
        }
    }
  }

  void validateAll(Iterable<ProxyProfile> profiles) {
    final values = profiles.toList(growable: false);
    if (values.isEmpty) {
      throw const ProvisioningException('At least one proxy is required.');
    }
    for (final profile in values) {
      validate(profile);
    }
  }
}
