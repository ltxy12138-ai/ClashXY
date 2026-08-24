import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/app_runtime_controller.dart';
import '../../models/profile_models.dart';
import '../../l10n/l10n.dart';

Future<bool> showProfileEditDialog(
  BuildContext context,
  AppRuntimeController controller,
  ConnectionProfile profile,
) async {
  final l10n = context.l10n;
  final name = TextEditingController(text: profile.displayName);
  final url = TextEditingController(text: profile.subscriptionUrl?.toString());
  final formKey = GlobalKey<FormState>();
  var intervalMinutes = profile.autoUpdateInterval.inMinutes;
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.editProfile),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.subscriptionName,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.profileNameValidation
                        : null,
                  ),
                  if (profile.origin == ProfileOrigin.subscription) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: url,
                      decoration: InputDecoration(
                        labelText: l10n.subscriptionUrl,
                      ),
                      validator: (value) {
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        return uri?.scheme == 'https' &&
                                uri?.host.isNotEmpty == true &&
                                uri?.userInfo.isEmpty == true
                            ? null
                            : l10n.subscriptionUrlNoCredentials;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _intervalOptions.contains(intervalMinutes)
                          ? intervalMinutes
                          : 0,
                      decoration: InputDecoration(labelText: l10n.autoUpdate),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(l10n.manualUpdate),
                        ),
                        DropdownMenuItem(
                          value: 360,
                          child: Text(l10n.everyHours(6)),
                        ),
                        DropdownMenuItem(
                          value: 720,
                          child: Text(l10n.everyHours(12)),
                        ),
                        DropdownMenuItem(
                          value: 1440,
                          child: Text(l10n.everyDay),
                        ),
                        DropdownMenuItem(
                          value: 4320,
                          child: Text(l10n.everyDays(3)),
                        ),
                        DropdownMenuItem(
                          value: 10080,
                          child: Text(l10n.everyWeek),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => intervalMinutes = value ?? 0),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.createdAt(_formatDateTime(profile.createdAt))}\n'
                    '${l10n.contentUpdatedAt(_formatDateTime(profile.lastUpdatedAt))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return false;
    return await controller.updateStandaloneProfile(
      profile: profile,
      name: name.text,
      subscriptionUrl: profile.origin == ProfileOrigin.subscription
          ? Uri.parse(url.text.trim())
          : null,
      autoUpdateInterval: Duration(minutes: intervalMinutes),
    );
  } finally {
    name.dispose();
    url.dispose();
  }
}

Future<void> exportProfileWithWarning(
  BuildContext context,
  ConnectionProfile profile,
) async {
  final l10n = context.l10n;
  final config = profile.rawConfig;
  if (config == null) return;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.exportSensitiveTitle),
      content: Text(l10n.exportSensitiveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.understandAndExport),
        ),
      ],
    ),
  );
  if (accepted != true) return;
  final safeName = profile.displayName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final location = await getSaveLocation(
    suggestedName: '$safeName.yaml',
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(
        label: l10n.yamlProfileFile,
        extensions: const <String>['yaml', 'yml'],
      ),
    ],
  );
  if (location == null) return;
  final content = const JsonEncoder.withIndent('  ').convert(config);
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    mimeType: 'application/yaml',
    name: '$safeName.yaml',
  );
  await file.saveTo(location.path);
}

Future<bool> showAdvancedYamlEditor(
  BuildContext context,
  AppRuntimeController controller,
  ConnectionProfile profile,
) async {
  final config = profile.rawConfig;
  if (config == null) return false;
  final l10n = context.l10n;
  final yaml = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(config),
  );
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editAdvancedYaml),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.editAdvancedYamlSubtitle),
              if (profile.origin == ProfileOrigin.subscription) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.subscriptionYamlRefreshWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: yaml,
                minLines: 18,
                maxLines: 26,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Clash / Mihomo YAML',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    return await controller.replaceStandaloneYaml(
      profile: profile,
      yaml: yaml.text,
    );
  } finally {
    yaml.dispose();
  }
}

const List<int> _intervalOptions = <int>[0, 360, 720, 1440, 4320, 10080];

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
