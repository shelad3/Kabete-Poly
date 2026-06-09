import 'package:flutter/material.dart';

enum LocationType {
  adminOffice,
  academicBlock,
  lab,
  workshop,
  departmentOffice,
  staffRoom,
  library,
  hall,
  hostel,
  medBay,
  busPark,
  sportsField,
  cafeteria,
  other,
}

class CampusLocation {
  final String id;
  final String name;
  final String description;
  final LocationType type;
  final double lat;
  final double lng;
  final Color color;
  final List<String> aliases;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.lat,
    required this.lng,
    this.color = Colors.grey,
    this.aliases = const [],
  });
}

Color colorForType(LocationType type) {
  switch (type) {
    case LocationType.adminOffice:
      return const Color(0xFF1565C0);
    case LocationType.academicBlock:
      return const Color(0xFFEF6C00);
    case LocationType.lab:
      return const Color(0xFF00897B);
    case LocationType.workshop:
      return const Color(0xFF6D4C41);
    case LocationType.departmentOffice:
      return const Color(0xFF7B1FA2);
    case LocationType.staffRoom:
      return const Color(0xFF37474F);
    case LocationType.library:
      return const Color(0xFF283593);
    case LocationType.hall:
      return const Color(0xFF6A1B9A);
    case LocationType.hostel:
      return const Color(0xFFC62828);
    case LocationType.medBay:
      return const Color(0xFFD32F2F);
    case LocationType.busPark:
      return const Color(0xFF546E7A);
    case LocationType.sportsField:
      return const Color(0xFF2E7D32);
    case LocationType.cafeteria:
      return const Color(0xFFF9A825);
    case LocationType.other:
      return const Color(0xFF757575);
  }
}

String labelForType(LocationType type) {
  switch (type) {
    case LocationType.adminOffice:
      return 'Admin Office';
    case LocationType.academicBlock:
      return 'Academic Block';
    case LocationType.lab:
      return 'Laboratory';
    case LocationType.workshop:
      return 'Workshop';
    case LocationType.departmentOffice:
      return 'Dept Office';
    case LocationType.staffRoom:
      return 'Staff Room';
    case LocationType.library:
      return 'Library';
    case LocationType.hall:
      return 'Hall';
    case LocationType.hostel:
      return 'Hostel';
    case LocationType.medBay:
      return 'Med Bay';
    case LocationType.busPark:
      return 'Bus Park';
    case LocationType.sportsField:
      return 'Sports Field';
    case LocationType.cafeteria:
      return 'Cafeteria';
    case LocationType.other:
      return 'Other';
  }
}

IconData iconForType(LocationType type) {
  switch (type) {
    case LocationType.adminOffice:
      return Icons.business;
    case LocationType.academicBlock:
      return Icons.school;
    case LocationType.lab:
      return Icons.science;
    case LocationType.workshop:
      return Icons.build;
    case LocationType.departmentOffice:
      return Icons.meeting_room;
    case LocationType.staffRoom:
      return Icons.people;
    case LocationType.library:
      return Icons.local_library;
    case LocationType.hall:
      return Icons.theater_comedy;
    case LocationType.hostel:
      return Icons.bed;
    case LocationType.medBay:
      return Icons.local_hospital;
    case LocationType.busPark:
      return Icons.directions_bus;
    case LocationType.sportsField:
      return Icons.sports_soccer;
    case LocationType.cafeteria:
      return Icons.restaurant;
    case LocationType.other:
      return Icons.place;
  }
}

