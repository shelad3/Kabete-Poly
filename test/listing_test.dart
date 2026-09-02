// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:kabete2026eiteet/models/listing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Listing.startingPrice', () {
    test('returns cheapest room option price', () {
      final listing = Listing(
        id: 'l1',
        name: 'Sunny Apartments',
        description: 'Great place',
        area: 'Kabete Town',
        roomOptions: const [
          RoomOption(type: 'Self Contained', price: 12000),
          RoomOption(type: '1 Room', price: 8000),
          RoomOption(type: 'Bedsitter', price: 6500),
        ],
      );
      expect(listing.startingPrice, 6500);
    });

    test('returns null when no room options', () {
      final listing = Listing(id: 'l2', name: 'X', description: '', area: 'Uthiru');
      expect(listing.startingPrice, isNull);
    });

    test('handles a single option', () {
      final listing = Listing(
        id: 'l3',
        name: 'Y',
        description: '',
        area: 'Kinoo',
        roomOptions: const [RoomOption(type: '2 Rooms', price: 15000)],
      );
      expect(listing.startingPrice, 15000);
    });
  });

  group('Listing.fromJson', () {
    test('parses a full document with GeoPoint and Timestamp', () {
      final when = DateTime(2026, 8, 1, 9, 30);
      final listing = Listing.fromJson({
        'name': 'Green Homes',
        'description': 'Near Gate A',
        'coverImage': 'https://img.example/cover.jpg',
        'images': ['https://img.example/a.jpg', 'https://img.example/b.jpg'],
        'area': 'Near Gate A',
        'location': GeoPoint(-1.2646, 36.7270),
        'roomOptions': [
          {'type': 'Self Contained', 'price': 13000},
          {'type': 'Shared', 'price': 4500},
        ],
        'contactPhone': '0712345678',
        'isActive': true,
        'createdBy': 'admin-uid',
        'createdAt': Timestamp.fromDate(when),
      }, 'doc-1');

      expect(listing.id, 'doc-1');
      expect(listing.name, 'Green Homes');
      expect(listing.area, 'Near Gate A');
      expect(listing.location?.latitude, closeTo(-1.2646, 0.0001));
      expect(listing.roomOptions.length, 2);
      expect(listing.roomOptions.first.type, 'Self Contained');
      expect(listing.startingPrice, 4500);
      expect(listing.contactPhone, '0712345678');
      expect(listing.isActive, isTrue);
      expect(listing.createdAt, when);
    });

    test('handles missing optional fields gracefully', () {
      final listing = Listing.fromJson({'name': 'Minimal'}, 'doc-2');
      expect(listing.area, 'Other');
      expect(listing.location, isNull);
      expect(listing.images, isEmpty);
      expect(listing.roomOptions, isEmpty);
      expect(listing.isActive, isTrue);
      expect(listing.startingPrice, isNull);
    });
  });

  group('Listing.toJson', () {
    test('round-trips non-null fields', () {
      final listing = Listing(
        id: 'doc-3',
        name: 'Round Trip',
        description: 'desc',
        coverImage: 'https://img.example/c.jpg',
        images: const ['https://img.example/x.jpg'],
        area: 'Mugeka',
        location: GeoPoint(-1.25, 36.72),
        roomOptions: const [RoomOption(type: '1 Room', price: 7500)],
        contactPhone: '0700111222',
        isActive: false,
        createdAt: DateTime(2026, 7, 1),
      );
      final json = listing.toJson();
      expect(json['name'], 'Round Trip');
      expect(json['area'], 'Mugeka');
      expect(json['isActive'], isFalse);
      expect(json['location'], isA<GeoPoint>());
      expect(json['roomOptions'], isA<List<dynamic>>());
      expect(json['createdAt'], isA<Timestamp>());
    });

    test('omits empty image/location/phone fields', () {
      final listing = Listing(
        id: 'doc-4',
        name: 'Min',
        description: '',
        area: 'Other',
      );
      final json = listing.toJson();
      expect(json.containsKey('coverImage'), isFalse);
      expect(json.containsKey('images'), isFalse);
      expect(json.containsKey('location'), isFalse);
      expect(json.containsKey('contactPhone'), isFalse);
      expect(json.containsKey('createdBy'), isFalse);
    });
  });

  group('Listing constants', () {
    test('areas are non-empty and deduplicated', () {
      expect(kListingAreas, isNotEmpty);
      expect(kListingAreas.toSet().length, kListingAreas.length);
      expect(kListingAreas, contains('Kabete Town'));
    });

    test('room types are non-empty', () {
      expect(kListingRoomTypes, isNotEmpty);
      expect(kListingRoomTypes, contains('Self Contained'));
    });
  });
}
