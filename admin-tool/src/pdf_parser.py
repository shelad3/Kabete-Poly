# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""PDF timetable parser using pdfplumber."""

import re
from typing import Optional

import pdfplumber


class TimetableParseResult:
    """Result of parsing a timetable PDF."""
    def __init__(self):
        self.entries: list[dict] = []
        self.errors: list[str] = []
        self.class_id: str = ''
        self.department: str = ''
        self.semester: str = ''

    @property
    def success_count(self) -> int:
        return len(self.entries)

    @property
    def error_count(self) -> int:
        return len(self.errors)


class PdfTimetableParser:
    """Parse PDF timetable files from Kenyan polytechnic format."""

    DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    DAY_ABBR = {'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
                'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday'}

    def parse(self, file_path: str) -> TimetableParseResult:
        result = TimetableParseResult()
        try:
            with pdfplumber.open(file_path) as pdf:
                for page_num, page in enumerate(pdf.pages, 1):
                    self._parse_page(page, page_num, result)
        except Exception as e:
            result.errors.append(f'Failed to open PDF: {e}')
        return result

    def _parse_page(self, page, page_num: int, result: TimetableParseResult):
        text = page.extract_text() or ''
        tables = page.extract_tables()

        # Try to extract header metadata
        header_info = self._extract_header(text)
        if header_info:
            if not result.class_id and header_info.get('class_id'):
                result.class_id = header_info['class_id']
            if not result.department and header_info.get('department'):
                result.department = header_info['department']
            if not result.semester and header_info.get('semester'):
                result.semester = header_info['semester']

        if tables:
            for table in tables:
                self._parse_table(table, result)
        else:
            # Fallback: try line-by-line parsing
            self._parse_text_lines(text, result)

    def _extract_header(self, text: str) -> dict:
        info = {}
        lines = text.split('\n')[:20]
        for line in lines:
            line_lower = line.lower()
            m = re.search(r'(?:class|cohort|batch|group)\s*[:\-]?\s*(\S+)', line_lower, re.IGNORECASE)
            if m:
                info['class_id'] = m.group(1).upper()
            m = re.search(r'(?:department|dept|faculty)\s*[:\-]?\s*(.+)', line_lower, re.IGNORECASE)
            if m:
                info['department'] = m.group(1).strip()
            m = re.search(r'(?:semester|term|sem)\s*[:\-]?\s*(\d+)', line_lower, re.IGNORECASE)
            if m:
                info['semester'] = f'Semester {m.group(1)}'
        return info

    def _parse_table(self, table: list[list], result: TimetableParseResult):
        if not table or len(table) < 2:
            return
        headers = [str(h).strip().lower() if h else '' for h in table[0]]
        day_col = self._find_column(headers, ['day', 'day of week', 'weekday'])
        time_col = self._find_column(headers, ['time', 'start time', 'start', 'period'])
        end_time_col = self._find_column(headers, ['end time', 'end', 'to'])
        unit_col = self._find_column(headers, ['unit', 'course', 'subject', 'module', 'course code', 'unit code'])
        unit_name_col = self._find_column(headers, ['course name', 'unit name', 'subject name', 'description'])
        venue_col = self._find_column(headers, ['venue', 'room', 'classroom', 'location', 'hall'])
        lecturer_col = self._find_column(headers, ['lecturer', 'teacher', 'instructor', 'staff', 'facilitator'])

        for row in table[1:]:
            if not row or all(cell is None or str(cell).strip() == '' for cell in row):
                continue
            entry = self._build_entry(row, day_col, time_col, end_time_col,
                                      unit_col, unit_name_col, venue_col, lecturer_col)
            if entry:
                result.entries.append(entry)

    def _find_column(self, headers: list[str], candidates: list[str]) -> int:
        for i, h in enumerate(headers):
            for c in candidates:
                if c in h:
                    return i
        return -1

    def _build_entry(self, row: list, day_col: int, time_col: int, end_time_col: int,
                     unit_col: int, unit_name_col: int, venue_col: int, lecturer_col: int) -> dict | None:
        def cell(idx):
            return str(row[idx]).strip() if 0 <= idx < len(row) and row[idx] else ''

        day = self._normalize_day(cell(day_col)) if day_col >= 0 else ''
        time_val = cell(time_col) if time_col >= 0 else ''
        end_time = cell(end_time_col) if end_time_col >= 0 else ''

        # Parse time range from single column if needed
        if time_val and not end_time:
            time_parts = re.split(r'\s*[-–—to]+\s*', time_val)
            if len(time_parts) >= 2:
                time_val = time_parts[0].strip()
                end_time = time_parts[1].strip()

        unit_code = cell(unit_col) if unit_col >= 0 else ''
        unit_name = cell(unit_name_col) if unit_name_col >= 0 else ''
        venue = cell(venue_col) if venue_col >= 0 else ''
        lecturer = cell(lecturer_col) if lecturer_col >= 0 else ''

        if not day and not unit_code:
            return None

        label = f'{unit_code} - {unit_name}' if unit_name else unit_code

        return {
            'day': day,
            'time': self._normalize_time(time_val),
            'endTime': self._normalize_time(end_time),
            'unit': label,
            'venue': venue,
            'lecturer': lecturer,
            'color': 4282339765,  # default blue
        }

    def _parse_text_lines(self, text: str, result: TimetableParseResult):
        """Fallback parser for non-table PDFs — line-by-line heuristic."""
        lines = text.split('\n')
        current_day = ''
        for line in lines:
            line = line.strip()
            if not line:
                continue
            lower = line.lower()
            # Check if line is a day header
            for day in self.DAYS:
                if day.lower() in lower and len(line) < 20:
                    current_day = day
                    break
            # Match timetable lines: time + unit + venue pattern
            m = re.match(
                r'(\d{1,2}[:.]\d{2})\s*[-–—to]+\s*(\d{1,2}[:.]\d{2})\s+(.+?)(?:\s{2,}|\t)(.+?)(?:\s{2,}|\t)(.*)',
                line,
            )
            if m:
                result.entries.append({
                    'day': current_day,
                    'time': self._normalize_time(m.group(1)),
                    'endTime': self._normalize_time(m.group(2)),
                    'unit': m.group(3).strip(),
                    'venue': m.group(4).strip(),
                    'lecturer': m.group(5).strip(),
                    'color': 4282339765,
                })

    def _normalize_day(self, day: str) -> str:
        lower = day.strip().lower()
        if lower in self.DAY_ABBR:
            return self.DAY_ABBR[lower]
        for d in self.DAYS:
            if d.lower() == lower:
                return d
        # Return as-is if not recognized
        return day.strip()

    def _normalize_time(self, t: str) -> str:
        t = t.strip().replace('.', ':')
        if re.match(r'^\d{1,2}:\d{2}$', t):
            if len(t.split(':')[0]) == 1:
                t = '0' + t
            return t
        return t


