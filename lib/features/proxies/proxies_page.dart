import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/clash_models.dart';
import '../../models/connection_models.dart';
import '../../l10n/l10n.dart';

class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {
  final _search = TextEditingController();
  bool _sortByDelay = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    final connected = state.connection is Connected;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.proxiesTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.refreshProxyGroups,
              onPressed: connected ? controller.refreshClashData : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 20,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.runMode),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'rule', label: Text(l10n.modeRule)),
                    ButtonSegment(
                      value: 'global',
                      label: Text(l10n.modeGlobal),
                    ),
                    ButtonSegment(
                      value: 'direct',
                      label: Text(l10n.modeDirect),
                    ),
                  ],
                  selected: <String>{
                    const <String>{
                          'rule',
                          'global',
                          'direct',
                        }.contains(state.coreMode)
                        ? state.coreMode
                        : 'rule',
                  },
                  onSelectionChanged: connected
                      ? (selection) => controller.setCoreMode(selection.first)
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (connected && state.proxyProviders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.proxyProviders,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...state.proxyProviders.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProviderCard(
                provider: provider,
                busy: state.busy,
                onUpdate: () => controller.updateProvider(provider.name),
              ),
            ),
          ),
        ],
        if (connected && state.ruleProviders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.ruleProviders,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...state.ruleProviders.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RuleProviderCard(
                provider: provider,
                busy: state.busy,
                onUpdate: () => controller.updateRuleProvider(provider.name),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                enabled: connected,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.searchNodes,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              selected: _sortByDelay,
              onSelected: connected && state.proxyDelays.isNotEmpty
                  ? (value) => setState(() => _sortByDelay = value)
                  : null,
              avatar: const Icon(Icons.sort_rounded, size: 18),
              label: Text(l10n.sortByDelay),
            ),
          ],
        ),
        if (state.delayTesting) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(l10n.testingNodes),
        ],
        const SizedBox(height: 16),
        if (!connected)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.connectToViewProxies),
            ),
          )
        else if (state.proxyGroups.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noSelectableGroups),
            ),
          )
        else
          ...state.proxyGroups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GroupCard(
                group: group,
                delays: state.proxyDelays,
                query: _search.text,
                sortByDelay: _sortByDelay,
                delayTesting: state.delayTesting,
                onSelect: (proxy) => controller.selectProxy(group.name, proxy),
                onTestOne: controller.testDelay,
                onTestAll: () => controller.testGroupDelays(group),
              ),
            ),
          ),
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!.resolve(l10n)),
        ],
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.busy,
    required this.onUpdate,
  });

  final ProxyProviderState provider;
  final bool busy;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final used = provider.uploadBytes + provider.downloadBytes;
    final hasQuota = provider.totalBytes > 0;
    final progress = hasQuota
        ? (used / provider.totalBytes).clamp(0.0, 1.0)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.cloud_sync_rounded)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${provider.vehicleType} · ${l10n.nodeCount(provider.proxyCount)}'
                        '${provider.updatedAt == null ? '' : ' · ${l10n.updatedAt(_dateTime(provider.updatedAt!))}'}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.updateProvider,
                  onPressed: busy ? null : onUpdate,
                  icon: const Icon(Icons.sync_rounded),
                ),
              ],
            ),
            if (hasQuota) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                '${l10n.quotaUsed(_bytes(used), _bytes(provider.totalBytes))}'
                '${provider.expireAt == null ? '' : ' · ${l10n.expiresOn(_date(provider.expireAt!))}'}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleProviderCard extends StatelessWidget {
  const _RuleProviderCard({
    required this.provider,
    required this.busy,
    required this.onUpdate,
  });

  final RuleProviderState provider;
  final bool busy;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const CircleAvatar(child: Icon(Icons.rule_folder_rounded)),
        title: Text(provider.name),
        subtitle: Text(
          '${l10n.ruleProviderSummary(provider.behavior, provider.vehicleType, provider.ruleCount)}'
          '${provider.updatedAt == null ? '' : ' · ${l10n.updatedAt(_dateTime(provider.updatedAt!))}'}',
        ),
        trailing: IconButton(
          tooltip: l10n.updateRuleProvider,
          onPressed: busy ? null : onUpdate,
          icon: const Icon(Icons.sync_rounded),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.delays,
    required this.query,
    required this.sortByDelay,
    required this.delayTesting,
    required this.onSelect,
    required this.onTestOne,
    required this.onTestAll,
  });

  final ProxyGroupState group;
  final Map<String, int> delays;
  final String query;
  final bool sortByDelay;
  final bool delayTesting;
  final ValueChanged<String> onSelect;
  final Future<void> Function([String?]) onTestOne;
  final VoidCallback onTestAll;

  List<String> get _options {
    final normalized = query.trim().toLowerCase();
    final result = group.options
        .where(
          (name) =>
              normalized.isEmpty || name.toLowerCase().contains(normalized),
        )
        .toList(growable: true);
    final selected = group.selected;
    if (selected != null && !result.contains(selected)) {
      result.insert(0, selected);
    }
    if (sortByDelay) {
      result.sort(
        (left, right) =>
            (delays[left] ?? 1 << 30).compareTo(delays[right] ?? 1 << 30),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = _options;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final selector = DropdownButton<String>(
              isExpanded: true,
              value: options.contains(group.selected) ? group.selected : null,
              hint: Text(
                options.isEmpty ? l10n.noMatchingNodes : l10n.selectNode,
              ),
              items: options
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                          if (delays[name] != null)
                            Text(
                              '${delays[name]} ms',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onSelect(value);
              },
            );
            final header = Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    group.alive ? Icons.hub_rounded : Icons.cloud_off_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l10n.groupOptions(group.type, group.options.length)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.testCurrentNode,
                  onPressed: group.selected == null || delayTesting
                      ? null
                      : () => onTestOne(group.selected),
                  icon: const Icon(Icons.speed_rounded),
                ),
                IconButton(
                  tooltip: l10n.testGroup,
                  onPressed: delayTesting ? null : onTestAll,
                  icon: const Icon(Icons.network_check_rounded),
                ),
              ],
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, const SizedBox(height: 12), selector],
              );
            }
            return Row(
              children: [
                Expanded(child: header),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: selector),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${_date(local)} ${two(local.hour)}:${two(local.minute)}';
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
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
