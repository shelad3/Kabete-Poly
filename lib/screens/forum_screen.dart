import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/forum_channel.dart';
import '../services/forum_service.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import '../services/unread_badge_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/shimmer_loading.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ForumService _forumService = ForumService();
  final _textController = TextEditingController();
  String? _selectedChannelId;
  bool _showChannelList = true;
  Map<String, DateTime> _lastSeen = {};
  Map<String, DateTime> _latestMsg = {};
  bool _seenLoaded = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadLastSeen(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('forum_last_seen_$classId');
    if (raw != null) {
      final map = Map<String, dynamic>.from(
        const JsonDecoder().convert(raw) as Map,
      );
      _lastSeen = map.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
    }
    _seenLoaded = true;
  }

  Future<void> _saveLastSeen(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = const JsonEncoder().convert(
      _lastSeen.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await prefs.setString('forum_last_seen_$classId', raw);
  }

  Future<void> _markChannelSeen(String channelId, String classId) async {
    _lastSeen[channelId] = DateTime.now();
    await _saveLastSeen(classId);
    _updateForumBadge();
  }

  void _updateForumBadge() {
    final unread = _latestMsg.entries.where((e) {
      final lastSeen = _lastSeen[e.key];
      return lastSeen == null || e.value.isAfter(lastSeen);
    }).length;
    context.read<UnreadBadgeProvider>().setForumCount(unread);
  }

  Future<void> _loadLatestTimestamps(List<ForumChannel> channels) async {
    final fs = FirebaseFirestore.instance;
    for (final ch in channels) {
      try {
        final snap = await fs
            .collection('messages')
            .where('channelId', isEqualTo: ch.id)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final ts = (snap.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
          if (ts != null) {
            _latestMsg[ch.id] = ts;
          }
        }
      } catch (_) {}
    }
    _updateForumBadge();
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final text = _textController.text;

    if (text.toLowerCase().contains('badword')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message blocked by AI Monitor: Inappropriate content.'),
          backgroundColor: Colors.red,
        ),
      );
      _textController.clear();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final user = authProvider.currentUser;

    if (user != null && _selectedChannelId != null) {
      final msg = ChatMessage(
        id: '',
        classId: classProvider.currentClass,
        channelId: _selectedChannelId!,
        senderId: context.read<AuthProvider>().currentUserId,
        senderName: user.fullName,
        senderAvatarUrl: user.profilePhotoUrl,
        text: text,
        timestamp: DateTime.now(),
      );

      _textController.clear();
      await _forumService.sendMessage(msg);
    }
  }

  Future<void> _createChannel() async {
    final nameCtrl = TextEditingController();
    String type = 'chat';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('New Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'chat', child: Text('Chat (everyone can post)')),
                  DropdownMenuItem(value: 'announcement', child: Text('Announcement (admin only)')),
                ],
                onChanged: (v) => setDState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'type': type});
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final classProvider = context.read<ClassProvider>();
      final user = context.read<AuthProvider>().currentUser;
      final channel = ForumChannel(
        id: '',
        classId: classProvider.currentClass,
        name: result['name']!,
        type: result['type']!,
        createdBy: user?.email ?? 'unknown',
        createdAt: DateTime.now(),
      );
      await _forumService.createChannel(channel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel created')),
        );
      }
    }
  }

  Future<void> _editChannel(ForumChannel channel) async {
    final nameCtrl = TextEditingController(text: channel.name);
    String type = channel.type;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Edit Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'chat', child: Text('Chat (everyone can post)')),
                  DropdownMenuItem(value: 'announcement', child: Text('Announcement (admin only)')),
                ],
                onChanged: (v) => setDState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'type': type});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _forumService.updateChannel(channel.id, {
        'name': result['name'],
        'type': result['type'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel "${result['name']}" updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showChannelList ? 'Channels' : 'Forum'),
        leading: _showChannelList
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showChannelList = true),
              ),
        actions: [
          Builder(builder: (ctx) {
            final user = ctx.read<AuthProvider>().currentUser;
            final canCreate = user != null && (user.isTeacher || user.isLeader || user.isAdmin);
            if (!canCreate) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Channel',
              onPressed: _createChannel,
            );
          }),
        ],
      ),
      body: Selector<ClassProvider, String>(
        selector: (_, cp) => cp.currentClass,
        builder: (_, currentClass, _) {
          if (!_seenLoaded) {
            _loadLastSeen(currentClass);
          }
          return _buildCurrentView(currentClass);
        },
      ),
    );
  }

  Widget _buildCurrentView(String currentClass) {
    return StreamBuilder<List<ForumChannel>>(
      stream: _forumService.getChannelsStream(currentClass),
      builder: (context, channelSnapshot) {
        if (channelSnapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerForumMessages();
        }
        if (channelSnapshot.hasError) {
          return Center(child: Text('Error loading channels: ${channelSnapshot.error}'));
        }
        final channels = channelSnapshot.data ?? [];
        if (_latestMsg.isEmpty && channels.isNotEmpty) {
          _loadLatestTimestamps(channels);
        }
        final user = context.read<AuthProvider>().currentUser;
        if (_showChannelList) {
          return _buildChannelList(channels, user);
        } else {
          return _buildChannelView(channels, currentClass, user);
        }
      },
    );
  }

  Widget _buildChannelList(List<ForumChannel> channels, dynamic user) {
    if (channels.isEmpty) {
      return const Center(child: Text('No channels yet. Create one to get started!'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final ch = channels[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isAdmin = user?.isAdmin ?? false;
        final isTeacher = user?.isTeacher ?? false;
        final canEdit = isTeacher || isAdmin;
        final lastSeen = _lastSeen[ch.id];
        final latest = _latestMsg[ch.id];
        final hasUnread = latest != null && (lastSeen == null || latest.isAfter(lastSeen));
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ch.isAnnouncement
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              child: Stack(
                children: [
                  Icon(
                    ch.isAnnouncement ? Icons.campaign : Icons.chat,
                    color: ch.isAnnouncement ? Colors.orange : Colors.blue,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(ch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (hasUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              ch.isAnnouncement ? 'Announcements' : 'Open discussion',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canEdit)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        _editChannel(ch);
                      } else if (action == 'delete' && isAdmin) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Channel'),
                            content: Text('Delete "${ch.name}"? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await _forumService.deleteChannel(ch.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${ch.name}" deleted')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('Edit'))),
                      if (isAdmin)
                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                    ],
                  ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              final classProvider = context.read<ClassProvider>();
              _markChannelSeen(ch.id, classProvider.currentClass);
              setState(() {
                _selectedChannelId = ch.id;
                _showChannelList = false;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildChannelView(List<ForumChannel> channels, String currentClass, dynamic user) {
    if (_selectedChannelId == null && channels.isNotEmpty) {
      _selectedChannelId = channels.first.id;
    }
    if (_selectedChannelId == null) {
      return const Center(child: Text('No channels available.'));
    }
    return Column(
      children: [
        if (channels.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: channels.map((ch) {
                final isSelected = _selectedChannelId == ch.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ch.isAnnouncement ? Icons.campaign : Icons.chat,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(ch.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        _markChannelSeen(ch.id, currentClass);
                        setState(() => _selectedChannelId = ch.id);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: _buildMessages(_selectedChannelId!, currentClass, user),
        ),
        _buildInputArea(channels, user),
      ],
    );
  }

  Widget _buildMessages(String channelId, String classId, dynamic user) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _forumService.getMessagesStream(channelId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading messages.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerForumMessages();
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet. Start the conversation!'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return _buildMessageBubble(msg);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isMe = currentUser != null && msg.senderName == currentUser.fullName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 18,
              backgroundImage: msg.senderAvatarUrl.isNotEmpty
                  ? NetworkImage(msg.senderAvatarUrl)
                  : const NetworkImage('https://i.pravatar.cc/100'),
            ),
          if (!isMe) const SizedBox(width: 8),
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(msg.senderName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? Theme.of(context).primaryColor : (isDark ? const Color(0xFF2A2A3E) : Colors.grey[200]),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 20),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(msg.timestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(List<ForumChannel> channels, dynamic user) {
    final selectedChannel = channels.where((c) => c.id == _selectedChannelId).firstOrNull;
    final bool isAnnouncement = selectedChannel?.isAnnouncement ?? false;
    final bool canPost = user != null && (!isAnnouncement || user.isTeacher || user.isAdmin || user.isLeader);

    if (!canPost) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[100],
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Text('Only admins and teachers can post in this channel.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(color: isDark ? Colors.white10 : Colors.black12, blurRadius: 4, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: isAnnouncement
                      ? 'Type an announcement...'
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sendMessage,
              elevation: 0,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}