final List<CampusLocation> campusLocations = [
  CampusLocation(
    id: 'bus_park',
    name: 'Bus Park / Entrance',
    description: 'Main entrance, bus drop-off, and security post at the north-west gate.',
    type: LocationType.busPark,
    lat: -1.26250,
    lng: 36.72410,
    aliases: ['Bus Park', 'Bus Stop', 'Bus Terminal', 'Parking', 'Entrance', 'Gate'],
  ),
  CampusLocation(
    id: 'e_block',
    name: 'E Block (Engineering)',
    description: 'Engineering classrooms, lecture halls, and department offices.',
    type: LocationType.academicBlock,
    lat: -1.26321,
    lng: 36.72612,
    aliases: [
      'E Block', 'E-2A', 'E-1F', 'E-1A', 'E-2B', 'E-2C',
      'Engineering Block', 'Engineering',
    ],
  ),
  CampusLocation(
    id: 'solar_lab',
    name: 'Solar Energy Lab',
    description: 'Solar energy research and practical training laboratory.',
    type: LocationType.lab,
    lat: -1.26337,
    lng: 36.72700,
    aliases: ['SOLAR LAB', 'Solar Lab', 'Solar Laboratory'],
  ),
  CampusLocation(
    id: 'staff_room',
    name: 'Staff Room',
    description: 'Common room and workspace for teaching staff.',
    type: LocationType.staffRoom,
    lat: -1.26276,
    lng: 36.72772,
    aliases: ['Staff Room', 'Staffroom', 'Teachers Lounge'],
  ),
  CampusLocation(
    id: 'admin_block',
    name: 'Administration Block',
    description: 'Principal\'s office, Deputy Principal, HOD offices, and main administrative staff.',
    type: LocationType.adminOffice,
    lat: -1.26256,
    lng: 36.72835,
    aliases: ['Admin Block', 'Admin Office', 'Administration'],
  ),
  CampusLocation(
    id: 'electronics_lab',
    name: 'Electronics Lab',
    description: 'Electronics and circuit design laboratory.',
    type: LocationType.lab,
    lat: -1.26414,
    lng: 36.72700,
    aliases: ['Electronics Lab', 'Electronics Laboratory'],
  ),
  CampusLocation(
    id: 'library',
    name: 'Library',
    description: 'Main campus library with books, journals, and study areas.',
    type: LocationType.library,
    lat: -1.26398,
    lng: 36.72814,
    aliases: ['Library', 'Library Block'],
  ),
  CampusLocation(
    id: 'smart_lab',
    name: 'Smart Lab',
    description: 'Modern smart classroom with digital learning technology.',
    type: LocationType.lab,
    lat: -1.26401,
    lng: 36.72891,
    aliases: ['Smart Lab', 'Smart Laboratory'],
  ),
  CampusLocation(
    id: 'computer_lab',
    name: 'Computer Lab',
    description: 'Computer laboratory for ICT and programming practicals.',
    type: LocationType.lab,
    lat: -1.26385,
    lng: 36.72959,
    aliases: ['Computer Lab', 'Computer Laboratory', 'ICT Lab'],
  ),
  CampusLocation(
    id: 'hostel_a',
    name: 'Hostel A (Male)',
    description: 'Male students\' residential hostel.',
    type: LocationType.hostel,
    lat: -1.26424,
    lng: 36.73000,
    aliases: ['Hostel A', 'Male Hostel', 'Boys Hostel'],
  ),
  CampusLocation(
    id: 'main_hall',
    name: 'Main Hall',
    description: 'Multipurpose hall for assemblies, events, and examinations.',
    type: LocationType.hall,
    lat: -1.26475,
    lng: 36.72679,
    aliases: ['Hall', 'Main Hall', 'Assembly Hall', 'Exam Hall'],
  ),
  CampusLocation(
    id: 'electrical_workshop',
    name: 'Electrical Workshop',
    description: 'Hands-on electrical installation and wiring workshop.',
    type: LocationType.workshop,
    lat: -1.26533,
    lng: 36.72710,
    aliases: ['Electrical Workshop', 'Workshop'],
  ),
  CampusLocation(
    id: 'machines_lab',
    name: 'Machines Laboratory',
    description: 'Electrical machines and equipment testing laboratory.',
    type: LocationType.lab,
    lat: -1.26578,
    lng: 36.72938,
    aliases: ['MACHINES LAB (E Block)', 'Machines Lab', 'Machine Lab'],
  ),
  CampusLocation(
    id: 'hostel_b',
    name: 'Hostel B (Female)',
    description: 'Female students\' residential hostel with courtyard.',
    type: LocationType.hostel,
    lat: -1.26649,
    lng: 36.72824,
    aliases: ['Hostel B', 'Female Hostel', 'Girls Hostel'],
  ),
  CampusLocation(
    id: 'hod_offices',
    name: 'HOD Offices',
    description: 'Heads of Department offices for Engineering, ICT, and Business.',
    type: LocationType.departmentOffice,
    lat: -1.26526,
    lng: 36.72876,
    aliases: ['HOD', 'HOD Offices', 'Department Offices', 'Dept Office'],
  ),
  CampusLocation(
    id: 'med_bay',
    name: 'Med Bay',
    description: 'Campus health center providing first aid and basic medical care.',
    type: LocationType.medBay,
    lat: -1.26674,
    lng: 36.72948,
    aliases: ['Med Bay', 'Medical Bay', 'Health Center', 'Clinic', 'Sick Bay'],
  ),
  CampusLocation(
    id: 'workshop_outside',
    name: 'Workshop (Outside Setup)',
    description: 'Outdoor practical workshop area for field installations.',
    type: LocationType.workshop,
    lat: -1.26700,
    lng: 36.72514,
    aliases: ['Workshop (Outside Setup)', 'Outside Workshop', 'External Workshop'],
  ),
  CampusLocation(
    id: 'sports_field',
    name: 'Sports Field',
    description: 'Athletics oval track and football pitch with grass infield.',
    type: LocationType.sportsField,
    lat: -1.26411,
    lng: 36.72400,
    aliases: ['Sports Field', 'Football Field', 'Pitch', 'Playground', 'Field', 'Track'],
  ),
  CampusLocation(
    id: 'cafeteria',
    name: 'Cafeteria',
    description: 'Student and staff dining area serving meals and refreshments.',
    type: LocationType.cafeteria,
    lat: -1.26597,
    lng: 36.72772,
    aliases: ['Cafeteria', 'Dining Hall', 'Kitchen'],
  ),
];

