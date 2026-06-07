import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/forum_channel.dart';
import '../services/forum_service.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import 'package:intl/intl.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ForumService _forumService = ForumService();
  final _textController = TextEditingController();
  String? _selectedChannelId;

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
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canCreateChannel = user != null && (user.isTeacher || user.isLeader || user.isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Forum'),
        actions: [
          if (canCreateChannel)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Channel',
              onPressed: _createChannel,
            ),
        ],
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, _) {
          final currentClass = classProvider.currentClass;
          return StreamBuilder<List<ForumChannel>>(
            stream: _forumService.getChannelsStream(currentClass),
            builder: (context, channelSnapshot) {
              final channels = channelSnapshot.data ?? [];
              if (_selectedChannelId == null && channels.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedChannelId = channels.first.id);
                  }
                });
              }

              return Column(
                children: [
                  if (channels.isNotEmpty)
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: channels.map((ch) {
                          final isSelected = _selectedChannelId == ch.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ch.isAnnouncement ? Icons.campaign : Icons.chat,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(ch.name),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) setState(() => _selectedChannelId = ch.id);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (_selectedChannelId != null)
                    Expanded(
                      child: _buildMessages(_selectedChannelId!, currentClass, user),
                    )
                  else
                    const Expanded(
                      child: Center(child: Text('No channels available.')),
                    ),
                  if (_selectedChannelId != null)
                    _buildInputArea(channels, user),
                ],
              );
            },
          );
        },
      ),
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
          return const Center(child: CircularProgressIndicator());
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
                  color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 20),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
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
                  fillColor: Colors.grey[100],
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
