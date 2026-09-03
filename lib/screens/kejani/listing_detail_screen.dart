// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/listing.dart';
import 'kejani_tab.dart' show formatKes;

class ListingDetailScreen extends StatelessWidget {
  final Listing listing;
  const ListingDetailScreen({super.key, required this.listing});

  void _openMaps() async {
    final loc = listing.location;
    if (loc == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _callContact() async {
    final uri = Uri.parse('tel:${listing.contactPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _whatsapp() async {
    final number =
        listing.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyContact(BuildContext context) async {
    if (listing.contactPhone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: listing.contactPhone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = listing.startingPrice;
    final allImages =
        [if (listing.coverImage.isNotEmpty) listing.coverImage, ...listing.images];

    return Scaffold(
      appBar: AppBar(title: Text(listing.name)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (allImages.isNotEmpty)
            _ImageCarousel(images: allImages, name: listing.name),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (price != null)
                      Text(
                        formatKes(price),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.area,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'About this place',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  listing.description.isEmpty
                      ? 'No description provided.'
                      : listing.description,
                ),
                if (listing.roomOptions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Room options',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...listing.roomOptions.map((r) => _RoomOptionRow(option: r)),
                ],
                if (listing.location != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LocationCard(
                    lat: listing.location!.latitude,
                    lng: listing.location!.longitude,
                    onOpenMaps: _openMaps,
                  ),
                ],
                if (listing.contactPhone.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ContactCard(
                    phone: listing.contactPhone,
                    onCall: _callContact,
                    onWhatsApp: _whatsapp,
                    onCopy: () => _copyContact(context),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  onPressed:
                      listing.contactPhone.isEmpty ? null : _callContact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: listing.contactPhone.isEmpty ? null : _whatsapp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<String> images;
  final String name;
  const _ImageCarousel({required this.images, required this.name});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Image.network(
              widget.images[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1}/${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomOptionRow extends StatelessWidget {
  final RoomOption option;
  const _RoomOptionRow({required this.option});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.king_bed_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(option.type, style: const TextStyle(fontSize: 15)),
              ),
              Text(
                formatKes(option.price),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (option.amenities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: option.amenities.map((a) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final double lat;
  final double lng;
  final VoidCallback onOpenMaps;
  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.map, color: theme.colorScheme.primary),
        title: Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
        subtitle: const Text('Open in Google Maps'),
        trailing: const Icon(Icons.open_in_new),
        onTap: onOpenMaps,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopy;
  const _ContactCard({
    required this.phone,
    required this.onCall,
    required this.onWhatsApp,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.phone_outlined,
              color: theme.colorScheme.primary,
            ),
            title: SelectableText(
              phone,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text('Tap to call'),
            trailing: IconButton(
              tooltip: 'Copy contact',
              icon: const Icon(Icons.copy_rounded),
              onPressed: onCopy,
            ),
            onTap: onCall,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.06,
                      ),
                    ),
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Open in WhatsApp'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
