// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';

/// Lets an Official block, restrict or unblock registered users.
class UserAccessControlScreen extends StatefulWidget {
  const UserAccessControlScreen({super.key});

  @override
  State<UserAccessControlScreen> createState() => _UserAccessControlScreenState();
}

class _UserAccessControlScreenState extends State<UserAccessControlScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Block / Restrict Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, reg no, or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('fullName')
                  .limit(500)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error loading users: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                final users = docs.where((doc) {
                  if (_query.isEmpty) return true;
                  final d = doc.data() as Map<String, dynamic>;
                  final name = (d['fullName'] ?? '').toString().toLowerCase();
                  final regNo = (d['registrationNumber'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  final role = (d['role'] ?? '').toString().toLowerCase();
                  return name.contains(_query) ||
                      regNo.contains(_query) ||
                      email.contains(_query) ||
                      role.contains(_query);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _UserTile(
                      uid: doc.id,
                      data: data,
                      onTap: () => _showStatusSheet(context, doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusSheet(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final current = data['accountStatus'] ?? 'active';
    final currentReason = data['statusReason'] as String?;
    String? selected = current.toString();
    final reasonController = TextEditingController(text: currentReason ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['fullName'] ?? 'User'} · ${data['registrationNumber'] ?? ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  data['email']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Account status', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Active',
                      color: Colors.green,
                      selected: selected == 'active',
                      onTap: () => setSheetState(() => selected = 'active'),
                    ),
                    _StatusChip(
                      label: 'Restricted',
                      color: Colors.orange,
                      selected: selected == 'restricted',
                      onTap: () => setSheetState(() => selected = 'restricted'),
                    ),
                    _StatusChip(
                      label: 'Banned',
                      color: Colors.red,
                      selected: selected == 'banned',
                      onTap: () => setSheetState(() => selected = 'banned'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selected != 'active') ...[
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (shown to the user)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: const Text('Save Status'),
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              final adminUid =
                                  context.read<AuthProvider>().currentUserId;
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update({
                                'accountStatus': selected,
                                'statusReason':
                                    selected == 'active' ? '' : reasonController.text.trim(),
                                'statusUpdatedAt': FieldValue.serverTimestamp(),
                                'statusUpdatedBy': adminUid,
                              });
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Status updated to ${selected == 'active' ? 'Active' : selected}',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (sheetCtx.mounted) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.uid,
    required this.data,
    required this.onTap,
  });

  final String uid;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = data['fullName'] ?? 'Unknown';
    final role = data['role'] ?? 'Student';
    final status = (data['accountStatus'] ?? 'active').toString();
    final statusColor = UserAccessControlColor.statusColor(status);
    final regNo = data['registrationNumber'] ?? '';
    final email = data['email'] ?? '';
    final classes = List<String>.from(data['enrolledClasses'] ?? []);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Text(
            name.toString()[0].toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                '$name ($role)',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '$regNo · $email\n${classes.length} class(es)',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.15),
      side: BorderSide(
        color: selected ? color : Theme.of(context).dividerColor,
      ),
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: color,
      onSelected: (_) => onTap(),
    );
  }
}

/// Color helper shared by the tile and the sheet.
abstract final class UserAccessControlColor {
  static Color statusColor(String status) {
    switch (status) {
      case 'banned':
        return Colors.red;
      case 'restricted':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}