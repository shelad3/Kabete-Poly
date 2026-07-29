# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Enhanced CSV timetable parser with column mapping."""

import csv
import re
from typing import Optional


CsvEntry = dict


class CsvParseResult:
    def __init__(self):
        self.entries: list[CsvEntry] = []
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.headers: list[str] = []
        self.detected_mapping: dict[str, str] = {}
        self.class_id: str = ''
        self.detected_mode: str = 'class'  # 'class' or 'exam'

    @property
    def success_count(self) -> int:
        return len(self.entries)

    @property
    def error_count(self) -> int:
        return len(self.errors)


# Column name → standard field mapping for CLASS timetable
CLASS_COLUMN_ALIASES = {
    'day': ['day', 'day of week', 'weekday', 'dayofweek'],
    'time': ['time', 'start time', 'start', 'starttime', 'from', 'period'],
    'end_time': ['end time', 'end', 'endtime', 'to', 'until'],
    'unit': ['unit', 'course', 'subject', 'module', 'unit code', 'unitcode',
             'course code', 'coursecode', 'subject code', 'subjectcode',
             'code', 'course name'],
    'venue': ['venue', 'room', 'classroom', 'location', 'hall', 'place'],
    'lecturer': ['lecturer', 'teacher', 'instructor', 'staff', 'facilitator',
                 'lecturer name', 'teacher name'],
    'class_id': ['class', 'class id', 'classid', 'cohort', 'batch', 'group',
                 'programme', 'program'],
    'department': ['department', 'dept', 'faculty', 'school'],
    'semester': ['semester', 'sem', 'term', 'academic year', 'year'],
    'week_range': ['week range', 'weekrange', 'weeks', 'week'],
}

# Column name → standard field mapping for EXAM timetable
EXAM_COLUMN_ALIASES = {
    'subject': ['subject', 'course', 'unit', 'course name', 'unit name', 'exam', 'module'],
    'date': ['date', 'exam date', 'day', 'day of exam'],
    'start_time': ['start time', 'start', 'time', 'from', 'starttime'],
    'end_time': ['end time', 'end', 'to', 'endtime', 'until'],
    'room': ['room', 'venue', 'hall', 'location', 'classroom'],
    'teacher': ['teacher', 'lecturer', 'invigilator', 'supervisor', 'examiner'],
    'exam_type': ['type', 'exam type', 'category', 'exam category'],
    'class_id': ['class', 'class id', 'classid', 'cohort', 'batch', 'group',
                 'programme', 'program'],
}


class CsvTimetableParser:
    def __init__(self):
        self._column_mapping: dict[str, str] = {}

    def parse(self, file_path: str, column_mapping: Optional[dict[str, str]] = None) -> CsvParseResult:
        result = CsvParseResult()
        self._column_mapping = column_mapping or {}

        try:
            with open(file_path, 'r', encoding='utf-8-sig') as f:
                reader = csv.reader(f)
                rows = list(reader)
        except Exception as e:
            result.errors.append(f'Failed to read CSV: {e}')
            return result

        if not rows:
            result.errors.append('CSV file is empty.')
            return result

        result.headers = rows[0]

        if not self._column_mapping:
            self._column_mapping = self._auto_detect_mapping(result.headers)
            result.detected_mapping = self._column_mapping

        # Check required columns
        has_day = 'day' in self._column_mapping.values()
        has_time = 'time' in self._column_mapping.values()
        has_unit = 'unit' in self._column_mapping.values()

        if not (has_day and has_time and has_unit):
            missing = []
            if not has_day:
                missing.append('day')
            if not has_time:
                missing.append('time')
            if not has_unit:
                missing.append('unit')
            result.errors.append(f'Missing required columns: {", ".join(missing)}. Use column mapping editor.')
            return result

        # Map header indices
        col_index: dict[str, int] = {}
        for csv_col, std_field in self._column_mapping.items():
            try:
                col_index[std_field] = result.headers.index(csv_col)
            except ValueError:
                result.warnings.append(f'Mapped column "{csv_col}" not found in header row.')

        for row_idx, row in enumerate(rows[1:], 2):
            if not row or all(cell.strip() == '' for cell in row):
                continue
            entry = self._build_entry(row, col_index)
            if entry:
                result.entries.append(entry)
            else:
                result.warnings.append(f'Row {row_idx}: could not parse (skipped)')

        return result

    def _auto_detect_mapping(self, headers: list[str]) -> dict[str, str]:
        mapping = {}
        for header in headers:
            header_lower = header.strip().lower()
            for std_field, aliases in CLASS_COLUMN_ALIASES.items():
                if header_lower in aliases:
                    mapping[header] = std_field
                    break
            else:
                # Try partial match
                for std_field, aliases in CLASS_COLUMN_ALIASES.items():
                    if any(a in header_lower for a in aliases):
                        mapping[header] = std_field
                        break
        return mapping

    def _build_entry(self, row: list[str], col_index: dict[str, int]) -> Optional[CsvEntry]:
        def cell(field: str) -> str:
            idx = col_index.get(field)
            if idx is not None and 0 <= idx < len(row):
                return row[idx].strip()
            return ''

        day = cell('day')
        time_val = cell('time')
        end_time = cell('end_time')
        unit = cell('unit')
        venue = cell('venue')
        lecturer = cell('lecturer')

        # Parse time range from single column
        if time_val and not end_time:
            parts = re.split(r'\s*[-–—to]+\s*', time_val)
            if len(parts) >= 2:
                time_val = parts[0].strip()
                end_time = parts[1].strip()

        if not day and not unit:
            return None

        return {
            'day': day,
            'time': self._normalize_time(time_val),
            'endTime': self._normalize_time(end_time) if end_time else '',
            'unit': unit,
            'venue': venue,
            'lecturer': lecturer,
            'color': 4282339765,
        }

    @staticmethod
    def _normalize_time(t: str) -> str:
        t = t.strip().replace('.', ':')
        if re.match(r'^\d{1,2}:\d{2}$', t):
            if len(t.split(':')[0]) == 1:
                t = '0' + t
            return t
        return t


