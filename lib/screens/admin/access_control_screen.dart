// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/access_control_provider.dart';
import '../../services/auth_provider.dart';

/// Global switches for enabling/disabling login & registration, plus
/// per-role allowances. Written to `access_control/global`.
class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  static const _roles = ['Student', 'Leader', 'Teacher', 'Official'];

  late bool _loginEnabled;
  late bool _registrationEnabled;
  late List<String> _loginAllowedRoles;
  late List<String> _registrationAllowedRoles;
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final config = context.read<AccessControlProvider>().config;
    _loginEnabled = config.loginEnabled;
    _registrationEnabled = config.registrationEnabled;
    _loginAllowedRoles = List.of(config.loginAllowedRoles);
    _registrationAllowedRoles = List.of(config.registrationAllowedRoles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Access Control')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Sign-ins Enabled',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _loginEnabled
                          ? 'Users can sign in to the app'
                          : 'All sign-ins are blocked (existing sessions stay valid)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _loginEnabled,
                    onChanged: (v) => setState(() => _loginEnabled = v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Registration Enabled',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _registrationEnabled
                          ? 'New accounts can register'
                          : 'New registrations are closed',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _registrationEnabled,
                    onChanged: (v) => setState(() => _registrationEnabled = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildRoleSection(
            context,
            title: 'Roles Allowed to Sign In',
            subtitle:
                'Empty = all roles. Selected roles below can sign in when the master switch is on.',
            selected: _loginAllowedRoles,
            onChanged: (v) => setState(() => _loginAllowedRoles = v),
          ),
          const SizedBox(height: 12),
          _buildRoleSection(
            context,
            title: 'Roles Allowed to Register',
            subtitle:
                'Empty = all roles. Limits who can create a new account.',
            selected: _registrationAllowedRoles,
            onChanged: (v) => setState(() => _registrationAllowedRoles = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Access Settings'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: blocking sign-ins does not log out users who are already signed in.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in _roles)
                  FilterChip(
                    label: Text(role, style: const TextStyle(fontSize: 13)),
                    selected: selected.contains(role),
                    onSelected: (sel) {
                      final next = List.of(selected);
                      if (sel) {
                        next.add(role);
                      } else {
                        next.remove(role);
                      }
                      onChanged(next);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final provider = context.read<AccessControlProvider>();
      final adminUid = context.read<AuthProvider>().currentUserId;
      await provider.save(
        loginEnabled: _loginEnabled,
        registrationEnabled: _registrationEnabled,
        loginAllowedRoles: _loginAllowedRoles,
        registrationAllowedRoles: _registrationAllowedRoles,
        adminUid: adminUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}