import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_runtime_controller.dart';
import '../../app/providers.dart';
import '../../models/panel_models.dart';
import '../../models/profile_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../profiles/profile_edit_actions.dart';
import '../profiles/profile_source_actions.dart';

class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    final panel = state.panel;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.profilesTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: state.busy
                  ? null
                  : () => _showAddMenu(context, controller),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addProfile),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.profilesIntro),
        const SizedBox(height: 24),
        if (state.profiles.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(l10n.noProfiles),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => _showAddMenu(context, controller),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addFirstProfile),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.profiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProfileTile(
                profile: profile,
                busy: state.busy,
                active: state.activeProfileId == profile.id,
                onConnect: () => controller.connect(profile),
                onRefresh: profile.origin == ProfileOrigin.subscription
                    ? () => controller.refreshSubscription(profile)
                    : null,
                onEdit: profile.isStandalone
                    ? () => showProfileEditDialog(context, controller, profile)
                    : null,
                onEditYaml: profile.isStandalone && profile.rawConfig != null
                    ? () => showAdvancedYamlEditor(context, controller, profile)
                    : null,
                onExport: profile.rawConfig == null
                    ? null
                    : () => exportProfileWithWarning(context, profile),
                onDelete: () =>
                    _confirmDelete(context, controller, profile, panel?.id),
              ),
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.twoSuiManagementOptional,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (panel != null)
              IconButton.filledTonal(
                tooltip: l10n.refreshPanelStatus,
                onPressed: state.busy ? null : controller.refreshRemote,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (panel == null)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(l10n.twoSuiNotConnected),
              subtitle: Text(l10n.twoSuiNotRequired),
              trailing: OutlinedButton(
                onPressed: () => context.go('/setup?panel=1'),
                child: Text(l10n.connectPanel),
              ),
            ),
          )
        else ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const CircleAvatar(child: Icon(Icons.dns_rounded)),
              title: Text(panel.name),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(panel.baseUrl.toString()),
                    const SizedBox(height: 2),
                    Text(l10n.signedInAs(panel.username)),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    avatar: Icon(
                      state.serverStatus?.running == true
                          ? Icons.check_circle
                          : Icons.help_outline,
                      size: 18,
                    ),
                    label: Text(
                      state.serverStatus?.running == true
                          ? l10n.online
                          : l10n.unknown,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.managePanelAccount,
                    onPressed: state.busy
                        ? null
                        : () =>
                              _showPanelManagement(context, controller, panel),
                    icon: const Icon(Icons.manage_accounts_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 36,
                runSpacing: 20,
                children: [
                  _Stat(
                    label: l10n.version,
                    value: state.serverStatus?.version.isEmpty == false
                        ? state.serverStatus!.version
                        : '—',
                  ),
                  _Stat(
                    label: l10n.uptime,
                    value: l10n.seconds(state.serverStatus?.uptimeSeconds ?? 0),
                  ),
                  _Stat(
                    label: l10n.upload,
                    value: _bytes(state.serverTraffic?.uploadBytes ?? 0),
                  ),
                  _Stat(
                    label: l10n.download,
                    value: _bytes(state.serverTraffic?.downloadBytes ?? 0),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!.resolve(l10n)),
        ],
      ],
    );
  }

  Future<void> _showAddMenu(
    BuildContext context,
    AppRuntimeController controller,
  ) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(l10n.addSubscription),
                subtitle: Text(l10n.subscriptionSubtitle),
                onTap: () => Navigator.pop(context, _AddChoice.subscription),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_rounded),
                title: Text(l10n.importLocalConfig),
                subtitle: Text(l10n.importLocalSubtitle),
                onTap: () => Navigator.pop(context, _AddChoice.localFile),
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: Text(l10n.customYaml),
                subtitle: Text(l10n.customYamlSubtitle),
                onTap: () => Navigator.pop(context, _AddChoice.custom),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _AddChoice.subscription:
        await showSubscriptionDialog(context, controller);
      case _AddChoice.localFile:
        try {
          await importLocalProfile(context, controller);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.fileReadFailed)));
          }
        }
      case _AddChoice.custom:
        await showCustomYamlDialog(context, controller);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppRuntimeController controller,
    ConnectionProfile profile,
    String? connectedPanelId,
  ) async {
    final l10n = context.l10n;
    final isManaged = !profile.isStandalone;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isManaged ? l10n.deleteManagedTitle : l10n.deleteProfileTitle,
        ),
        content: Text(
          isManaged
              ? profile.panelId == connectedPanelId
                    ? l10n.deleteManagedBody
                    : l10n.deleteDetachedManagedBody
              : l10n.deleteProfileBody,
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
    if (accepted == true) await controller.deleteDevice(profile);
  }

  Future<void> _showPanelManagement(
    BuildContext context,
    AppRuntimeController controller,
    PanelAccount panel,
  ) async {
    final l10n = context.l10n;
    final choice = await showDialog<_PanelDisconnectChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.disconnectPanelTitle),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.disconnectPanelBody),
              const SizedBox(height: 16),
              Card.filled(
                child: ListTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: Text(l10n.disconnectLocally),
                  subtitle: Text(l10n.disconnectLocallySubtitle),
                  onTap: () =>
                      Navigator.pop(context, _PanelDisconnectChoice.local),
                ),
              ),
              if (panel.tokenId != null) ...[
                const SizedBox(height: 8),
                Card.filled(
                  child: ListTile(
                    leading: const Icon(Icons.key_off_outlined),
                    title: Text(l10n.revokeAndDisconnect),
                    subtitle: Text(l10n.revokeAndDisconnectSubtitle),
                    onTap: () =>
                        Navigator.pop(context, _PanelDisconnectChoice.revoke),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  l10n.tokenRevokeUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _PanelDisconnectChoice.local:
        await controller.disconnectPanelLocal();
      case _PanelDisconnectChoice.revoke:
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _PanelRevokeDialog(),
        );
    }
  }
}