class CsvExamTimetableParser:
    """Parse exam timetable CSV files with column mapping."""

    EXAM_TYPES = ['final', 'midterm', 'cat', 'practical']

    def __init__(self):
        self._column_mapping: dict[str, str] = {}

    def parse(self, file_path: str, column_mapping: Optional[dict[str, str]] = None) -> CsvParseResult:
        result = CsvParseResult()
        result.detected_mode = 'exam'
        self._column_mapping = column_mapping or {}

        try:
            with open(file_path, 'r', encoding='utf-8-sig') as f:
                reader = csv.reader(f)
                rows = list(reader)
        except Exception as e:
            result.errors.append(f'Failed to read CSV: {e}')
            return result

        if not rows:
            result.errors.append('CSV file is empty.')
            return result

        result.headers = rows[0]

        if not self._column_mapping:
            self._column_mapping = self._auto_detect_mapping(result.headers)
            result.detected_mapping = self._column_mapping

        # Check required columns
        has_subject = 'subject' in self._column_mapping.values()
        has_date = 'date' in self._column_mapping.values()
        has_start = 'start_time' in self._column_mapping.values()

        if not (has_subject and has_date):
            missing = []
            if not has_subject:
                missing.append('subject')
            if not has_date:
                missing.append('date')
            result.errors.append(f'Missing required exam columns: {", ".join(missing)}.')
            return result

        # Map header indices
        col_index: dict[str, int] = {}
        for csv_col, std_field in self._column_mapping.items():
            try:
                col_index[std_field] = result.headers.index(csv_col)
            except ValueError:
                result.warnings.append(f'Mapped column "{csv_col}" not found in header row.')

        for row_idx, row in enumerate(rows[1:], 2):
            if not row or all(cell.strip() == '' for cell in row):
                continue
            entry = self._build_entry(row, col_index)
            if entry:
                result.entries.append(entry)
            else:
                result.warnings.append(f'Row {row_idx}: could not parse (skipped)')

        return result

    def _auto_detect_mapping(self, headers: list[str]) -> dict[str, str]:
        mapping = {}
        for header in headers:
            header_lower = header.strip().lower()
            for std_field, aliases in EXAM_COLUMN_ALIASES.items():
                if header_lower in aliases:
                    mapping[header] = std_field
                    break
            else:
                for std_field, aliases in EXAM_COLUMN_ALIASES.items():
                    if any(a in header_lower for a in aliases):
                        mapping[header] = std_field
                        break
        return mapping

    def _build_entry(self, row: list[str], col_index: dict[str, int]) -> Optional[CsvEntry]:
        def cell(field: str) -> str:
            idx = col_index.get(field)
            if idx is not None and 0 <= idx < len(row):
                return row[idx].strip()
            return ''

        subject = cell('subject')
        date_val = cell('date')
        start_time = cell('start_time')
        end_time = cell('end_time')
        room = cell('room')
        teacher = cell('teacher')
        exam_type = cell('exam_type')

        if start_time and not end_time:
            parts = re.split(r'\s*[-–—to]+\s*', start_time)
            if len(parts) >= 2:
                start_time = parts[0].strip()
                end_time = parts[1].strip()

        if not subject and not date_val:
            return None

        exam_type_lower = exam_type.lower()
        if exam_type_lower not in self.EXAM_TYPES:
            for t in self.EXAM_TYPES:
                if t in exam_type_lower:
                    exam_type_lower = t
                    break
            else:
                exam_type_lower = 'final'

        return {
            'subject': subject,
            'date': date_val,
            'startTime': self._normalize_time(start_time),
            'endTime': self._normalize_time(end_time) if end_time else '',
            'room': room,
            'teacher': teacher,
            'type': exam_type_lower,
        }

    @staticmethod
    def _normalize_time(t: str) -> str:
        t = t.strip().replace('.', ':')
        if re.match(r'^\d{1,2}:\d{2}$', t):
            if len(t.split(':')[0]) == 1:
                t = '0' + t
            return t
        return t
