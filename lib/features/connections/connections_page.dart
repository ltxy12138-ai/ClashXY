import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/clash_models.dart';
import '../../models/connection_models.dart';
import '../../l10n/l10n.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final state = ref.read(runtimeControllerProvider);
      if (state.connection is Connected) {
        unawaited(
          ref.read(runtimeControllerProvider.notifier).refreshConnections(),
        );
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    final connected = state.connection is Connected;
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.connectionsTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l10n.refreshRuntime,
                  onPressed: connected ? controller.refreshClashData : null,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              tabs: [
                Tab(text: l10n.tabConnections),
                Tab(text: l10n.tabRules),
                Tab(text: l10n.tabLogs),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: connected
                  ? TabBarView(
                      children: [
                        _ConnectionsTab(
                          snapshot: state.connectionSnapshot,
                          onClose: controller.closeConnection,
                          onCloseAll: controller.closeAllConnections,
                        ),
                        _RulesTab(rules: state.rules),
                        _LogsTab(
                          logs: state.coreLogs,
                          onClear: controller.clearCoreLogs,
                        ),
                      ],
                    )
                  : Center(child: Text(l10n.connectToViewRuntime)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsTab extends StatefulWidget {
  const _ConnectionsTab({
    required this.snapshot,
    required this.onClose,
    required this.onCloseAll,
  });

  final ConnectionSnapshot? snapshot;
  final Future<void> Function(String) onClose;
  final Future<void> Function() onCloseAll;

  @override
  State<_ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<_ConnectionsTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allRows =
        widget.snapshot?.connections ?? const <ClashConnectionEntry>[];
    final query = _search.text.trim().toLowerCase();
    final rows = allRows
        .where((row) {
          if (query.isEmpty) return true;
          return row.host.toLowerCase().contains(query) ||
              row.destination.toLowerCase().contains(query) ||
              row.network.toLowerCase().contains(query) ||
              row.chains.any((chain) => chain.toLowerCase().contains(query));
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.connectionSummary(
                  allRows.length,
                  _bytes(widget.snapshot?.uploadTotal ?? 0),
                  _bytes(widget.snapshot?.downloadTotal ?? 0),
                ),
              ),
            ),
            const Icon(Icons.sync_rounded, size: 16),
            const SizedBox(width: 4),
            Text(l10n.refreshEveryTwoSeconds),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: allRows.isEmpty ? null : widget.onCloseAll,
              icon: const Icon(Icons.close_rounded),
              label: Text(l10n.closeAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.searchConnections,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    allRows.isEmpty
                        ? l10n.noActiveConnections
                        : l10n.noMatchingConnections,
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.swap_horiz_rounded),
                        title: Text(
                          row.host.isEmpty ? row.destination : row.host,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${row.network.toUpperCase()} · ${row.chains.join(' → ')} · ↑${_bytes(row.uploadBytes)} ↓${_bytes(row.downloadBytes)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: l10n.closeConnection,
                          onPressed: row.id.isEmpty
                              ? null
                              : () => widget.onClose(row.id),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab({required this.rules});

  final List<ClashRuleEntry> rules;

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final rules = widget.rules
        .where((rule) {
          if (query.isEmpty) return true;
          return rule.type.toLowerCase().contains(query) ||
              rule.payload.toLowerCase().contains(query) ||
              rule.proxy.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.searchRules,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Text(
                    widget.rules.isEmpty ? l10n.noRules : l10n.noMatchingRules,
                  ),
                )
              : ListView.builder(
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return ListTile(
                      dense: true,
                      leading: Text('${index + 1}'),
                      title: Text('${rule.type}  ${rule.payload}'),
                      trailing: Text(rule.proxy),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LogsTab extends StatefulWidget {
  const _LogsTab({required this.logs, required this.onClear});

  final List<CoreLogEntry> logs;
  final VoidCallback onClear;

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  final _search = TextEditingController();
  String _level = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final logs = widget.logs
        .where((entry) {
          final levelMatches =
              _level == 'all' ||
              entry.level.toLowerCase() == _level ||
              (_level == 'warning' && entry.level.toLowerCase() == 'warn');
          return levelMatches &&
              (query.isEmpty || entry.message.toLowerCase().contains(query));
        })
        .toList(growable: false);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.searchLogs,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _level,
              items: [
                DropdownMenuItem(value: 'all', child: Text(l10n.allLevels)),
                const DropdownMenuItem(value: 'debug', child: Text('Debug')),
                const DropdownMenuItem(value: 'info', child: Text('Info')),
                const DropdownMenuItem(
                  value: 'warning',
                  child: Text('Warning'),
                ),
                const DropdownMenuItem(value: 'error', child: Text('Error')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _level = value);
              },
            ),
            IconButton(
              tooltip: l10n.clearLogs,
              onPressed: widget.logs.isEmpty ? null : widget.onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    widget.logs.isEmpty ? l10n.noLogs : l10n.noMatchingLogs,
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final entry = logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText(
                        '${_time(entry.capturedAt)} [${entry.level.toUpperCase()}] ${entry.message}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _time(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
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