enum _AddChoice { subscription, localFile, custom }

enum _PanelDisconnectChoice { local, revoke }

enum _ProfileAction { edit, editYaml, export, delete }

class _PanelRevokeDialog extends ConsumerStatefulWidget {
  const _PanelRevokeDialog();

  @override
  ConsumerState<_PanelRevokeDialog> createState() => _PanelRevokeDialogState();
}

class _PanelRevokeDialogState extends ConsumerState<_PanelRevokeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _needsTwoFactor = false;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(runtimeControllerProvider);
    return AlertDialog(
      title: Text(l10n.reauthenticatePanel),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.reauthenticatePanelBody),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: state.panel?.username ?? '',
                readOnly: true,
                decoration: InputDecoration(labelText: l10n.username),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.password),
                validator: (value) => value == null || value.isEmpty
                    ? l10n.passwordValidation
                    : null,
              ),
              if (_needsTwoFactor) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.twoFactorCode),
                ),
              ],
              if (state.message != null) ...[
                const SizedBox(height: 12),
                Text(state.message!.resolve(l10n)),
              ],
              if (state.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: state.busy ? null : _submit,
          icon: const Icon(Icons.key_off_outlined),
          label: Text(l10n.revokeToken),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(runtimeControllerProvider.notifier)
        .revokeAndDisconnectPanel(password: _password.text, code: _code.text);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _needsTwoFactor = ref.read(runtimeControllerProvider).needsTwoFactor;
      });
    }
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.busy,
    required this.active,
    required this.onConnect,
    required this.onRefresh,
    required this.onEdit,
    required this.onEditYaml,
    required this.onExport,
    required this.onDelete,
  });

  final ConnectionProfile profile;
  final bool busy;
  final bool active;
  final VoidCallback onConnect;
  final VoidCallback? onRefresh;
  final VoidCallback? onEdit;
  final VoidCallback? onEditYaml;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: active
          ? Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.3)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: CircleAvatar(
          child: Icon(
            active ? Icons.shield_rounded : _originIcon(profile.origin),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(profile.displayName)),
            if (active)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  avatar: const Icon(Icons.circle, size: 10),
                  label: Text(l10n.currentProfile),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(_profileSummary(l10n, profile)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRefresh != null)
              IconButton(
                tooltip: l10n.updateSubscription,
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.sync_rounded),
              ),
            IconButton(
              tooltip: active
                  ? l10n.activeProfileTooltip
                  : l10n.connectProfileTooltip,
              onPressed: busy || active ? null : onConnect,
              icon: Icon(
                active ? Icons.check_rounded : Icons.play_arrow_rounded,
              ),
            ),
            PopupMenuButton<_ProfileAction>(
              enabled: !busy,
              tooltip: l10n.moreActions,
              onSelected: (action) {
                switch (action) {
                  case _ProfileAction.edit:
                    onEdit?.call();
                  case _ProfileAction.editYaml:
                    onEditYaml?.call();
                  case _ProfileAction.export:
                    onExport?.call();
                  case _ProfileAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: _ProfileAction.edit,
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.edit),
                    ),
                  ),
                if (onEditYaml != null)
                  PopupMenuItem(
                    value: _ProfileAction.editYaml,
                    child: ListTile(
                      leading: const Icon(Icons.code_rounded),
                      title: Text(l10n.editAdvancedYaml),
                    ),
                  ),
                if (onExport != null)
                  PopupMenuItem(
                    value: _ProfileAction.export,
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.exportProfile),
                    ),
                  ),
                PopupMenuItem(
                  value: _ProfileAction.delete,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

String _profileSummary(AppLocalizations l10n, ConnectionProfile profile) {
  final label = switch (profile.origin) {
    ProfileOrigin.subscription => l10n.profileOriginSubscription,
    ProfileOrigin.localFile => l10n.profileOriginLocal,
    ProfileOrigin.custom => l10n.profileOriginCustom,
    ProfileOrigin.twoSui => l10n.profileOriginTwoSui,
  };
  final raw = profile.rawConfig;
  final proxyCount = raw?['proxies'] is List
      ? (raw!['proxies']! as List).length
      : profile.proxies.length;
  final providerCount = raw?['proxy-providers'] is Map
      ? (raw!['proxy-providers']! as Map).length
      : 0;
  final details = <String>[
    if (proxyCount > 0) l10n.nodeCount(proxyCount),
    if (providerCount > 0) l10n.providerCount(providerCount),
  ];
  final updated = _formatProfileTime(profile.lastUpdatedAt);
  final autoUpdate = profile.autoUpdateEnabled
      ? l10n.autoUpdateValue(_intervalLabel(l10n, profile.autoUpdateInterval))
      : null;
  final prefix = details.isEmpty ? label : '$label · ${details.join(' · ')}';
  return <String>[prefix, l10n.updatedAt(updated), ?autoUpdate].join(' · ');
}

IconData _originIcon(ProfileOrigin origin) => switch (origin) {
  ProfileOrigin.subscription => Icons.link_rounded,
  ProfileOrigin.localFile => Icons.file_open_rounded,
  ProfileOrigin.custom => Icons.code_rounded,
  ProfileOrigin.twoSui => Icons.admin_panel_settings_rounded,
};

String _intervalLabel(AppLocalizations l10n, Duration interval) {
  final hours = interval.inHours;
  if (hours < 24) return l10n.everyHours(hours);
  final days = interval.inDays;
  return days == 1
      ? l10n.everyDay
      : days == 7
      ? l10n.everyWeek
      : l10n.everyDays(days);
}

String _formatProfileTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _bytes(int value) {
  if (value >= 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '$value B';
}
