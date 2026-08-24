import '../../core/errors/app_exception.dart';
import '../../models/panel_models.dart';

enum InboundPreference { automatic, vlessReality, hysteria2 }

class InboundSelector {
  const InboundSelector();

  List<Inbound> select(List<Inbound> inbounds, InboundPreference preference) {
    final enabled = inbounds.where((inbound) => inbound.enabled).toList();
    final matches = switch (preference) {
      InboundPreference.vlessReality => _ofType(enabled, 'vless'),
      InboundPreference.hysteria2 => _ofType(enabled, 'hysteria2'),
      InboundPreference.automatic => <Inbound>[
        ..._ofType(enabled, 'vless'),
        ..._ofType(enabled, 'hysteria2'),
      ],
    };
    if (matches.isEmpty) {
      throw ProvisioningException(
        'No enabled inbound matches ${preference.name}.',
      );
    }
    return matches;
  }

  List<Inbound> _ofType(List<Inbound> source, String protocol) {
    return source
        .where((inbound) => inbound.protocol.toLowerCase() == protocol)
        .toList(growable: false);
  }
}
