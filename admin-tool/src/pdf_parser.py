# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""PDF timetable parser using pdfplumber — handles KNP master-grid format."""

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
        self.cohorts: list[str] = []

    @property
    def success_count(self) -> int:
        return len(self.entries)

    @property
    def error_count(self) -> int:
        return len(self.errors)


# Known lecturer names to help split venue/subject/lecturer from messy cells.
_LECTURER_HINTS = [
    'mr.', 'mrs.', 'ms.', 'dr.', 'prof.', 'tr.', 'trainer',
    'samuel', 'david', 'eva', 'sheila', 'ochieng', 'njuguna',
    'vincent', 'wasonga', 'bornface', 'musyoka', 'felix', 'otieno',
    'jack', 'mwatika', 'israel', 'nyakundi', 'janet', 'anyango',
    'monday', 'wakyendo', 'lydia', 'morris', 'kimani', 'petronillah',
    'miyogo', 'vivia', 'kemboi', 'festus', 'mutinda', 'justus',
    'musasia', 'kennedy', 'muguro', 'ruth', 'kariuki', 'agnes',
    'kirui', 'amos', 'sielei', 'moses', 'kenny', 'namasaka',
    'charles', 'yegon', 'deborah', 'kwamboka', 'benjamin', 'ouko',
    'eric', 'mawira', 'godfrey', 'kariuki', 'odhiambo', 'victor',
    'obora', 'jerono', 'kairu', 'daniel', 'joyce', 'wambui',
]


