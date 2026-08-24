import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      runtimeControllerProvider.select((state) => state.settings),
    );
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    Future<void> save(AppSettings value) => controller.updateSettings(value);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          l10n.settingsTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            trailing: DropdownButton<String>(
              value: settings.localeCode,
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.systemLanguage),
                ),
                ...AppLocalizations.supportedLocales.map(
                  (locale) => DropdownMenuItem(
                    value: locale.toLanguageTag(),
                    child: Text(lookupAppLocalizations(locale).languageName),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) save(settings.copyWith(localeCode: value));
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(l10n.startup),
                subtitle: Text(l10n.startupPending),
                value: settings.launchAtStartup,
                onChanged: (value) =>
                    save(settings.copyWith(launchAtStartup: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.autoConnect),
                subtitle: Text(l10n.autoConnectSubtitle),
                value: settings.autoConnect,
                onChanged: (value) =>
                    save(settings.copyWith(autoConnect: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.newDeviceProtocol),
                subtitle: Text(l10n.newDeviceProtocolSubtitle),
                trailing: DropdownButton<String>(
                  value: settings.protocol,
                  items: [
                    DropdownMenuItem(
                      value: 'automatic',
                      child: Text(l10n.automatic),
                    ),
                    const DropdownMenuItem(
                      value: 'vlessReality',
                      child: Text('VLESS Reality'),
                    ),
                    const DropdownMenuItem(
                      value: 'hysteria2',
                      child: Text('Hysteria2'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) save(settings.copyWith(protocol: value));
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.windowsTun),
                subtitle: Text(l10n.windowsTunSubtitle),
                value: settings.tunEnabled,
                onChanged: (value) =>
                    save(settings.copyWith(tunEnabled: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('IPv6'),
                value: settings.ipv6Enabled,
                onChanged: (value) =>
                    save(settings.copyWith(ipv6Enabled: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.coreLogs),
                subtitle: Text(l10n.coreLogsSubtitle),
                value: settings.logsEnabled,
                onChanged: (value) =>
                    save(settings.copyWith(logsEnabled: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.advancedSettings,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(l10n.advancedSettingsSubtitle),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _IntegerSettingTile(
                title: l10n.mixedPort,
                value: settings.mixedPort,
                min: 1024,
                max: 65535,
                disallowed: <int>{
                  settings.controllerPort,
                  settings.dnsListenPort,
                },
                onChanged: (value) => save(settings.copyWith(mixedPort: value)),
              ),
              const Divider(height: 1),
              _IntegerSettingTile(
                title: l10n.controllerPort,
                value: settings.controllerPort,
                min: 1024,
                max: 65535,
                disallowed: <int>{settings.mixedPort, settings.dnsListenPort},
                onChanged: (value) =>
                    save(settings.copyWith(controllerPort: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.allowLan),
                subtitle: Text(l10n.allowLanWarning),
                value: settings.allowLan,
                onChanged: (value) => save(settings.copyWith(allowLan: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.tunStack),
                trailing: DropdownButton<String>(
                  value: settings.tunStack,
                  items: [
                    DropdownMenuItem(
                      value: 'mixed',
                      child: Text(l10n.tunStackMixed),
                    ),
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(l10n.tunStackSystem),
                    ),
                    DropdownMenuItem(
                      value: 'gvisor',
                      child: Text(l10n.tunStackGvisor),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) save(settings.copyWith(tunStack: value));
                  },
                ),
              ),
              const Divider(height: 1),
              _IntegerSettingTile(
                title: l10n.tunMtu,
                value: settings.tunMtu,
                min: 1280,
                max: 9000,
                onChanged: (value) => save(settings.copyWith(tunMtu: value)),
              ),
              const Divider(height: 1),
              _TextSettingTile(
                title: l10n.tunDeviceName,
                value: settings.tunDevice,
                onChanged: (value) => save(settings.copyWith(tunDevice: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.tunStrictRoute),
                value: settings.tunStrictRoute,
                onChanged: (value) =>
                    save(settings.copyWith(tunStrictRoute: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.tunAutoRoute),
                value: settings.tunAutoRoute,
                onChanged: (value) =>
                    save(settings.copyWith(tunAutoRoute: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.tunAutoDetect),
                value: settings.tunAutoDetectInterface,
                onChanged: (value) =>
                    save(settings.copyWith(tunAutoDetectInterface: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(l10n.dnsOverride),
                subtitle: Text(l10n.dnsOverrideSubtitle),
                value: settings.dnsOverrideEnabled,
                onChanged: (value) =>
                    save(settings.copyWith(dnsOverrideEnabled: value)),
              ),
              if (settings.dnsOverrideEnabled) ...[
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.dnsEnabled),
                  value: settings.dnsEnabled,
                  onChanged: (value) =>
                      save(settings.copyWith(dnsEnabled: value)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.dnsMode),
                  trailing: DropdownButton<String>(
                    value: settings.dnsMode,
                    items: [
                      DropdownMenuItem(
                        value: 'fake-ip',
                        child: Text(l10n.dnsModeFakeIp),
                      ),
                      DropdownMenuItem(
                        value: 'redir-host',
                        child: Text(l10n.dnsModeRedirHost),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        save(settings.copyWith(dnsMode: value));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                _IntegerSettingTile(
                  title: l10n.dnsListenPort,
                  value: settings.dnsListenPort,
                  min: 1024,
                  max: 65535,
                  disallowed: <int>{
                    settings.mixedPort,
                    settings.controllerPort,
                  },
                  onChanged: (value) =>
                      save(settings.copyWith(dnsListenPort: value)),
                ),
                const Divider(height: 1),
                _TextSettingTile(
                  title: l10n.dnsNameserver,
                  value: settings.dnsNameserver,
                  onChanged: (value) =>
                      save(settings.copyWith(dnsNameserver: value)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(l10n.snifferOverride),
                subtitle: Text(l10n.snifferOverrideSubtitle),
                value: settings.snifferOverrideEnabled,
                onChanged: (value) =>
                    save(settings.copyWith(snifferOverrideEnabled: value)),
              ),
              if (settings.snifferOverrideEnabled) ...[
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.snifferEnabled),
                  value: settings.snifferEnabled,
                  onChanged: (value) =>
                      save(settings.copyWith(snifferEnabled: value)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.settingsNextConnect),
      ],
    );
  }
}

class _IntegerSettingTile extends StatelessWidget {
  const _IntegerSettingTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.disallowed = const <int>{},
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final Set<int> disallowed;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    trailing: Text('$value'),
    onTap: () async {
      final updated = await _editInteger(
        context,
        title: title,
        value: value,
        min: min,
        max: max,
        disallowed: disallowed,
      );
      if (updated != null) onChanged(updated);
    },
  );
}

class _TextSettingTile extends StatelessWidget {
  const _TextSettingTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: () async {
      final updated = await _editText(context, title: title, value: value);
      if (updated != null) onChanged(updated);
    },
  );
}

Future<int?> _editInteger(
  BuildContext context, {
  required String title,
  required int value,
  required int min,
  required int max,
  required Set<int> disallowed,
}) async {
  final controller = TextEditingController(text: '$value');
  final formKey = GlobalKey<FormState>();
  final l10n = context.l10n;
  try {
    return await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            validator: (text) {
              final parsed = int.tryParse(text ?? '');
              if (parsed == null || parsed < min || parsed > max) {
                return min == 1024 && max == 65535
                    ? l10n.validPort
                    : l10n.validMtu;
              }
              if (disallowed.contains(parsed)) return l10n.portMustDiffer;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, int.parse(controller.text));
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<String?> _editText(
  BuildContext context, {
  required String title,
  required String value,
}) async {
  final controller = TextEditingController(text: value);
  final formKey = GlobalKey<FormState>();
  final l10n = context.l10n;
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            validator: (text) => text == null || text.trim().isEmpty
                ? l10n.valueCannotBeEmpty
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
