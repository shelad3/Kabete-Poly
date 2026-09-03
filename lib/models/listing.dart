// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

/// Predefined areas near campus for filtering listings.
const kListingAreas = <String>[
  'Kabete Town',
  'Kwa Chief',
  'Red Soil',
  'Near Gate A',
  'Along Kabete Road',
  'Kabete Market',
  'Mugeka',
  'Uthiru',
  'Kinoo',
  'Other',
];

/// Predefined accommodation/room options for a listing.
const kListingRoomTypes = <String>[
  'Self Contained',
  '1 Room',
  '2 Rooms',
  'Bedsitter',
  'Shared',
];

/// Amenities a room option may include.
const kListingAmenities = <String>[
  'Bathroom',
  'Kitchen',
  'Parking',
  'Wifi',
  'Water',
  'Electricity',
  'Balcony',
  'Security',
];

/// A single rentable room option within an apartment listing.
class RoomOption {
  final String type; // one of kListingRoomTypes
  final int price; // monthly rent in KES
  final List<String> amenities; // subset of kListingAmenities

  const RoomOption({
    required this.type,
    required this.price,
    this.amenities = const [],
  });

  factory RoomOption.fromJson(Map<String, dynamic> json) => RoomOption(
        type: json['type'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        amenities: (json['amenities'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'price': price,
        if (amenities.isNotEmpty) 'amenities': amenities,
      };
}

/// An apartment / rental listing near campus.
class Listing {
  final String id;
  final String name;
  final String description;
  final String coverImage;
  final List<String> images;
  final String area;
  final GeoPoint? location; // lat/lng pin for map sync
  final List<RoomOption> roomOptions;
  final String contactPhone;
  final bool isActive;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Listing({
    required this.id,
    required this.name,
    required this.description,
    this.coverImage = '',
    this.images = const [],
    required this.area,
    this.location,
    this.roomOptions = const [],
    this.contactPhone = '',
    this.isActive = true,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  /// The cheapest monthly rent across all room options (null if none set).
  int? get startingPrice {
    if (roomOptions.isEmpty) return null;
    return roomOptions.map((r) => r.price).reduce((a, b) => a < b ? a : b);
  }

  factory Listing.fromJson(Map<String, dynamic> json, String docId) {
    final location = json['location'];
    return Listing(
      id: docId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverImage: json['coverImage'] as String? ?? '',
      images: (json['images'] as List?)?.cast<String>() ?? const [],
      area: json['area'] as String? ?? 'Other',
      location: location is GeoPoint ? location : null,
      roomOptions: (json['roomOptions'] as List?)
              ?.map((e) => RoomOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      contactPhone: json['contactPhone'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (coverImage.isNotEmpty) 'coverImage': coverImage,
        if (images.isNotEmpty) 'images': images,
        'area': area,
        if (location != null) 'location': location,
        if (roomOptions.isNotEmpty)
          'roomOptions': roomOptions.map((r) => r.toJson()).toList(),
        if (contactPhone.isNotEmpty) 'contactPhone': contactPhone,
        'isActive': isActive,
        if (createdBy.isNotEmpty) 'createdBy': createdBy,
        if (createdAt != null)
          'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null)
          'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
