// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feature_flag_provider.dart';

/// A declarative widget that shows [child] only if the feature is enabled.
/// Shows [fallback] (or a default lock icon) when the feature is disabled.
class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onDisabledTap;

  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
    this.onDisabledTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeatureFlagProvider>();
    final isEnabled = provider.isEnabled(feature);

    if (isEnabled) return child;

    final disabledWidget =
        fallback ??
        _DefaultDisabledWidget(
          message:
              provider.getDisabledMessage(feature) ??
              'This feature is currently unavailable.',
        );

    if (onDisabledTap != null) {
      return GestureDetector(onTap: onDisabledTap, child: disabledWidget);
    }

    return GestureDetector(
      onTap: () {
        final msg =
            provider.getDisabledMessage(feature) ??
            'This feature is currently unavailable.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: disabledWidget,
    );
  }
}

/// Imperative check for use outside widgets (e.g., in navigation callbacks).
/// Returns true if the feature is enabled, showing a SnackBar if not.
bool checkFeatureEnabled(BuildContext context, String feature) {
  final provider = context.read<FeatureFlagProvider>();
  if (provider.isEnabled(feature)) return true;

  final msg =
      provider.getDisabledMessage(feature) ??
      'This feature is currently unavailable.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
  return false;
}

class _DefaultDisabledWidget extends StatelessWidget {
  final String message;
  const _DefaultDisabledWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