class PdfTimetableParser:
    """Parse KNP master-grid timetable PDFs.

    The PDF has a consistent structure across all pages:
      Row 0: 'KNPMASTER' header
      Row 1: Day headers (Monday..Friday, each spanning 5 cols)
      Row 2: Time slot headers (number + start/end time, repeated per day)
      Rows 3+: One row per cohort. Col 0 = class ID, cols 1-25 = cells.

    Each cell contains: VENUE\\nSubject\\nLecturer (or empty).
    """

    DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    DAY_ABBR = {'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
                'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday'}

    # Time slots in order (slot number -> (start, end))
    TIME_SLOTS = {
        1: ('07:00', '09:00'),
        2: ('09:00', '11:00'),
        3: ('11:00', '13:00'),
        4: ('13:00', '15:00'),
        5: ('15:00', '17:00'),
    }

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
        tables = page.extract_tables()
        if not tables:
            return

        for table in tables:
            if not table or len(table) < 4:
                continue

            # Verify this is the master grid: row 0 should contain 'KNPMASTER'
            row0_text = ' '.join(str(c) for c in table[0] if c)
            if 'KNPMASTER' not in row0_text.upper():
                continue

            # Extract time slots from row 2
            time_slots = self._extract_time_slots(table[2])
            if not time_slots:
                result.errors.append(f'Page {page_num}: could not parse time slots')
                continue

            # Parse cohort rows (rows 3+)
            for row_idx in range(3, len(table)):
                row = table[row_idx]
                if not row:
                    continue
                class_id = str(row[0]).strip() if row[0] else ''
                if not class_id:
                    continue

                if class_id not in result.cohorts:
                    result.cohorts.append(class_id)

                # Parse each timeslot cell (cols 1-25)
                for col_idx in range(1, min(26, len(row))):
                    cell_text = str(row[col_idx]).strip() if row[col_idx] else ''
                    if not cell_text:
                        continue

                    slot_num = self._col_to_slot(col_idx)
                    if slot_num is None or slot_num not in time_slots:
                        continue

                    day, start_time, end_time = time_slots[slot_num]
                    venue, subject, lecturer = self._parse_cell(cell_text)

                    if not subject and not venue:
                        continue

                    result.entries.append({
                        'class_id': class_id,
                        'day': day,
                        'time': start_time,
                        'endTime': end_time,
                        'unit': self._fix_text(subject),
                        'venue': self._fix_text(venue),
                        'lecturer': self._clean_lecturer(lecturer),
                        'color': 4282339765,
                    })

    def _extract_time_slots(self, row: list) -> dict[int, tuple[str, str, str]]:
        """Parse time slot header row into {col_index: (day, start, end)}.

        Row 2 looks like:
          [None, '1\\n07:00\\n09:00AM', '2\\n09:00\\n11:00AM', ..., '5\\n03:00\\n05:00PM',
           '1\\n07:00\\n09:00AM', ...]  (repeated 5 times for 5 days)

        Returns mapping of column index -> (day_name, start_time, end_time).
        """
        if not row:
            return {}

        # First figure out the day mapping from row 1
        # But we can also just use the column position:
        # cols 1-5 = Monday, 6-10 = Tuesday, 11-15 = Wednesday, 16-20 = Thursday, 21-25 = Friday
        days_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']

        slots = {}
        slot_re = re.compile(r'(\d)\s*\n\s*(\d{1,2}):(\d{2})\s*\n\s*(\d{1,2}):(\d{2})\s*(AM|PM)?', re.IGNORECASE)

        for col_idx in range(1, min(26, len(row))):
            cell = str(row[col_idx]) if row[col_idx] else ''
            m = slot_re.search(cell)
            if m:
                slot_num = int(m.group(1))
                start_h = int(m.group(2))
                start_m = int(m.group(3))
                end_h = int(m.group(4))
                end_m = int(m.group(5))
                ampm = (m.group(6) or '').upper()

                # Convert to 24h if AM/PM present
                if ampm == 'PM' and start_h < 12:
                    start_h += 12
                if ampm == 'PM' and end_h < 12:
                    end_h += 12

                start = f'{start_h:02d}:{start_m:02d}'
                end = f'{end_h:02d}:{end_m:02d}'

                # Determine day from column position
                day_idx = (col_idx - 1) // 5
                if day_idx < len(days_order):
                    day = days_order[day_idx]
                else:
                    day = ''

                slots[col_idx] = (day, start, end)

        return slots

    def _col_to_slot(self, col_idx: int) -> int | None:
        """Map column index (1-25) to slot number (1-5) within the day."""
        if col_idx < 1 or col_idx > 25:
            return None
        return ((col_idx - 1) % 5) + 1

    def _parse_cell(self, text: str) -> tuple[str, str, str]:
        """Parse a cell's text into (venue, subject, lecturer).

        Typical cell format:
          VENUE_CODE\\nSubject Name\\nLECTURER NAME
        or:
          VENUE_NAME\\nSubject Name\\nLECTURER NAME

        Some cells have messy line breaks or extra info. We use heuristics.
        """
        # Clean up known pdfplumber artifacts
        text = text.replace('\\n', '\n')
        lines = [l.strip() for l in text.split('\n') if l.strip()]

        if not lines:
            return '', '', ''

        # Known venue patterns
        venue_patterns = [
            r'^E-\d[A-Z]?$',           # E-1E, E-2A, E-IB, etc.
            r'^C\d+-\w+$',             # C12-G, C12-F
            r'^ROOM\s',                # ROOM 201
            r'LAB$',
            r'LAB\s*\(',
            r'WORKSHOP',
            r'WORKSOP',
            r'POWERLINES',
            r'COMP\s',
            r'TELECOM\s',
            r'SOLAR\s',
            r'ROBOTICS\s',
            r'BLOCK\)',
            r'\(OUTSIDE',
            r'\(WRK',
            r'SETUP\)',
            r'ELECTRICAL WORKSHOP',
            r'ELECTRONICS LAB',
            r'ELECTRICAL AND',
        ]

        venue = ''
        subject_lines = []
        lecturer = ''

        for i, line in enumerate(lines):
            if self._is_venue(line, venue_patterns):
                venue = line
            elif self._is_lecturer(line):
                lecturer = self._clean_lecturer(line)
            else:
                subject_lines.append(line)

        # If we couldn't identify parts, use position heuristics
        if not venue and not lecturer and len(lines) >= 2:
            # First line is often venue
            if self._looks_like_venue(lines[0]):
                venue = lines[0]
                subject_lines = lines[1:]
            else:
                subject_lines = lines

        # Clean lecturer if it got mixed with subject
        if lecturer and subject_lines:
            # Remove lecturer name fragments from subject
            cleaned = []
            for sl in subject_lines:
                if not any(hint in sl.lower() for hint in _LECTURER_HINTS):
                    cleaned.append(sl)
            if cleaned:
                subject_lines = cleaned

        subject = ' '.join(subject_lines).strip()

        # Clean up common artifacts in subject
        subject = re.sub(r'\s+', ' ', subject)
        subject = subject.strip('- ')

        return venue, subject, self._clean_lecturer(lecturer)

    def _is_venue(self, line: str, patterns: list[str]) -> bool:
        upper = line.upper()
        for p in patterns:
            if re.search(p, upper):
                return True
        return False

    def _looks_like_venue(self, line: str) -> bool:
        return self._is_venue(line, [
            r'^E-\d', r'^C\d+', r'LAB', r'WORKSHOP', r'WORKSOP',
            r'POWERLINES', r'COMP', r'TELECOM', r'SOLAR', r'ROBOTICS',
            r'BLOCK', r'OUTSIDE', r'SETUP', r'ELECTRICAL',
        ])

    def _is_lecturer(self, line: str) -> bool:
        lower = line.lower().strip()
        for hint in _LECTURER_HINTS:
            if hint in lower:
                return True
        # All-caps name pattern (e.g. "SAMUEL NJUGUNA")
        if re.match(r'^[A-Z][A-Z\s.]+$', line.strip()) and len(line.strip()) > 3:
            return True
        return False

    def _clean_lecturer(self, name: str) -> str:
        name = name.strip()
        # Remove artifacts like "(wrk shop)" etc.
        name = re.sub(r'\(.*?\)', '', name).strip()
        # Title case for display
        parts = name.split()
        if parts and all(p.isupper() or p[0].isupper() for p in parts):
            return ' '.join(p.capitalize() if p.isupper() else p for p in parts)
        return name

    def _normalize_day(self, day: str) -> str:
        lower = day.strip().lower()
        if lower in self.DAY_ABBR:
            return self.DAY_ABBR[lower]
        for d in self.DAYS:
            if d.lower() == lower:
                return d
        return day.strip()

    def _normalize_time(self, t: str) -> str:
        t = t.strip().replace('.', ':')
        if re.match(r'^\d{1,2}:\d{2}$', t):
            if len(t.split(':')[0]) == 1:
                t = '0' + t
            return t
        return t

    def _fix_text(self, text: str) -> str:
        """Fix common PDF word-break artifacts and normalize whitespace."""
        if not text:
            return text
        fixes = [
            ('Microproc essor', 'Microprocessor'),
            ('Microproce ssor', 'Microprocessor'),
            ('Technolog y', 'Technology'),
            ('managem ent', 'management'),
            ('Mathem atics', 'Mathematics'),
            ('Engineerin g', 'Engineering'),
            ('Cont rol', 'Control'),
            ('Measurem ent', 'Measurement'),
            ('automatiom', 'automation'),
            ('automatio n', 'automation'),
            ('Maintenan ce', 'Maintenance'),
            ('Maintenan\nce', 'Maintenance'),
            ('Employabil ity', 'Employability'),
            ('Princip les', 'Principles'),
            ('ElectronicsI I', 'Electronics II'),
            ('Installationpractical', 'Installation practical'),
            ('Installationtheory', 'Installation theory'),
            ('Measurementand', 'Measurement and'),
            ('projectmanagement', 'project management'),
            ('Systemsautomation', 'Systems automation'),
            ('Systemsinstallation', 'Systems installation'),
            ('SystemsOperations', 'Systems Operations'),
            ('System s', 'Systems'),
            ('Installationmaintenance', 'Installation maintenance'),
        ]
        for old, new in fixes:
            text = text.replace(old, new)
        # Fix venue fragments: "(OUTSIDE SETUP)" -> "WORKSHOP (OUTSIDE SETUP)"
        text = re.sub(r'^\((OUTSIDE|WRK)\s*SHOP?\)', r'WORKSHOP \1', text)
        text = re.sub(r'^BLOCK\)$', 'E BLOCK', text)
        text = re.sub(r'^SETUP\)$', 'WORKSHOP (OUTSIDE SETUP)', text)
        # Normalize whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        return text


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
            'endTime': self._normalize_time(end_time),
            'room': room,
            'teacher': teacher,
            'type': exam_type_lower,
        }

    def _parse_text_lines(self, text: str, result: TimetableParseResult):
        lines = text.split('\n')
        current_date = ''
        for line in lines:
            line = line.strip()
            if not line:
                continue
            m = re.match(r'(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})', line)
            if m:
                current_date = m.group(1).replace('/', '-')
                continue
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
