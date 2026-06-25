import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data?.docs ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No events yet',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Event galleries will appear here',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index].data() as Map<String, dynamic>;
              final eventId = events[index].id;
              return _EventCard(eventId: eventId, event: event);
            },
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const _EventCard({required this.eventId, required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? 'Untitled Event';
    final description = event['description'] as String? ?? '';
    final date = event['date'] as Timestamp?;
    final dateStr = date != null
        ? DateFormat('d MMM yyyy').format(date.toDate())
        : 'Date TBD';
    final coverUrl = event['coverUrl'] as String?;
    final photoCount = (event['photoCount'] as num?)?.toInt() ?? 0;
    final visibility = event['visibility'] as String? ?? 'public';

    if (visibility == 'private') return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEventGallery(context, eventId, event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultHeader(title),
              )
            else
              _defaultHeader(title),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      if (photoCount > 0) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.photo,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$photoCount photos',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultHeader(String title) {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.primaries[title.hashCode % Colors.primaries.length]
          .withValues(alpha: 0.3),
      child: Center(
        child: Icon(Icons.photo_library_outlined,
            size: 48, color: Colors.white70),
      ),
    );
  }

  void _openEventGallery(
      BuildContext context, String eventId, Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EventGalleryScreen(
          eventId: eventId,
          event: event,
        ),
      ),
    );
  }
}

class _EventGalleryScreen extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const _EventGalleryScreen(
      {required this.eventId, required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? 'Event Gallery';
    final specialGuests =
        (event['specialGuests'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (specialGuests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Special Guests',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: specialGuests.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final guest = specialGuests[i];
                        final guestName =
                            guest['name'] as String? ?? 'Guest';
                        final guestRole =
                            guest['role'] as String? ?? '';
                        final guestPhoto = guest['photoUrl'] as String?;
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: guestPhoto != null &&
                                      guestPhoto.isNotEmpty
                                  ? NetworkImage(guestPhoto)
                                  : null,
                              child: guestPhoto == null ||
                                      guestPhoto.isEmpty
                                  ? Text(guestName[0].toUpperCase())
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(guestName,
                                style: const TextStyle(fontSize: 11)),
                            if (guestRole.isNotEmpty)
                              Text(guestRole,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600])),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .collection('photos')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final photos = snapshot.data?.docs ?? [];
                if (photos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No photos in this event',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) {
                    final photo = photos[i].data() as Map<String, dynamic>;
                    final url = photo['url'] as String? ?? '';
                    return GestureDetector(
                      onTap: () => _viewPhoto(context, url),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child:
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
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

  void _viewPhoto(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
