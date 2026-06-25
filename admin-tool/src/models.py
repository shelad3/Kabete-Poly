from dataclasses import dataclass, field, asdict
from typing import Optional


@dataclass
class GradeRecord:
    studentId: str
    studentName: str
    regNo: str
    subjectName: str
    classId: str
    term: str
    academicYear: str
    assessments: dict = field(default_factory=lambda: {'cat1': {'score': 0, 'max': 30}, 'cat2': {'score': 0, 'max': 30}, 'exam': {'score': 0, 'max': 100}})
    teacherId: str = ''
    teacherName: str = ''
    comments: str = ''
    doc_id: str = ''

    @property
    def cat1Score(self) -> float:
        return float(self.assessments.get('cat1', {}).get('score', 0))

    @property
    def cat1Max(self) -> float:
        return float(self.assessments.get('cat1', {}).get('max', 30))

    @property
    def cat2Score(self) -> float:
        return float(self.assessments.get('cat2', {}).get('score', 0))

    @property
    def cat2Max(self) -> float:
        return float(self.assessments.get('cat2', {}).get('max', 30))

    @property
    def examScore(self) -> float:
        return float(self.assessments.get('exam', {}).get('score', 0))

    @property
    def examMax(self) -> float:
        return float(self.assessments.get('exam', {}).get('max', 100))

    def get_score(self, name: str) -> float:
        return float(self.assessments.get(name, {}).get('score', 0))

    def get_max(self, name: str) -> float:
        return float(self.assessments.get(name, {}).get('max', 0))

    @property
    def total_score(self) -> float:
        return sum(a.get('score', 0) for a in self.assessments.values())

    @property
    def total_max(self) -> float:
        return sum(a.get('max', 0) for a in self.assessments.values())

    @property
    def percentage(self) -> float:
        if self.total_max == 0:
            return 0.0
        return (self.total_score / self.total_max) * 100

    @property
    def letter_grade(self) -> str:
        pct = self.percentage
        if pct >= 80:
            return 'A'
        elif pct >= 70:
            return 'B'
        elif pct >= 60:
            return 'C'
        elif pct >= 50:
            return 'D'
        return 'E'

    def to_dict(self) -> dict:
        d = asdict(self)
        d.pop('doc_id')
        return d

    @staticmethod
    def from_doc(doc) -> 'GradeRecord':
        data = doc.to_dict()
        assessments = data.get('assessments', {})
        if not assessments:
            # backward compat
            assessments = {}
            if float(data.get('cat1Score', 0)) > 0 or float(data.get('cat1Max', 30)) != 30:
                assessments['cat1'] = {'score': float(data.get('cat1Score', 0)), 'max': float(data.get('cat1Max', 30))}
            if float(data.get('cat2Score', 0)) > 0 or float(data.get('cat2Max', 30)) != 30:
                assessments['cat2'] = {'score': float(data.get('cat2Score', 0)), 'max': float(data.get('cat2Max', 30))}
            if float(data.get('examScore', 0)) > 0 or float(data.get('examMax', 40)) != 40:
                assessments['exam'] = {'score': float(data.get('examScore', 0)), 'max': float(data.get('examMax', 100))}
            if not assessments:
                assessments = {'cat1': {'score': 0, 'max': 30}, 'cat2': {'score': 0, 'max': 30}, 'exam': {'score': 0, 'max': 100}}

        return GradeRecord(
            doc_id=doc.id,
            studentId=data.get('studentId', ''),
            studentName=data.get('studentName', ''),
            regNo=data.get('regNo', ''),
            subjectName=data.get('subjectName', ''),
            classId=data.get('classId', ''),
            term=data.get('term', ''),
            academicYear=data.get('academicYear', ''),
            assessments=assessments,
            teacherId=data.get('teacherId', ''),
            teacherName=data.get('teacherName', ''),
            comments=data.get('comments', ''),
        )


@dataclass
class TimetableEntry:
    day: str
    time: str
    unit: str
    room: str
    lecturer: str
    color: int = 0xFF1A237E
    doc_id: str = ''

    def to_dict(self) -> dict:
        d = {
            'day': self.day,
            'time': self.time,
            'unit': self.unit,
            'room': self.room,
            'lecturer': self.lecturer,
            'color': self.color,
        }
        return d

    @staticmethod
    def from_doc(doc) -> 'TimetableEntry':
        data = doc.to_dict()
        return TimetableEntry(
            doc_id=doc.id,
            day=data.get('day', ''),
            time=data.get('time', ''),
            unit=data.get('unit', ''),
            room=data.get('room', ''),
            lecturer=data.get('lecturer', ''),
            color=data.get('color', 0xFF1A237E),
        )


@dataclass
class UserProfile:
    uid: str
    name: str
    regNo: str
    role: str
    enrolled_classes: list = field(default_factory=list)

    @staticmethod
    def from_doc(doc) -> 'UserProfile':
        data = doc.to_dict() or {}
        return UserProfile(
            uid=doc.id,
            name=data.get('name', ''),
            regNo=data.get('registrationNumber', data.get('regNo', '')),
            role=data.get('role', ''),
            enrolled_classes=data.get('enrolledClasses', []),
        )
