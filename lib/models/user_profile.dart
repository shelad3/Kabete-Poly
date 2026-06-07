class UserProfile {
  final String registrationNumber; // Also functions as Staff ID or Teacher TSC
  final String fullName;
  final String profilePhotoUrl;
  final String mobileNumber;
  final String email;
  final bool isHostelResident;
  final String role; // 'Student', 'Leader', 'Teacher', 'Official'
  final String? designation; // e.g. 'Prefect', 'HOD'
  final List<String> enrolledClasses;
  final int classChangeCount;

  UserProfile({
    required this.registrationNumber,
    required this.fullName,
    required this.profilePhotoUrl,
    required this.mobileNumber,
    required this.email,
    required this.isHostelResident,
    this.role = 'Student',
    this.designation,
    this.enrolledClasses = const [],
    this.classChangeCount = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      registrationNumber: json['registrationNumber'] ?? '',
      fullName: json['fullName'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      email: json['email'] ?? '',
      isHostelResident: json['isHostelResident'] ?? false,
      role: json['role'] ?? 'Student',
      designation: json['designation'],
      enrolledClasses: List<String>.from(json['enrolledClasses'] ?? []),
      classChangeCount: json['classChangeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationNumber': registrationNumber,
      'fullName': fullName,
      'profilePhotoUrl': profilePhotoUrl,
      'mobileNumber': mobileNumber,
      'email': email,
      'isHostelResident': isHostelResident,
      'role': role,
      'designation': designation,
      'enrolledClasses': enrolledClasses,
      'classChangeCount': classChangeCount,
    };
  }

  bool get canChangeClass => classChangeCount < 2;
  int get classChangesRemaining => 2 - classChangeCount;

  // Helper getters
  bool get isAdmin => role == 'Official';
  bool get isTeacher => role == 'Teacher' || role == 'Official';
  bool get isLeader => role == 'Leader';
}
