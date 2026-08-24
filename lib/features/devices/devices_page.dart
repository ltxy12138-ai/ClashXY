import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../models/profile_models.dart';
import '../../l10n/l10n.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    final onlineIds = state.onlineDevices.map((device) => device.id).toSet();
    final managedProfiles = state.profiles
        .where((profile) => !profile.isStandalone)
        .toList(growable: false);
    final clientIds = <String, String>{
      for (final device in state.localDevices) device.profileId: device.name,
    };
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.devicesTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: state.busy ? null : controller.refreshRemote,
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.localDevices, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (managedProfiles.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.devices_other_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    state.panel == null
                        ? l10n.noPanelConnected
                        : l10n.noLocalDevices,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : state.panel == null
                        ? () => context.go('/setup?panel=1')
                        : () => _createDevice(
                            context,
                            controller.provisionAndConnect,
                          ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      state.panel == null
                          ? l10n.connectTwoSui
                          : l10n.createLocalDevice,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...managedProfiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LocalDeviceTile(
                profile: profile,
                clientId: clientIds[profile.id],
                busy: state.busy,
                onDelete: () => _confirmDelete(
                  context,
                  controller.deleteDevice,
                  profile,
                  state.panel?.id,
                ),
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text(l10n.remoteClients, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (state.remoteDevices.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noRemoteClients),
            ),
          )
        else
          Card(
            child: Column(
              children: state.remoteDevices.map((device) {
                final online = onlineIds.contains(device.id);
                return ListTile(
                  leading: Icon(
                    online ? Icons.circle : Icons.circle_outlined,
                    color: online ? Colors.greenAccent : null,
                    size: 16,
                  ),
                  title: Text(device.name),
                  subtitle: Text(l10n.clientNumber(device.id)),
                  trailing: Text(
                    online
                        ? l10n.online
                        : device.enabled
                        ? l10n.offline
                        : l10n.disabled,
                  ),
                );
              }).toList(),
            ),
          ),
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!.resolve(l10n)),
        ],
      ],
    );
  }

  Future<void> _createDevice(
    BuildContext context,
    Future<void> Function({String? displayName}) create,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: Platform.localHostname);
    final formKey = GlobalKey<FormState>();
    final displayName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createLocalDevice),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.deviceDisplayName,
                  hintText: l10n.deviceDisplayNameHint,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.deviceDisplayNameValidation
                    : null,
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.machineIdentityNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(l10n.createLocalDevice),
          ),
        ],
      ),
    );
    controller.dispose();
    if (displayName != null && context.mounted) {
      await create(displayName: displayName);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Future<void> Function(ConnectionProfile) delete,
    ConnectionProfile profile,
    String? connectedPanelId,
  ) async {
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDeviceTitle),
        content: Text(
          profile.panelId == connectedPanelId
              ? l10n.deleteDeviceBody
              : l10n.deleteDetachedManagedBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (accepted == true) await delete(profile);
  }
}

class _LocalDeviceTile extends StatelessWidget {
  const _LocalDeviceTile({
    required this.profile,
    required this.clientId,
    required this.busy,
    required this.onDelete,
  });

  final ConnectionProfile profile;
  final String? clientId;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const CircleAvatar(child: Icon(Icons.computer_rounded)),
        title: Text(profile.displayName),
        subtitle: Text(
          '${clientId ?? profile.displayName} · Client #${profile.remoteClientId}\n'
          '${profile.proxies.map((proxy) => proxy.protocol.name).join(' · ')}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: l10n.deleteDeviceTooltip,
          onPressed: busy ? null : onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}
