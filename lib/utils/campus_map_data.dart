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
  washroom,
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
    case LocationType.washroom:
      return const Color(0xFF00BCD4);
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
    case LocationType.washroom:
      return 'Washroom';
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
    case LocationType.washroom:
      return Icons.wc;
    case LocationType.other:
      return Icons.place;
  }
}

final List<CampusLocation> campusLocations = [
  // ---- BOYS' HOUSES ----
  const CampusLocation(
    id: 'elgon_1',
    name: 'Elgon 1',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264790,
    lng: 36.725540,
    aliases: ['Elgon 1', 'Elgon One'],
  ),
  const CampusLocation(
    id: 'elgon_2',
    name: 'Elgon 2',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264893,
    lng: 36.725539,
    aliases: ['Elgon 2', 'Elgon Two'],
  ),
  const CampusLocation(
    id: 'elgon_3',
    name: 'Elgon 3',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.265011,
    lng: 36.725557,
    aliases: ['Elgon 3', 'Elgon Three'],
  ),
  const CampusLocation(
    id: 'elgon_4',
    name: 'Elgon 4',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.265114,
    lng: 36.725582,
    aliases: ['Elgon 4', 'Elgon Four'],
  ),
  const CampusLocation(
    id: 'house_5',
    name: 'House 5',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264762,
    lng: 36.725874,
    aliases: ['House 5'],
  ),
  const CampusLocation(
    id: 'house_6',
    name: 'House 6',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264859,
    lng: 36.725889,
    aliases: ['House 6'],
  ),
  const CampusLocation(
    id: 'house_7',
    name: 'House 7',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264970,
    lng: 36.725889,
    aliases: ['House 7'],
  ),
  const CampusLocation(
    id: 'house_8',
    name: 'House 8',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.265094,
    lng: 36.725899,
    aliases: ['House 8'],
  ),
  const CampusLocation(
    id: 'longonot_1',
    name: 'Longonot 1',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264740,
    lng: 36.726114,
    aliases: ['Longonot 1', 'Longonot One'],
  ),
  const CampusLocation(
    id: 'longonot_2',
    name: 'Longonot 2',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264861,
    lng: 36.726099,
    aliases: ['Longonot 2', 'Longonot Two'],
  ),
  const CampusLocation(
    id: 'longonot_3',
    name: 'Longonot 3',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.264967,
    lng: 36.726105,
    aliases: ['Longonot 3', 'Longonot Three'],
  ),
  const CampusLocation(
    id: 'longonot_4',
    name: 'Longonot 4',
    description: 'Boys\' residential house.',
    type: LocationType.hostel,
    lat: -1.265094,
    lng: 36.726112,
    aliases: ['Longonot 4', 'Longonot Four'],
  ),
  const CampusLocation(
    id: 'white_house',
    name: 'White House',
    description: 'Boys\' residential house with 16 cubes.',
    type: LocationType.hostel,
    lat: -1.265320,
    lng: 36.725932,
    aliases: ['White House', 'Whitehouse'],
  ),

  // ---- BOYS' WASHROOMS ----
  const CampusLocation(
    id: 'washroom_a',
    name: 'Boys Washroom A',
    description: 'Boys\' washroom facility.',
    type: LocationType.washroom,
    lat: -1.264830,
    lng: 36.726250,
    aliases: ['Washroom A', 'Boys Washroom A'],
  ),
  const CampusLocation(
    id: 'washroom_b',
    name: 'Boys Washroom B',
    description: 'Boys\' washroom facility.',
    type: LocationType.washroom,
    lat: -1.264865,
    lng: 36.725720,
    aliases: ['Washroom B', 'Boys Washroom B'],
  ),
  const CampusLocation(
    id: 'washroom_c',
    name: 'Boys Washroom C',
    description: 'Boys\' washroom facility.',
    type: LocationType.washroom,
    lat: -1.265367,
    lng: 36.725666,
    aliases: ['Washroom C', 'Boys Washroom C'],
  ),

  // ---- GIRLS' HOUSES ----
  const CampusLocation(
    id: 'girls_1',
    name: 'Girls House 1',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.264788,
    lng: 36.725315,
    aliases: ['Girls House 1', 'Girls 1'],
  ),
  const CampusLocation(
    id: 'girls_2',
    name: 'Girls House 2',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.264898,
    lng: 36.725304,
    aliases: ['Girls House 2', 'Girls 2'],
  ),
  const CampusLocation(
    id: 'girls_3',
    name: 'Girls House 3',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.265021,
    lng: 36.725335,
    aliases: ['Girls House 3', 'Girls 3'],
  ),
  const CampusLocation(
    id: 'girls_4',
    name: 'Girls House 4',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.265129,
    lng: 36.725311,
    aliases: ['Girls House 4', 'Girls 4'],
  ),
  const CampusLocation(
    id: 'girls_5',
    name: 'Girls House 5',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.265290,
    lng: 36.725351,
    aliases: ['Girls House 5', 'Girls 5'],
  ),
  const CampusLocation(
    id: 'girls_6',
    name: 'Girls House 6',
    description: 'Girls\' residential house.',
    type: LocationType.hostel,
    lat: -1.265366,
    lng: 36.725332,
    aliases: ['Girls House 6', 'Girls 6'],
  ),

  // ---- CAMPUS FACILITIES ----
  const CampusLocation(
    id: 'student_kitchen',
    name: 'Student Kitchen',
    description: 'Campus kitchen serving meals to students.',
    type: LocationType.cafeteria,
    lat: -1.265307,
    lng: 36.726290,
    aliases: ['Student Kitchen', 'Kitchen'],
  ),
  const CampusLocation(
    id: 'west_hall',
    name: 'West Hall',
    description: 'Multipurpose hall near the residential area.',
    type: LocationType.hall,
    lat: -1.265310,
    lng: 36.726185,
    aliases: ['West Hall'],
  ),
  const CampusLocation(
    id: 'east_hall',
    name: 'East Hall',
    description: 'Multipurpose hall near the residential area.',
    type: LocationType.hall,
    lat: -1.265319,
    lng: 36.726404,
    aliases: ['East Hall'],
  ),
  const CampusLocation(
    id: 'basketball_court',
    name: 'Basketball Court',
    description: 'Outdoor basketball court for students.',
    type: LocationType.sportsField,
    lat: -1.264861,
    lng: 36.726478,
    aliases: ['Basketball Court', 'Basketball'],
  ),
  const CampusLocation(
    id: 'ee_block',
    name: 'Electrical Engineering Block',
    description: 'Electrical Engineering classrooms and department offices.',
    type: LocationType.academicBlock,
    lat: -1.265876,
    lng: 36.727454,
    aliases: [
      'Electrical Engineering Block', 'EE Block', 'Electrical Eng',
      'Electrical Engineering',
    ],
  ),
  const CampusLocation(
    id: 'iahc',
    name: 'IAHC Block',
    description: 'ICT, Accounting, and Humanities classrooms.',
    type: LocationType.academicBlock,
    lat: -1.266459,
    lng: 36.726610,
    aliases: ['IAHC', 'IAHC Block', 'ICT Block', 'Accounting Block'],
  ),
  const CampusLocation(
    id: 'bus_park',
    name: 'Bus Park',
    description: 'Main bus park and transportation hub.',
    type: LocationType.busPark,
    lat: -1.266062,
    lng: 36.726812,
    aliases: ['Bus Park', 'Bus Stop', 'Parking'],
  ),
  const CampusLocation(
    id: 'library',
    name: 'Library',
    description: 'Main campus library with books, journals, and study areas.',
    type: LocationType.library,
    lat: -1.264766,
    lng: 36.727464,
    aliases: ['Library', 'Library Block'],
  ),
  const CampusLocation(
    id: 'ee_workshop',
    name: 'Electrical Engineering Workshop',
    description: 'Hands-on electrical installation and wiring workshop.',
    type: LocationType.workshop,
    lat: -1.264833,
    lng: 36.727978,
    aliases: ['Electrical Workshop', 'EE Workshop', 'Electrical Engineering Workshop'],
  ),
  const CampusLocation(
    id: 'automotive_block',
    name: 'Automotive Engineering Block',
    description: 'Automotive engineering classrooms and workshop.',
    type: LocationType.academicBlock,
    lat: -1.265408,
    lng: 36.728048,
    aliases: ['Automotive Block', 'Automotive Engineering', 'Auto Engineering'],
  ),
  const CampusLocation(
    id: 'med_bay',
    name: 'Med Bay',
    description: 'Campus health center providing first aid and basic medical care.',
    type: LocationType.medBay,
    lat: -1.265014,
    lng: 36.726604,
    aliases: ['Med Bay', 'Medical Bay', 'Health Center', 'Clinic', 'Sick Bay'],
  ),
  const CampusLocation(
    id: 'field_2',
    name: 'Field 2',
    description: 'Multi-purpose sports field.',
    type: LocationType.sportsField,
    lat: -1.266257,
    lng: 36.725407,
    aliases: ['Field 2', 'Sports Field 2'],
  ),
  const CampusLocation(
    id: 'shops',
    name: 'Shops',
    description: 'Ice Pop, PlayStation, Simba Stk — student hangout area.',
    type: LocationType.other,
    lat: -1.265610,
    lng: 36.725572,
    aliases: ['Shops', 'Ice Pop', 'PlayStation', 'Simba Stk', 'Simba Stock'],
  ),
  const CampusLocation(
    id: 'unnamed_facility',
    name: 'Unnamed Facility',
    description: 'Unlabeled facility near the shops area.',
    type: LocationType.other,
    lat: -1.265618,
    lng: 36.725783,
    aliases: [],
  ),
  const CampusLocation(
    id: 'pool_game',
    name: 'Pool Game Entertainment',
    description: 'Pool table and indoor games entertainment area.',
    type: LocationType.other,
    lat: -1.265640,
    lng: 36.725710,
    aliases: ['Pool Game', 'Pool', 'Entertainment', 'Games'],
  ),
  const CampusLocation(
    id: 'field_3',
    name: 'Field 3',
    description: 'Multi-purpose sports field.',
    type: LocationType.sportsField,
    lat: -1.265844,
    lng: 36.724718,
    aliases: ['Field 3', 'Sports Field 3'],
  ),
  const CampusLocation(
    id: 'intl_studies',
    name: 'International Studies Block',
    description: 'International studies classrooms and offices.',
    type: LocationType.academicBlock,
    lat: -1.264402,
    lng: 36.726761,
    aliases: ['International Studies', 'Intl Studies', 'International Studies Block'],
  ),
  const CampusLocation(
    id: 'admin_block',
    name: 'Administration Block',
    description: 'Principal\'s office, Deputy Principal, and main administrative staff.',
    type: LocationType.adminOffice,
    lat: -1.264787,
    lng: 36.727164,
    aliases: ['Admin Block', 'Administration', 'Admin Office'],
  ),
  const CampusLocation(
    id: 'exam_office',
    name: 'Examination Office',
    description: 'Examination administration and records office.',
    type: LocationType.adminOffice,
    lat: -1.264798,
    lng: 36.726838,
    aliases: ['Exam Office', 'Examination Office', 'Exams Office'],
  ),
  const CampusLocation(
    id: 'accounts_office',
    name: 'Accounts Office',
    description: 'Finance and accounts department.',
    type: LocationType.adminOffice,
    lat: -1.264986,
    lng: 36.726750,
    aliases: ['Accounts Office', 'Accounts', 'Finance'],
  ),
  const CampusLocation(
    id: 'deans_office',
    name: 'Dean\'s Office',
    description: 'Dean of Students office.',
    type: LocationType.departmentOffice,
    lat: -1.265586,
    lng: 36.726408,
    aliases: ['Dean\'s Office', 'Dean Office', 'Dean of Students'],
  ),
  const CampusLocation(
    id: 'lecture_theater',
    name: 'Lecture / Theater Room',
    description: 'Large lecture hall and theater-style classroom.',
    type: LocationType.hall,
    lat: -1.265529,
    lng: 36.726789,
    aliases: ['Lecture Theater', 'Lecture Room', 'Theater Room', 'Lecture Hall'],
  ),
  const CampusLocation(
    id: 'main_hall',
    name: 'Main Hall',
    description: 'Multipurpose hall for assemblies, events, and examinations.',
    type: LocationType.hall,
    lat: -1.265487,
    lng: 36.727241,
    aliases: ['Main Hall', 'Assembly Hall', 'Exam Hall', 'Hall'],
  ),
];

