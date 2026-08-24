import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/app_runtime_state.dart';
import '../../models/connection_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    final l10n = context.l10n;
    final connected = state.connection is Connected;
    final transitioning =
        state.connection is Connecting ||
        state.connection is Reconnecting ||
        state.connection is Stopping;
    return _PageFrame(
      title: l10n.navHome,
      subtitle: state.profiles.isEmpty
          ? l10n.homeNoProfiles
          : l10n.homeProfilesAvailable(state.profiles.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _connectionColor(
                        context,
                        state.connection,
                      ).withValues(alpha: 0.16),
                    ),
                    child: Icon(
                      connected ? Icons.shield_rounded : Icons.shield_outlined,
                      size: 52,
                      color: _connectionColor(context, state.connection),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _connectionLabel(l10n, state.connection),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 22),
                  if (state.profiles.isEmpty)
                    FilledButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => context.go('/servers'),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.addProfile),
                    )
                  else
                    FilledButton.icon(
                      onPressed: transitioning
                          ? null
                          : connected
                          ? controller.disconnect
                          : controller.connect,
                      icon: Icon(
                        connected
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(connected ? l10n.disconnect : l10n.connect),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                _MetricCard(
                  icon: Icons.upload_rounded,
                  label: l10n.uploadSpeed,
                  value: _rate(state.traffic?.uploadBytesPerSecond ?? 0),
                ),
                _MetricCard(
                  icon: Icons.download_rounded,
                  label: l10n.downloadSpeed,
                  value: _rate(state.traffic?.downloadBytesPerSecond ?? 0),
                ),
                _MetricCard(
                  icon: Icons.speed_rounded,
                  label: l10n.proxyDelay,
                  value: switch (state.delayTestStatus) {
                    DelayTestStatus.testing => l10n.delayTesting,
                    DelayTestStatus.failed => l10n.delayFailed,
                    DelayTestStatus.success when state.delay != null =>
                      '${state.delay!.milliseconds} ms',
                    _ => '—',
                  },
                  onTap:
                      connected &&
                          state.delayTestStatus != DelayTestStatus.testing
                      ? controller.testDelay
                      : null,
                ),
              ];
              if (constraints.maxWidth >= 760) {
                return Row(
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: card,
                          ),
                        ),
                      )
                      .toList(),
                );
              }
              return Column(
                children: cards
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (state.message != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.message!.resolve(l10n)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

String _connectionLabel(AppLocalizations l10n, AppConnectionState state) =>
    switch (state) {
      Disconnected() => l10n.connectionDisconnected,
      Connecting() => l10n.connectionConnecting,
      Connected() => l10n.connectionConnected,
      WaitingForNetwork() => l10n.connectionWaitingNetwork,
      Reconnecting(:final attempt) => l10n.connectionReconnecting(attempt),
      Stopping() => l10n.connectionStopping,
      ConnectionFailure(:final message) => l10n.connectionError(
        l10n.localeName.startsWith('en') &&
                RegExp(r'[\u3400-\u9fff]').hasMatch(message)
            ? l10n.connectionErrorGeneric
            : message,
      ),
    };

Color _connectionColor(BuildContext context, AppConnectionState state) {
  return switch (state) {
    Connected() => Colors.greenAccent,
    ConnectionFailure() => Theme.of(context).colorScheme.error,
    Connecting() || Reconnecting() || Stopping() => Colors.amberAccent,
    _ => Theme.of(context).colorScheme.primary,
  };
}

String _rate(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
  return '$bytes B/s';
}
