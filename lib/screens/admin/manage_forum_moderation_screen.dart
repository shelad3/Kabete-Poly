// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../models/forum_channel.dart';
import '../../models/message.dart';
import '../../services/forum_service.dart';
import '../../widgets/state_views.dart';

/// Admin/teacher moderation of forum channels and messages per class.
/// Admins can delete inappropriate channels and messages directly.
class ManageForumModerationScreen extends StatefulWidget {
  final List<String> classes;

  const ManageForumModerationScreen({super.key, required this.classes});

  @override
  State<ManageForumModerationScreen> createState() =>
      _ManageForumModerationScreenState();
}

class _ManageForumModerationScreenState
    extends State<ManageForumModerationScreen> {
  final ForumService _forumService = ForumService();
  late String _selectedClass;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.classes.isNotEmpty ? widget.classes.first : '';
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message'),
        content: Text('Delete this message from ${message.senderName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(message.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteChannel(ForumChannel channel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete channel'),
        content: Text(
          'Delete "${channel.name}" and all its messages? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final messages = await FirebaseFirestore.instance
            .collection('messages')
            .where('channelId', isEqualTo: channel.id)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final m in messages.docs) {
          batch.delete(m.reference);
        }
        batch.delete(
          FirebaseFirestore.instance
              .collection('forum_channels')
              .doc(channel.id),
        );
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Channel deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Forum Moderation'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'Channels'),
              Tab(icon: Icon(Icons.forum), text: 'Messages'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (widget.classes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.classes
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (v) => setState(
                    () => _selectedClass = v ?? _selectedClass,
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildChannelsTab(),
                  _buildMessagesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsTab() {
    return StreamBuilder<List<ForumChannel>>(
      stream: _forumService.getChannelsStream(_selectedClass),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final channels = snap.data ?? const <ForumChannel>[];
        if (channels.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No channels',
            subtitle: 'This class has no forum channels yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: channels.length,
          itemBuilder: (context, i) {
            final ch = channels[i];
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('channelId', isEqualTo: ch.id)
                  .snapshots(),
              builder: (ctx, msgSnap) {
                final count = msgSnap.data?.docs.length ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ch.isAnnouncement
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.blue.withValues(alpha: 0.12),
                      child: Icon(
                        ch.isAnnouncement
                            ? Icons.campaign
                            : Icons.chat_bubble_outline,
                        color: ch.isAnnouncement
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ),
                    title: Text(ch.name),
                    subtitle: Text(
                      '${ch.isAnnouncement ? "Announcement" : "Public chat"}'
                      ' · $count messages',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete channel',
                      onPressed: () => _deleteChannel(ch),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('classId', isEqualTo: _selectedClass)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(message: 'Could not load messages');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: 'No messages',
            subtitle: 'No forum messages in this class yet.',
          );
        }
        final messages = docs
            .map(
              (d) => ChatMessage.fromJson(
                d.data() as Map<String, dynamic>,
                d.id,
              ),
            )
            .toList();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: m.senderAvatarUrl.isNotEmpty
                    ? CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        backgroundImage: NetworkImage(m.senderAvatarUrl),
                        onBackgroundImageError: (_, __) {},
                      )
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  m.senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMM yyyy, HH:mm').format(m.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete message',
                  onPressed: () => _deleteMessage(m),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
