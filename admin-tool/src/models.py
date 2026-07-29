# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

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


# ── Exam Timetable ──────────────────────────────────────────────────

@dataclass
class ExamTimetableEntry:
    """An exam timetable entry for a class."""
    class_id: str
    subject: str
    teacher: str
    room: str
    date: str           # 'YYYY-MM-DD'
    start_time: str     # 'HH:MM'
    end_time: str       # 'HH:MM'
    exam_type: str      # 'midterm', 'final', 'cat', 'practical'
    description: str = ''
    instructions: str = ''
    day_of_week: int = 0
    doc_id: str = ''

    def to_dict(self) -> dict:
        return {
            'classId': self.class_id,
            'subject': self.subject,
            'teacher': self.teacher,
            'room': self.room,
            'date': self.date,
            'startTime': self.start_time,
            'endTime': self.end_time,
            'type': self.exam_type,
            'description': self.description,
            'instructions': self.instructions,
            'dayOfWeek': self.day_of_week,
        }

    @staticmethod
    def from_doc(doc) -> 'ExamTimetableEntry':
        data = doc.to_dict() or {}
        return ExamTimetableEntry(
            doc_id=doc.id,
            class_id=data.get('classId', ''),
            subject=data.get('subject', ''),
            teacher=data.get('teacher', ''),
            room=data.get('room', ''),
            date=str(data.get('date', '')),
            start_time=data.get('startTime', '00:00'),
            end_time=data.get('endTime', '00:00'),
            exam_type=data.get('type', 'final'),
            description=data.get('description', ''),
            instructions=data.get('instructions', ''),
            day_of_week=data.get('dayOfWeek', 0),
        )


# ── Payments ────────────────────────────────────────────────────────

PAYMENT_METHODS = ('mpesa', 'airtel', 'card')
PAYMENT_STATUSES = ('pending', 'processing', 'completed', 'failed', 'refunded')


@dataclass
class Payment:
    """A payment record for a hostel booking."""
    booking_id: str
    student_id: str
    amount: float
    method: str               # mpesa / airtel / card
    status: str               # pending / processing / completed / failed / refunded
    currency: str = 'KES'
    phone_number: str = ''
    checkout_request_id: str = ''
    transaction_ref: str = ''
    failure_reason: str = ''
    initiated_at: Optional[str] = None
    completed_at: Optional[str] = None
    doc_id: str = ''

    def to_dict(self) -> dict:
        d = {
            'bookingId': self.booking_id,
            'studentId': self.student_id,
            'amount': self.amount,
            'method': self.method,
            'status': self.status,
            'currency': self.currency,
            'phoneNumber': self.phone_number,
            'checkoutRequestId': self.checkout_request_id,
            'transactionRef': self.transaction_ref,
            'failureReason': self.failure_reason,
        }
        return d

    @staticmethod
    def from_doc(doc) -> 'Payment':
        data = doc.to_dict() or {}
        return Payment(
            doc_id=doc.id,
            booking_id=data.get('bookingId', ''),
            student_id=data.get('studentId', ''),
            amount=float(data.get('amount', 0)),
            method=data.get('method', 'mpesa'),
            status=data.get('status', 'pending'),
            currency=data.get('currency', 'KES'),
            phone_number=data.get('phoneNumber', ''),
            checkout_request_id=data.get('checkoutRequestId', ''),
            transaction_ref=data.get('transactionRef', ''),
            failure_reason=data.get('failureReason', ''),
            initiated_at=str(data.get('initiatedAt', '')) if data.get('initiatedAt') else None,
            completed_at=str(data.get('completedAt', '')) if data.get('completedAt') else None,
        )

    @property
    def method_label(self) -> str:
        return {'mpesa': 'M-Pesa', 'airtel': 'Airtel Money', 'card': 'Card'}.get(self.method, self.method)

    @property
    def status_label(self) -> str:
        return self.status.capitalize()

    @property
    def status_color(self) -> str:
        colors = {
            'completed': '#4CAF50',
            'processing': '#FF9800',
            'pending': '#9E9E9E',
            'failed': '#F44336',
            'refunded': '#2196F3',
        }
        return colors.get(self.status, '#9E9E9E')


# ── Feature Flags ───────────────────────────────────────────────────

DEFAULT_FEATURE_FLAGS = {
    'hostel_booking': 'Hostel Booking',
    'quizzes': 'Quizzes',
    'forum': 'Discussion Forum',
    'report_cards': 'Report Cards',
    'grades': 'Grades',
    'timetable': 'Timetable',
    'notifications': 'Notifications',
    'gallery': 'Gallery',
    'campus_map': 'Campus Map',
    'lesson_verification': 'Lesson Verification',
    'exam_booking': 'Exam Booking',
    'voting': 'Student Leader Voting',
}


@dataclass
class FeatureFlag:
    """A feature toggle with optional schedule."""
    name: str
    display_name: str
    enabled: bool = True
    description: str = ''
    auto_disable_at: Optional[str] = None
    auto_enable_at: Optional[str] = None
    disabled_message: str = 'This feature is currently unavailable.'
    allowed_roles: list = field(default_factory=list)
    doc_id: str = ''

    def to_dict(self) -> dict:
        schedule = {}
        if self.auto_disable_at:
            schedule['autoDisableAt'] = self.auto_disable_at
        if self.auto_enable_at:
            schedule['autoEnableAt'] = self.auto_enable_at
        d = {
            'name': self.name,
            'displayName': self.display_name,
            'enabled': self.enabled,
            'description': self.description,
            'disabledMessage': self.disabled_message,
            'allowedRoles': self.allowed_roles,
        }
        if schedule:
            d['schedule'] = schedule
        return d

    @staticmethod
    def from_doc(doc) -> 'FeatureFlag':
        data = doc.to_dict() or {}
        schedule = data.get('schedule') or {}
        return FeatureFlag(
            doc_id=doc.id,
            name=data.get('name', ''),
            display_name=data.get('displayName', ''),
            enabled=bool(data.get('enabled', True)),
            description=data.get('description', ''),
            auto_disable_at=schedule.get('autoDisableAt'),
            auto_enable_at=schedule.get('autoEnableAt'),
            disabled_message=data.get('disabledMessage', 'This feature is currently unavailable.'),
            allowed_roles=list(data.get('allowedRoles', [])),
        )
