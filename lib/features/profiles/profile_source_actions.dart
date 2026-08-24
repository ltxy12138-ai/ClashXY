import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/app_runtime_controller.dart';
import '../../l10n/l10n.dart';

Future<bool> showSubscriptionDialog(
  BuildContext context,
  AppRuntimeController controller,
) async {
  final l10n = context.l10n;
  final name = TextEditingController(text: l10n.subscriptionNameHint);
  final url = TextEditingController();
  final formKey = GlobalKey<FormState>();
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addSubscription),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.subscriptionName),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.profileNameValidation
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: url,
                  decoration: InputDecoration(
                    labelText: l10n.subscriptionUrl,
                    hintText: 'https://example.com/subscription',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri?.scheme == 'https' &&
                            uri?.host.isNotEmpty == true
                        ? null
                        : l10n.subscriptionUrlValidation;
                  },
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
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    return await controller.addSubscription(name: name.text, url: url.text);
  } finally {
    name.dispose();
    url.dispose();
  }
}

Future<bool> importLocalProfile(
  BuildContext context,
  AppRuntimeController controller,
) async {
  final group = XTypeGroup(
    label: context.l10n.yamlProfileFile,
    extensions: <String>['yaml', 'yml'],
  );
  final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
  if (file == null) return false;
  final yaml = await file.readAsString();
  final fileName = file.name.replaceFirst(RegExp(r'\.(yaml|yml)$'), '');
  return controller.importLocalConfig(name: fileName, yaml: yaml);
}

Future<bool> showCustomYamlDialog(
  BuildContext context,
  AppRuntimeController controller,
) async {
  final l10n = context.l10n;
  final name = TextEditingController(text: l10n.customProfileNameHint);
  final yaml = TextEditingController();
  final formKey = GlobalKey<FormState>();
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customYaml),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: l10n.subscriptionName),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.profileNameValidation
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: yaml,
                  minLines: 12,
                  maxLines: 18,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Clash / Mihomo YAML',
                    alignLabelWithHint: true,
                    hintText: 'proxies:\n  - name: ...',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.yamlEmptyValidation
                      : null,
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
    );
    if (accepted != true) return false;
    return await controller.importCustomConfig(
      name: name.text,
      yaml: yaml.text,
    );
  } finally {
    name.dispose();
    yaml.dispose();
  }
}