final Map<String, String> venueToLocationId = {
  'E-2A': 'e_block',
  'E-1F': 'e_block',
  'E-1A': 'e_block',
  'E-2B': 'e_block',
  'E-2C': 'e_block',
  'SOLAR LAB': 'solar_lab',
  'Solar Lab': 'solar_lab',
  'MACHINES LAB (E Block)': 'machines_lab',
  'Machines Lab (E Block)': 'machines_lab',
  'Machines Lab': 'machines_lab',
  'Electrical Workshop': 'electrical_workshop',
  'Electronics Lab': 'electronics_lab',
  'Smart Lab': 'smart_lab',
  'Computer Lab': 'computer_lab',
  'Library': 'library',
  'Main Hall': 'main_hall',
  'Hall': 'main_hall',
  'Cafeteria': 'cafeteria',
  'Bus Park': 'bus_park',
  'Sports Field': 'sports_field',
  'Workshop (Outside Setup)': 'workshop_outside',
  'Med Bay': 'med_bay',
};

final Map<String, String> teacherToOfficeLocationId = {
  'Mr. Kamau': 'staff_room',
  'Ms. Wanjiku': 'staff_room',
  'Dr. Ochieng': 'hod_offices',
  'Eng. Mutua': 'e_block',
  'Mr. Kiprop': 'e_block',
  'Mrs. Akinyi': 'staff_room',
  'Mr. Njoroge': 'electrical_workshop',
  'Mr. Odhiambo': 'hod_offices',
  'Prof. Wekesa': 'admin_block',
  'Madam Grace': 'staff_room',
  'Mr. Otieno': 'e_block',
  'Madam Faith': 'computer_lab',
  'Mr. Kosgey': 'staff_room',
};

CampusLocation? findLocationByVenue(String room) {
  final cleaned = room.trim();
  if (venueToLocationId.containsKey(cleaned)) {
    final id = venueToLocationId[cleaned]!;
    return campusLocations.where((l) => l.id == id).firstOrNull;
  }
  for (final loc in campusLocations) {
    if (loc.aliases.any((a) => cleaned.toLowerCase().contains(a.toLowerCase()))) {
      return loc;
    }
  }
  return null;
}

CampusLocation? findLocationByTeacher(String teacherName) {
  final cleaned = teacherName.trim();
  if (teacherToOfficeLocationId.containsKey(cleaned)) {
    final id = teacherToOfficeLocationId[cleaned]!;
    return campusLocations.where((l) => l.id == id).firstOrNull;
  }
  for (final entry in teacherToOfficeLocationId.entries) {
    if (cleaned.toLowerCase().contains(entry.key.toLowerCase())) {
      return campusLocations.where((l) => l.id == entry.value).firstOrNull;
    }
  }
  return null;
}
