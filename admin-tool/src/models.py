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
    cat1Score: float = 0.0
    cat1Max: float = 30.0
    cat2Score: float = 0.0
    cat2Max: float = 30.0
    examScore: float = 0.0
    examMax: float = 40.0
    teacherId: str = ''
    teacherName: str = ''
    comments: str = ''
    doc_id: str = ''

    @property
    def total_score(self) -> float:
        return self.cat1Score + self.cat2Score + self.examScore

    @property
    def total_max(self) -> float:
        return self.cat1Max + self.cat2Max + self.examMax

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
        return GradeRecord(
            doc_id=doc.id,
            studentId=data.get('studentId', ''),
            studentName=data.get('studentName', ''),
            regNo=data.get('regNo', ''),
            subjectName=data.get('subjectName', ''),
            classId=data.get('classId', ''),
            term=data.get('term', ''),
            academicYear=data.get('academicYear', ''),
            cat1Score=float(data.get('cat1Score', 0)),
            cat1Max=float(data.get('cat1Max', 30)),
            cat2Score=float(data.get('cat2Score', 0)),
            cat2Max=float(data.get('cat2Max', 30)),
            examScore=float(data.get('examScore', 0)),
            examMax=float(data.get('examMax', 40)),
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
