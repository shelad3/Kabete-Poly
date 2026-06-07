import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/forum_channel.dart';

class ForumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _defaultsAttempted = {};

  // --- Channels ---

  Stream<List<ForumChannel>> getChannelsStream(String classId) {
    return _firestore
        .collection('forum_channels')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
      final channels = snapshot.docs.map(
          (doc) => ForumChannel.fromJson(doc.data(), doc.id)).toList();
      channels.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // If no channels exist yet, trigger creation of defaults (once per class)
      if (channels.isEmpty && _defaultsAttempted.add(classId)) {
        _ensureDefaultChannels(classId);
      }
      return channels;
    });
  }

  Future<void> _ensureDefaultChannels(String classId) async {
    final existing = await _firestore
        .collection('forum_channels')
        .where('classId', isEqualTo: classId)
        .get();

    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final globalRef = _firestore.collection('forum_channels').doc();
    batch.set(globalRef, {
      'classId': classId,
      'name': 'Global',
      'type': 'announcement',
      'createdBy': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final chatRef = _firestore.collection('forum_channels').doc();
    batch.set(chatRef, {
      'classId': classId,
      'name': 'Public Chat Room',
      'type': 'chat',
      'createdBy': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> createChannel(ForumChannel channel) async {
    await _firestore.collection('forum_channels').add(channel.toJson());
  }

  Future<void> deleteChannel(String channelId) async {
    await _firestore.collection('forum_channels').doc(channelId).delete();
  }

  // --- Messages ---

  Stream<List<ChatMessage>> getMessagesStream(String channelId) {
    return _firestore
        .collection('messages')
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList();
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    });
  }

  Future<void> sendMessage(ChatMessage message) async {
    await _firestore.collection('messages').add(message.toJson());
  }
}
