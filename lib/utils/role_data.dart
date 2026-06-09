class RoleData {
  RoleData._();

  static const List<DropdownSection> teacherDepartments = [
    DropdownSection('Engineering', [
      'Electrical and Electronics Engineering',
      'Mechanical Engineering',
      'Civil and Structural Engineering',
      'Building and Construction Technology',
    ]),
    DropdownSection('ICT & Computing', [
      'Information Communication Technology',
      'Computer Science',
      'Software Engineering',
      'Computer Networks and Administration',
    ]),
    DropdownSection('Business & Management', [
      'Business Management',
      'Accounting and Finance',
      'Human Resource Management',
      'Supply Chain Management',
      'Entrepreneurship',
    ]),
    DropdownSection('Applied Sciences', [
      'Medical Laboratory Sciences',
      'Pharmacy',
      'Nutrition and Dietetics',
      'Environmental Health',
      'Community Health',
    ]),
    DropdownSection('Hospitality & Tourism', [
      'Hotel and Hospitality Management',
      'Tourism and Travel Management',
      'Food and Beverage Production',
    ]),
    DropdownSection('Creative & Applied Arts', [
      'Fashion Design and Garment Making',
      'Graphic Design and Multimedia',
      'Film and Video Production',
      'Journalism and Mass Communication',
    ]),
    DropdownSection('Agriculture', [
      'General Agriculture',
      'Agribusiness Management',
      'Animal Health and Production',
      'Food Science and Technology',
    ]),
    DropdownSection('Education & Social Sciences', [
      'Early Childhood Education',
      'Special Needs Education',
      'Social Work and Community Development',
      'Criminology and Security Studies',
      'Library and Information Science',
    ]),
  ];

  static const List<DropdownSection> leaderPositions = [
    DropdownSection('Student Council', [
      'Student Council President',
      'Student Council Vice President',
      'Secretary General',
      'Finance Secretary',
      'Academic Secretary',
      'Entertainment Secretary',
      'Health and Environment Secretary',
      'Sports and Culture Secretary',
    ]),
    DropdownSection('Departmental Leadership', [
      'Departmental Student Chairperson',
      'Departmental Vice Chairperson',
      'Departmental Secretary',
      'Departmental Treasurer',
      'Departmental Academic Representative',
    ]),
    DropdownSection('Class Leadership', [
      'Class Representative',
      'Assistant Class Representative',
      'Academic Representative',
    ]),
    DropdownSection('Residence Leadership', [
      'Hall Captain',
      'Assistant Hall Captain',
      'Hostel Representative',
    ]),
  ];

  static const List<DropdownSection> officialOffices = [
    DropdownSection('Executive Management', [
      'Principal',
      'Deputy Principal — Academics',
      'Deputy Principal — Administration',
      'Deputy Principal — Student Affairs',
    ]),
    DropdownSection('Academic Management', [
      'Registrar',
      'Dean of Students',
      'Dean — School of Engineering',
      'Dean — School of Business',
      'Dean — School of ICT',
      'Dean — School of Applied Sciences',
      'Examinations Officer',
      'Quality Assurance Officer',
    ]),
    DropdownSection('Departmental Heads', [
      'HOD — Electrical and Electronics Engineering',
      'HOD — Mechanical Engineering',
      'HOD — Civil Engineering',
      'HOD — ICT',
      'HOD — Business Studies',
      'HOD — Applied Sciences',
      'HOD — Hospitality and Tourism',
      'HOD — Agriculture',
      'HOD — Liberal Studies',
    ]),
    DropdownSection('Administrative Staff', [
      'Bursar',
      'ICT Officer',
      'Librarian',
      'Sports Officer',
      'Guidance and Counselor',
      'Procurement Officer',
      'Human Resources Officer',
      'Public Relations Officer',
    ]),
    DropdownSection('Technical Staff', [
      'Senior Lecturer',
      'Lecturer',
      'Lab Technician',
      'Workshop Technician',
      'Research Assistant',
    ]),
  ];

  static List<String> allTeacherDepartments() {
    final list = <String>[];
    for (final section in teacherDepartments) {
      for (final item in section.items) {
        list.add(item);
      }
    }
    return list;
  }

  static List<String> allLeaderPositions() {
    final list = <String>[];
    for (final section in leaderPositions) {
      for (final item in section.items) {
        list.add(item);
      }
    }
    return list;
  }

  static List<String> allOfficialOffices() {
    final list = <String>[];
    for (final section in officialOffices) {
      for (final item in section.items) {
        list.add(item);
      }
    }
    return list;
  }

  static List<String> forRole(String role) {
    switch (role) {
      case 'Teacher':
        return allTeacherDepartments();
      case 'Leader':
        return allLeaderPositions();
      case 'Official':
        return allOfficialOffices();
      default:
        return [];
    }
  }

  static List<DropdownSection> sectionsForRole(String role) {
    switch (role) {
      case 'Teacher':
        return teacherDepartments;
      case 'Leader':
        return leaderPositions;
      case 'Official':
        return officialOffices;
      default:
        return [];
    }
  }
}

class DropdownSection {
  final String title;
  final List<String> items;
  const DropdownSection(this.title, this.items);
}