final Map<String, String> venueToLocationId = {
  'Electrical Engineering Block': 'ee_block',
  'EE Block': 'ee_block',
  'IAHC': 'iahc',
  'IAHC Block': 'iahc',
  'Library': 'library',
  'Main Hall': 'main_hall',
  'Hall': 'main_hall',
  'West Hall': 'west_hall',
  'East Hall': 'east_hall',
  'Lecture Theater': 'lecture_theater',
  'Lecture / Theater Room': 'lecture_theater',
  'Bus Park': 'bus_park',
  'Electrical Workshop': 'ee_workshop',
  'Electrical Engineering Workshop': 'ee_workshop',
  'Automotive Block': 'automotive_block',
  'Automotive Engineering': 'automotive_block',
  'Med Bay': 'med_bay',
  'Shops': 'shops',
  'Student Kitchen': 'student_kitchen',
  'Kitchen': 'student_kitchen',
  'Field 2': 'field_2',
  'Field 3': 'field_3',
  'Basketball Court': 'basketball_court',
  'Administration Block': 'admin_block',
  'Admin Block': 'admin_block',
  'Examination Office': 'exam_office',
  'Accounts Office': 'accounts_office',
  'International Studies Block': 'intl_studies',
  "Dean's Office": 'deans_office',
  'Pool Game': 'pool_game',
  'Pool Game Entertainment': 'pool_game',
};

final Map<String, String> teacherToOfficeLocationId = {
  'Mr. Kamau': 'ee_block',
  'Ms. Wanjiku': 'ee_block',
  'Dr. Ochieng': 'ee_block',
  'Eng. Mutua': 'ee_workshop',
  'Mr. Kiprop': 'ee_block',
  'Mrs. Akinyi': 'iahc',
  'Mr. Njoroge': 'ee_workshop',
  'Mr. Odhiambo': 'automotive_block',
  'Prof. Wekesa': 'admin_block',
  'Madam Grace': 'intl_studies',
  'Mr. Otieno': 'ee_block',
  'Madam Faith': 'iahc',
  'Mr. Kosgey': 'ee_block',
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