class PdfExamTimetableParser:
    """Parse exam timetable PDFs — extracts subject, date, time, room, teacher."""

    EXAM_TYPES = ['final', 'midterm', 'cat', 'practical']

    def parse(self, file_path: str) -> TimetableParseResult:
        result = TimetableParseResult()
        try:
            with pdfplumber.open(file_path) as pdf:
                for page_num, page in enumerate(pdf.pages, 1):
                    self._parse_page(page, page_num, result)
        except Exception as e:
            result.errors.append(f'Failed to open exam PDF: {e}')
        return result

    def _parse_page(self, page, page_num: int, result: TimetableParseResult):
        text = page.extract_text() or ''
        tables = page.extract_tables()

        header_info = self._extract_header(text)
        if header_info:
            if not result.class_id and header_info.get('class_id'):
                result.class_id = header_info['class_id']

        if tables:
            for table in tables:
                self._parse_table(table, result)
        else:
            self._parse_text_lines(text, result)

    def _extract_header(self, text: str) -> dict:
        info = {}
        lines = text.split('\n')[:20]
        for line in lines:
            lower = line.lower()
            m = re.search(r'(?:class|cohort|batch|group|programme)\s*[:\-]?\s*(\S+)', lower, re.IGNORECASE)
            if m:
                info['class_id'] = m.group(1).upper()
        return info

    def _parse_table(self, table: list[list], result: TimetableParseResult):
        if not table or len(table) < 2:
            return
        headers = [str(h).strip().lower() if h else '' for h in table[0]]
        subject_col = self._find_column(headers, ['subject', 'course', 'unit', 'course name', 'unit name'])
        date_col = self._find_column(headers, ['date', 'exam date', 'day'])
        start_col = self._find_column(headers, ['start', 'start time', 'time', 'from'])
        end_col = self._find_column(headers, ['end', 'end time', 'to', 'until'])
        room_col = self._find_column(headers, ['room', 'venue', 'hall', 'location'])
        teacher_col = self._find_column(headers, ['teacher', 'lecturer', 'invigilator', 'supervisor'])
        type_col = self._find_column(headers, ['type', 'exam type', 'category'])

        for row in table[1:]:
            if not row or all(cell is None or str(cell).strip() == '' for cell in row):
                continue
            entry = self._build_entry(row, subject_col, date_col, start_col, end_col,
                                      room_col, teacher_col, type_col)
            if entry:
                result.entries.append(entry)

    def _find_column(self, headers: list[str], candidates: list[str]) -> int:
        for i, h in enumerate(headers):
            for c in candidates:
                if c in h:
                    return i
        return -1

    def _build_entry(self, row: list, subject_col: int, date_col: int, start_col: int,
                     end_col: int, room_col: int, teacher_col: int, type_col: int) -> dict | None:
        def cell(idx):
            return str(row[idx]).strip() if 0 <= idx < len(row) and row[idx] else ''

        subject = cell(subject_col) if subject_col >= 0 else ''
        date_val = cell(date_col) if date_col >= 0 else ''
        start_time = cell(start_col) if start_col >= 0 else ''
        end_time = cell(end_col) if end_col >= 0 else ''
        room = cell(room_col) if room_col >= 0 else ''
        teacher = cell(teacher_col) if teacher_col >= 0 else ''
        exam_type = cell(type_col) if type_col >= 0 else 'final'

        # Parse time range
        if start_time and not end_time:
            parts = re.split(r'\s*[-–—to]+\s*', start_time)
            if len(parts) >= 2:
                start_time = parts[0].strip()
                end_time = parts[1].strip()

        if not subject and not date_val:
            return None

        exam_type_lower = exam_type.lower()
        if exam_type_lower not in self.EXAM_TYPES:
            # Try to detect from text
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
            'endTime': self._normalize_time(end_time),
            'room': room,
            'teacher': teacher,
            'type': exam_type_lower,
        }

    def _parse_text_lines(self, text: str, result: TimetableParseResult):
        """Fallback for non-table exam PDFs."""
        lines = text.split('\n')
        current_date = ''
        for line in lines:
            line = line.strip()
            if not line:
                continue
            # Detect date lines like "2026-04-15" or "15/04/2026"
            m = re.match(r'(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})', line)
            if m:
                current_date = m.group(1).replace('/', '-')
                continue
            # Detect exam lines: time + subject + room
            m = re.match(
                r'(\d{1,2}[:.]\d{2})\s*[-–—to]+\s*(\d{1,2}[:.]\d{2})\s+(.+?)(?:\s{2,}|\t)(.+?)(?:\s{2,}|\t)(.*)',
                line,
            )
            if m:
                result.entries.append({
                    'subject': m.group(3).strip(),
                    'date': current_date,
                    'startTime': self._normalize_time(m.group(1)),
                    'endTime': self._normalize_time(m.group(2)),
                    'room': m.group(4).strip(),
                    'teacher': m.group(5).strip(),
                    'type': 'final',
                })

    def _normalize_time(self, t: str) -> str:
        t = t.strip().replace('.', ':')
        if re.match(r'^\d{1,2}:\d{2}$', t):
            if len(t.split(':')[0]) == 1:
                t = '0' + t
            return t
        return t
