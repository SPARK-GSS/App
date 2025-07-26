class Person {
  final String school;
  final String studentId;
  final String contact;
  final List<String> clubs;

  Person({
    required this.school,
    required this.studentId,
    required this.contact,
    required this.clubs,
  });

  // JSON -> 객체
  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      school: json['school'] ?? '',
      studentId: json['studentId'] ?? '',
      contact: json['contact'] ?? '',
      clubs: (json['clubs'] as Map<dynamic, dynamic>?)?.values.map((e) => e.toString()).toList() ?? [],
    );
  }

  static fromMap(Map<dynamic, dynamic> personVal){
    var school = personVal['school'] ?? '';
    var studentId = personVal['studentId'] ?? '';
    var contact = personVal['contact'] ?? '';
    var clubsMap = personVal['clubs'] as Map<dynamic, dynamic>?;

    // Map → List<String>
    List<String> clubs = [];
    if (clubsMap != null) {
      clubs = clubsMap.values.map((e) => e.toString()).toList();
    }

    return Person(school: school, studentId: studentId, contact: contact, clubs: clubs);
  }

  // 객체 -> JSON
  Map<String, dynamic> toMap() {
    final clubsMap = <String, String>{};
    for (int i = 0; i < clubs.length; i++) {
      clubsMap['club${i + 1}'] = clubs[i];
    }

    return {
      'school': school,
      'studentId': studentId,
      'contact': contact,
      'clubs': clubsMap,
    };
  }
}
