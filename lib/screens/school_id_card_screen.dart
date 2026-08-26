// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class SchoolIDCardScreen extends StatelessWidget {
  const SchoolIDCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School ID Card')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.currentUser;
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _IDCardFront(user: user),
            ),
          );
        },
      ),
    );
  }
}

class _IDCardFront extends StatelessWidget {
  final dynamic user;

  const _IDCardFront({required this.user});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width - 48;
    return Container(
      width: cardWidth,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade800, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _TopBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                _PhotoSection(user: user),
                const SizedBox(height: 20),
                _DividerLine(),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Reg No:',
                  value: user.registrationNumber ?? '',
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  label: 'Gender:',
                  value: user.gender?.isNotEmpty == true ? user.gender : '—',
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  label: 'Nationality:',
                  value: user.nationality?.isNotEmpty == true
                      ? user.nationality
                      : 'Kenyan',
                ),
                const SizedBox(height: 4),
                _InfoRow(label: 'Role:', value: user.role ?? 'Student'),
                const SizedBox(height: 20),
                _DividerLine(),
                const SizedBox(height: 16),
                _BottomSeals(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school, color: Color(0xFF1B5E20), size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'KABETE NATIONAL\nPOLYTECHNIQUE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.2,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school, color: Color(0xFF1B5E20), size: 22),
          ),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final dynamic user;
  const _PhotoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 100,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green.shade800, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: user.profilePhotoUrl?.isNotEmpty == true
                ? Image.network(
                    user.profilePhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Icon(
                      Icons.person,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  )
                : Icon(
                    Icons.person,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  user.registrationNumber ?? '',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade200,
            Colors.green.shade800,
            Colors.green.shade200,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _BottomSeals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade700, width: 2),
                color: Colors.amber.shade50,
              ),
              child: Icon(Icons.gavel, color: Colors.amber.shade800, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              'COURTS\nOF KENYA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
                height: 1.2,
              ),
            ),
          ],
        ),
        Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade700, width: 2),
                color: Colors.green.shade50,
              ),
              child: Icon(
                Icons.verified_user,
                color: Colors.green.shade700,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'VALID\nID CARD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
