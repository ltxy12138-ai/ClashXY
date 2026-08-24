import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_runtime_state.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../profiles/profile_source_actions.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({this.panelOnly = false, super.key});

  final bool panelOnly;

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController(text: 'https://panel.example.com/app/');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _showPanelForm = false;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runtimeControllerProvider);
    final controller = ref.read(runtimeControllerProvider.notifier);
    if (state.stage == AppStage.ready && !widget.panelOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }
    if (state.stage == AppStage.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final panelForm = widget.panelOnly || _showPanelForm;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelForm ? 600 : 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: panelForm
                    ? _buildPanelForm(state)
                    : _buildSourcePicker(state, controller),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourcePicker(AppRuntimeState state, dynamic controller) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_moon_rounded, size: 56),
        const SizedBox(height: 16),
        Text(
          l10n.setupFirstProfile,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupIntro, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _SourceButton(
          icon: Icons.link_rounded,
          title: l10n.addSubscription,
          subtitle: l10n.subscriptionSubtitle,
          onTap: state.busy
              ? null
              : () => showSubscriptionDialog(context, controller),
        ),
        const SizedBox(height: 12),
        _SourceButton(
          icon: Icons.file_open_rounded,
          title: l10n.importLocalConfig,
          subtitle: l10n.importLocalSubtitle,
          onTap: state.busy ? null : () => _importLocal(controller),
        ),
        const SizedBox(height: 12),
        _SourceButton(
          icon: Icons.code_rounded,
          title: l10n.customYaml,
          subtitle: l10n.customYamlSubtitle,
          onTap: state.busy
              ? null
              : () => showCustomYamlDialog(context, controller),
        ),
        const SizedBox(height: 12),
        _SourceButton(
          icon: Icons.admin_panel_settings_rounded,
          title: l10n.connectTwoSuiOptional,
          subtitle: l10n.connectTwoSuiSubtitle,
          onTap: state.busy
              ? null
              : () => setState(() => _showPanelForm = true),
        ),
        if (state.busy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!.resolve(l10n), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _buildPanelForm(AppRuntimeState state) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!widget.panelOnly)
                IconButton(
                  tooltip: l10n.back,
                  onPressed: state.busy
                      ? null
                      : () => setState(() => _showPanelForm = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const Spacer(),
              const Icon(Icons.admin_panel_settings_rounded, size: 46),
              const Spacer(),
              if (!widget.panelOnly) const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.connectPanelTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(l10n.connectPanelSecurity, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          TextFormField(
            controller: _url,
            decoration: InputDecoration(
              labelText: l10n.panelAddress,
              hintText: 'https://panel.example.com/app/',
            ),
            validator: (value) => value == null || !value.startsWith('https://')
                ? l10n.panelAddressValidation
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _username,
            decoration: InputDecoration(labelText: l10n.username),
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.usernameValidation
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.password),
            validator: (value) =>
                value == null || value.isEmpty ? l10n.passwordValidation : null,
          ),
          if (state.needsTwoFactor) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.twoFactorCode),
            ),
          ],
          if (state.message != null) ...[
            const SizedBox(height: 16),
            Text(state.message!.resolve(l10n), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => ref
                            .read(runtimeControllerProvider.notifier)
                            .testPanel(_url.text),
                  icon: const Icon(Icons.network_check_rounded),
                  label: Text(l10n.testConnection),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy ? null : _submit,
                  icon: state.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(l10n.connect),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importLocal(dynamic controller) async {
    try {
      await importLocalProfile(context, controller);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.fileReadFailed)));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(runtimeControllerProvider.notifier)
        .configurePanel(
          url: _url.text,
          username: _username.text,
          password: _password.text,
          code: _code.text,
        );
    if (success) {
      _password.clear();
      _code.clear();
      if (widget.panelOnly && mounted) context.go('/servers');
    }
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        enabled: onTap != null,
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
