// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';

/// Shown when the signed-in user is banned or sign-ins are disabled.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.blockStatus;
    final isBanned = status == 'banned';
    final message = auth.blockMessage ??
        'Your access to this app has been disabled by the administration.';
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    (isBanned ? Colors.red : Colors.deepOrange).withValues(
                      alpha: 0.12,
                    ),
                child: Icon(
                  isBanned ? Icons.block : Icons.lock_outline,
                  size: 48,
                  color: isBanned ? Colors.red : Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isBanned ? 'Access Blocked' : 'Sign-ins Disabled',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact the KNP administration for assistance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}