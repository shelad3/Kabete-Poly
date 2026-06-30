// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

class House {
  final String id;
  final String name;
  final String category; // 'boys' or 'girls'
  final int totalCubes;
  final String? description;
  final bool reservedForNewStudents;

  House({
    required this.id,
    required this.name,
    required this.category,
    this.totalCubes = 12,
    this.description,
    this.reservedForNewStudents = false,
  });

  factory House.fromJson(Map<String, dynamic> json, String docId) => House(
    id: docId,
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? 'boys',
    totalCubes: (json['totalCubes'] as num?)?.toInt() ?? 12,
    description: json['description'] as String?,
    reservedForNewStudents: json['reservedForNewStudents'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'totalCubes': totalCubes,
    if (description != null) 'description': description,
    'reservedForNewStudents': reservedForNewStudents,
  };
}
