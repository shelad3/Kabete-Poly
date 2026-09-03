// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/state_views.dart';

class ManageListingsScreen extends StatefulWidget {
  const ManageListingsScreen({super.key});

  @override
  State<ManageListingsScreen> createState() => _ManageListingsScreenState();
}

class _ManageListingsScreenState extends State<ManageListingsScreen> {
  final ListingService _listingService = ListingService();

  Future<void> _toggleActive(Listing listing) async {
    await _listingService.updateListing(
      listing.id,
      Listing(
        id: listing.id,
        name: listing.name,
        description: listing.description,
        coverImage: listing.coverImage,
        images: listing.images,
        area: listing.area,
        location: listing.location,
        roomOptions: listing.roomOptions,
        contactPhone: listing.contactPhone,
        isActive: !listing.isActive,
        createdBy: listing.createdBy,
        createdAt: listing.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _deleteListing(Listing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Delete "${listing.name}"? This cannot be undone.'),
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
        await _listingService.deleteListing(listing.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing deleted'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Kejani Listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showListingForm(),
        icon: const Icon(Icons.add_home),
        label: const Text('New Listing'),
      ),
      body: StreamBuilder<List<Listing>>(
        stream: _listingService.getAllListingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data ?? [];
          if (listings.isEmpty) {
            return const EmptyState(
              icon: Icons.apartment,
              title: 'No listings yet',
              subtitle: 'Tap the button below to create your first listing.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listings.length,
            itemBuilder: (_, i) {
              final l = listings[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: l.coverImage.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            l.coverImage,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.apartment,
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(Icons.apartment, size: 40),
                  title: Text(l.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l.area} · ${l.roomOptions.length} options'),
                      Text(
                        l.isActive ? 'Active' : 'Hidden',
                        style: TextStyle(
                          color: l.isActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          l.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => _toggleActive(l),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showListingForm(existing: l),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteListing(l),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showListingForm({Listing? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ListingFormScreen(
          listingService: _listingService,
          existing: existing,
        ),
      ),
    );
  }
}

class _ListingFormScreen extends StatefulWidget {
  final ListingService listingService;
  final Listing? existing;

  const _ListingFormScreen({
    required this.listingService,
    this.existing,
  });

  @override
  State<_ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<_ListingFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _area = kListingAreas.first;
  bool _isActive = true;
  bool _isUploading = false;
  GeoPoint? _location;
  String _coverUrl = '';
  List<String> _galleryUrls = [];
  final List<File> _selectedImages = [];
  final List<_RoomDraft> _rooms = [];
  final StorageService _storage = StorageService();

  static const LatLng _campusCenter = LatLng(-1.264627, 36.727029);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description;
      _phoneCtrl.text = e.contactPhone;
      _area = e.area;
      _isActive = e.isActive;
      _location = e.location;
      _coverUrl = e.coverImage;
      _galleryUrls = List.of(e.images);
      for (final r in e.roomOptions) {
        _rooms.add(_RoomDraft(
          type: r.type,
          price: r.price,
          amenities: Set.of(r.amenities),
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _selectedImages.addAll(picked.map((p) => File(p.path))));
    }
  }

  void _addRoom() {
    setState(() => _rooms.add(_RoomDraft(type: kListingRoomTypes.first, price: 0)));
  }

  void _removeRoom(int index) {
    setState(() => _rooms.removeAt(index));
  }

  Future<void> _pickLocationOnMap() async {
    final initial = _location != null
        ? LatLng(_location!.latitude, _location!.longitude)
        : _campusCenter;
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPinScreen(initial: initial),
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _location = GeoPoint(picked.latitude, picked.longitude),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Listing name is required', isError: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      // If new images were picked, upload them (first = cover).
      List<String> uploaded = [];
      if (_selectedImages.isNotEmpty) {
        uploaded = await _storage.uploadImages(
          _selectedImages,
          'kejani/listings/${_isEdit ? widget.existing!.id : 'new'}',
        );
      }
      final cover = uploaded.isNotEmpty
          ? uploaded.first
          : (_coverUrl.isNotEmpty ? _coverUrl : '');
      final gallery = [
        if (uploaded.isNotEmpty) ...uploaded.skip(1),
        ..._galleryUrls,
      ];

      final roomOptions = _rooms
          .where((r) => r.price > 0)
          .map((r) => RoomOption(
                type: r.type,
                price: r.price,
                amenities: r.amenities.toList()..sort(),
              ))
          .toList();

      final now = DateTime.now();
      final layout = Listing(
        id: _isEdit ? widget.existing!.id : '',
        name: name,
        description: _descCtrl.text.trim(),
        coverImage: cover,
        images: gallery,
        area: _area,
        location: _location,
        roomOptions: roomOptions,
        contactPhone: _phoneCtrl.text.trim(),
        isActive: _isActive,
        createdBy: widget.existing?.createdBy ?? '',
        createdAt: _isEdit ? widget.existing!.createdAt : now,
        updatedAt: now,
      );

      if (_isEdit) {
        await widget.listingService.updateListing(widget.existing!.id, layout);
      } else {
        await widget.listingService.addListing(layout);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Listing updated' : 'Listing created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Save failed: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Listing' : 'New Listing'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _save,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Listing name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _area,
            decoration: const InputDecoration(
              labelText: 'Area',
              border: OutlineInputBorder(),
            ),
            items: kListingAreas
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _area = v ?? _area),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact phone (e.g. 07XX...)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible to users'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: 8),
          _buildLocationPicker(),
          const SizedBox(height: 12),
          _buildImagesSection(),
          const SizedBox(height: 12),
          _buildRoomsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    final hasLoc = _location != null;
    return Card(
      child: ListTile(
        leading: Icon(
          hasLoc ? Icons.location_on : Icons.location_off,
          color: hasLoc ? Colors.red : Colors.grey,
        ),
        title: Text(hasLoc ? 'Map pin set' : 'No map pin'),
        subtitle: hasLoc
            ? Text(
                '${_location!.latitude.toStringAsFixed(5)}, '
                '${_location!.longitude.toStringAsFixed(5)}',
              )
            : const Text('Tap to place a pin on the map'),
        trailing: TextButton(
          onPressed: _pickLocationOnMap,
          child: const Text('Set pin'),
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos (first = cover)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _selectedImages.isNotEmpty
            ? SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      Image.file(
                        _selectedImages[i],
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _selectedImages.removeAt(i),
                          ),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : (_galleryUrls.isNotEmpty
                ? SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _galleryUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _galleryUrls[i],
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick photos'),
        ),
      ],
    );
  }

  Widget _buildRoomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Room options', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_rooms.isEmpty)
          Text(
            'No room options yet',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        for (int i = 0; i < _rooms.length; i++) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _rooms[i].type,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: kListingRoomTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _rooms[i].type = v ?? _rooms[i].type),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'KES /mo',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      _rooms[i].price = int.tryParse(v) ?? 0,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeRoom(i),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Amenities',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kListingAmenities.map((a) {
              final selected = _rooms[i].amenities.contains(a);
              return FilterChip(
                label: Text(
                  a,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _rooms[i].amenities.add(a);
                    } else {
                      _rooms[i].amenities.remove(a);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _addRoom,
          icon: const Icon(Icons.add),
          label: const Text('Add room option'),
        ),
      ],
    );
  }
}

class _RoomDraft {
  String type;
  int price;
  final Set<String> amenities;
  _RoomDraft({
    required this.type,
    required this.price,
    Set<String>? amenities,
  }) : amenities = amenities ?? <String>{};
}

class _MapPinScreen extends StatefulWidget {
  final LatLng initial;
  const _MapPinScreen({required this.initial});

  @override
  State<_MapPinScreen> createState() => _MapPinScreenState();
}

class _MapPinScreenState extends State<_MapPinScreen> {
  late LatLng _pin;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _pin = widget.initial;
    _markers = {
      Marker(markerId: const MarkerId('pin'), position: _pin),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Listing Pin'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _pin),
            child: const Text('Done'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _pin, zoom: 15),
        markers: _markers,
        onTap: (latLng) {
          setState(() {
            _pin = latLng;
            _markers = {
              Marker(markerId: const MarkerId('pin'), position: _pin),
            };
          });
        },
        mapType: MapType.normal,
      ),
    );
  }
}
