# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""PDF timetable parser using pdfplumber — handles KNP master-grid and CBET sitting-plan formats."""

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
        self.class_metadata: dict[str, dict] = {}

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

            # Extract time slots from row 2, using row 1 for day detection
            day_row = table[1] if len(table) > 1 else []
            time_slots = self._extract_time_slots(table[2], day_row)
            if not time_slots:
                result.errors.append(f'Page {page_num}: could not parse time slots')
                continue

            # Determine slots per day from the parsed time slots
            if time_slots:
                all_cols = sorted(time_slots.keys())
                # Find first day boundary by detecting when day changes
                first_day = time_slots[all_cols[0]][0]
                slots_per_day = 1
                for ci in all_cols[1:]:
                    if time_slots[ci][0] == first_day:
                        slots_per_day += 1
                    else:
                        break
            else:
                slots_per_day = 5

            max_col = max(time_slots.keys()) if time_slots else 25

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

                # Parse each timeslot cell — use actual column count, not hardcoded 25
                for col_idx in range(1, min(max_col + 1, len(row))):
                    cell_text = str(row[col_idx]).strip() if row[col_idx] else ''
                    if not cell_text:
                        continue

                    if col_idx not in time_slots:
                        continue

                    day, start_time, end_time = time_slots[col_idx]
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

    def _extract_time_slots(self, slot_row: list, day_row: list) -> dict[int, tuple[str, str, str]]:
        """Parse time slot header row into {col_index: (day, start, end)}.

        Adaptively detects grid structure from the day and time slot header rows.
        Works with any number of days (3, 4, 5, 6) and any number of time slots
        per day (3, 4, 5, etc.).

        Returns mapping of column index -> (day_name, start_time, end_time).
        """
        if not slot_row:
            return {}

        # Step 1: Parse day boundaries from the day header row (row 1).
        # Day names appear at the start of each day group; None marks continuation.
        days_order = []
        day_boundaries = {}  # col_idx -> day_name
        for col_idx in range(1, len(day_row)):
            cell = str(day_row[col_idx]).strip() if day_row[col_idx] else ''
            if cell and cell.lower() in self.DAY_ABBR:
                day_name = self.DAY_ABBR[cell.lower()]
                days_order.append(day_name)
                day_boundaries[col_idx] = day_name
            elif cell and cell.capitalize() in [d.capitalize() for d in self.DAYS]:
                day_name = next(d for d in self.DAYS if d.capitalize() == cell.capitalize())
                days_order.append(day_name)
                day_boundaries[col_idx] = day_name

        # Step 2: Determine slots per day from day boundaries
        if len(days_order) >= 2:
            day_starts = sorted(day_boundaries.keys())
            slots_per_day = day_starts[1] - day_starts[0]
        elif len(days_order) == 1:
            # Single day — count non-empty slot cells
            slots_per_day = sum(1 for c in slot_row[1:] if c)
        else:
            # No day headers detected — fall back to 5 slots/day
            slots_per_day = 5

        # Step 3: Parse each time slot cell
        # AM/PM can appear on start time, end time, or both
        slot_re = re.compile(
            r'(\d+)\s*\n\s*(\d{1,2}):(\d{2})\s*(AM|PM)?\s*\n\s*(\d{1,2}):(\d{2})\s*(AM|PM)?',
            re.IGNORECASE,
        )

        slots = {}
        for col_idx in range(1, len(slot_row)):
            cell = str(slot_row[col_idx]) if slot_row[col_idx] else ''
            m = slot_re.search(cell)
            if not m:
                continue

            start_h, start_m = int(m.group(2)), int(m.group(3))
            start_ampm = (m.group(4) or '').upper()
            end_h, end_m = int(m.group(5)), int(m.group(6))
            end_ampm = (m.group(7) or '').upper()

            # If AM/PM is only on one of start/end, infer the other from the
            # slot context. Afternoon slots (13:00-15:00, 15:00-17:00) often
            # only mark PM on the end time (e.g. "4\n01:00\n03:00PM").
            if start_ampm and not end_ampm:
                end_ampm = start_ampm
            if end_ampm and not start_ampm:
                start_ampm = end_ampm

            # Convert to 24h
            if start_ampm == 'PM' and start_h < 12:
                start_h += 12
            if start_ampm == 'AM' and start_h == 12:
                start_h = 0
            if end_ampm == 'PM' and end_h < 12:
                end_h += 12
            if end_ampm == 'AM' and end_h == 12:
                end_h = 0

            start = f'{start_h:02d}:{start_m:02d}'
            end = f'{end_h:02d}:{end_m:02d}'

            # Determine day from column position
            day_idx = (col_idx - 1) // slots_per_day if slots_per_day > 0 else 0
            day = days_order[day_idx] if day_idx < len(days_order) else ''

            slots[col_idx] = (day, start, end)

        return slots

    def _col_to_slot(self, col_idx: int, slots_per_day: int = 5) -> int | None:
        """Map column index to slot number within the day."""
        if col_idx < 1 or slots_per_day < 1:
            return None
        return ((col_idx - 1) % slots_per_day) + 1

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


class PdfSittingPlanParser:
    """Parse KNP CBET per-day sitting-plan exam timetables.

    Each page is a ruled table with SNO, department, curriculum, level,
    cycle/code, class size, unit, date, session, type and venue columns.
    Words are read by coordinates because table extraction merges adjacent
    columns and overflowing unit text interleaves with the date column.
    """

    CODE_RE = re.compile(
        r'\b(?:CBET\s+)?[A-Z]{2,5}\s*/?\s*\d{3}\s*/?\s*[A-Z]\d{2}\b'
    )
    DATE_RE = re.compile(r'(\d{1,2})\s*[/-]\s*(\d{1,2})\s*[/-]\s*(\d{4})')
    TIME_RE = re.compile(r'(\d{1,2})\s*[:.]\s*(\d{2})\s*(AM|PM)', re.IGNORECASE)
    VENUE_RE = re.compile(
        r'(MAIN\s+HALL|[A-Z]\s*-\s*[A-Z0-9]{1,3})\s*\(\s*(\d+)\s*\)',
        re.IGNORECASE,
    )

    def parse(self, file_path: str) -> TimetableParseResult:
        result = TimetableParseResult()
        try:
            with pdfplumber.open(file_path) as pdf:
                self.parse_pdf(pdf, result)
        except Exception as e:
            result.errors.append(f'Failed to open exam PDF: {e}')
        return result

    def parse_pdf(self, pdf, result: TimetableParseResult | None = None) -> TimetableParseResult:
        result = result or TimetableParseResult()
        current_date = ''
        current_session = '08:00'

        for page_num, page in enumerate(pdf.pages, 1):
            words = page.extract_words(keep_blank_chars=False, use_text_flow=False)
            edges = self._cluster([
                edge['top'] for edge in page.edges if edge['orientation'] == 'h'
            ])
            if len(edges) < 2:
                result.errors.append(f'Page {page_num}: no table rows detected')
                continue

            for top, bottom in zip(edges, edges[1:]):
                band_words = [w for w in words if top <= w['top'] < bottom]
                if not band_words:
                    continue

                sno_word, sno_match = self._find_sno(band_words)
                if not sno_word:
                    current_date, current_session = self._update_day_header(
                        band_words, current_date, current_session
                    )
                    continue

                entry, meta, current_date, current_session = self._parse_row(
                    band_words, sno_match, current_date, current_session,
                    page_num, result,
                )
                if not entry:
                    continue
                result.entries.append(entry)
                code = entry['class_id']
                if code not in result.class_metadata:
                    result.class_metadata[code] = meta
                else:
                    for key, value in meta.items():
                        if value and not result.class_metadata[code].get(key):
                            result.class_metadata[code][key] = value

        if not result.entries and not result.errors:
            result.errors.append('No exam entries found in sitting plan PDF')
        return result

    @staticmethod
    def _cluster(values: list[float], tolerance: float = 1.5) -> list[float]:
        clusters: list[float] = []
        for value in sorted(values):
            if not clusters or value - clusters[-1] > tolerance:
                clusters.append(value)
            else:
                clusters[-1] = (clusters[-1] + value) / 2
        return clusters

    @staticmethod
    def _join(words: list[dict]) -> str:
        return re.sub(
            r'\s+', ' ', ' '.join(w['text'] for w in words if w['text'].strip())
        ).strip()

    @staticmethod
    def _find_sno(band_words: list[dict]):
        for word in band_words:
            if word['x0'] >= 60 or '/' in word['text']:
                continue
            if word['text'].upper().endswith(('TH', 'ST', 'ND', 'RD')):
                continue
            match = re.match(r'^(\d+)([A-Z].*)?$', word['text'])
            if match:
                return word, match
        return None, None

    def _update_day_header(self, words: list[dict], current_date: str,
                           current_session: str) -> tuple[str, str]:
        text = self._join(words)
        upper = text.upper()
        match = self.DATE_RE.search(text)
        if match:
            current_date = self._iso_date(match)
        if 'AFTERNOON' in upper:
            current_session = '14:00'
        elif 'MORNING' in upper:
            current_session = '08:00'
        return current_date, current_session

    def _parse_row(self, words: list[dict], sno_match, current_date: str,
                   current_session: str, page_num: int,
                   result: TimetableParseResult):
        sno = int(sno_match.group(1))
        extra_department = (sno_match.group(2) or '').strip()

        def col(low: float, high: float) -> list[dict]:
            return [w for w in words if low <= w['x0'] < high]

        department = self._join(col(60, 180))
        if extra_department:
            department = (extra_department + ' ' + department).strip()
        curriculum = self._join(col(180, 267))
        pre_code = self._join(col(267, 394))
        department, curriculum = self._clean_department_curriculum(
            department, curriculum
        )

        code_match = self.CODE_RE.search(pre_code) or self.CODE_RE.search(
            self._join(words)
        )
        if not code_match:
            result.errors.append(f'Page {page_num}: SNO {sno}: no class code found')
            return None, {}, current_date, current_session
        code = self._clean_code(code_match.group(0))

        level = self._extract_level(pre_code)
        cycle = self._extract_cycle(pre_code + ' ' + curriculum)

        raw_unit = self._join(sorted(
            col(394, 597), key=lambda w: (w['top'], w['x0'])
        ))
        size_match = re.match(r'^\s*(\d+)', raw_unit)
        size_from_pdf = int(size_match.group(1)) if size_match else 0
        unit = re.sub(r'^\s*\d+\s*', '', raw_unit)
        if current_date:
            unit = self._remove_subsequence(unit, self._date_token(current_date))
        unit = re.sub(r'^[^A-Za-z]+', '', unit)
        unit = re.sub(r'\s+', ' ', unit).strip(' -/')

        date_text = self._join(col(555, 597))
        date_match = self.DATE_RE.search(date_text)
        date = self._iso_date(date_match) if date_match else current_date
        if date:
            current_date = date

        session_text = self._join(col(597, 639))
        type_text = self._join(col(639, 703))
        time_match = self.TIME_RE.search(session_text)
        if time_match:
            start_time = self._to_24h(*time_match.groups())
            remainder = session_text[time_match.end():].strip()
            current_session = start_time
        else:
            start_time = current_session
            remainder = session_text
        exam_type = self._exam_type((remainder + ' ' + type_text).upper())
        end_time = self._add_hours(start_time, 3)

        venue_text = self._join(col(703, float('inf')))
        venues = [
            (re.sub(r'\s+', ' ', name).strip(), int(capacity))
            for name, capacity in self.VENUE_RE.findall(venue_text)
        ]
        room = ', '.join(name for name, _ in venues)
        size = sum(capacity for _, capacity in venues) or size_from_pdf

        if not unit:
            result.errors.append(f'Page {page_num}: SNO {sno}: empty unit name')
            return None, {}, current_date, current_session

        entry = {
            'class_id': code,
            'subject': unit,
            'date': date,
            'startTime': start_time,
            'endTime': end_time,
            'room': room,
            'teacher': '',
            'type': exam_type,
            'description': self._description(
                department, curriculum, level, cycle, size, venues, sno
            ),
        }
        meta = {
            'department': department,
            'curriculum': curriculum,
            'level': level,
            'cycle': cycle,
            'class_size': size,
        }
        return entry, meta, current_date, current_session

    @staticmethod
    def _clean_department_curriculum(department: str,
                                     curriculum: str) -> tuple[str, str]:
        department = re.sub(r'\s+', ' ', department).strip()
        curriculum = re.sub(r'\s+', ' ', curriculum).strip()
        if 'ENGINEERINGPRODUCTION' in department:
            department = department.replace('ENGINEERINGPRODUCTION', 'ENGINEERING')
            curriculum = ('PRODUCTION ' + curriculum).strip()
        curriculum = re.sub(r'(?<=[A-Z])LEVEL$', '', curriculum).strip()
        if re.fullmatch(
            r'(KNP\s+CBET|MODULAR|MODULE\s*\d+|CYCLE\s*\d*)',
            curriculum, re.IGNORECASE,
        ):
            curriculum = ''
        return department, curriculum

    @staticmethod
    def _clean_code(raw: str) -> str:
        raw = re.sub(r'\s+', ' ', raw).strip().upper()
        match = re.match(
            r'^(?:CBET\s+)?([A-Z]{2,5})\s*/?\s*(\d{3})\s*/?\s*([A-Z]\d{2})$',
            raw,
        )
        if match:
            return f'{match.group(1)} {match.group(2)} {match.group(3)}'
        raw = re.sub(r'\s*/\s*', ' ', raw)
        raw = re.sub(r'\s+', ' ', raw).strip()
        if raw.startswith('CBET '):
            raw = raw[5:].strip()
        return raw

    @staticmethod
    def _extract_level(pre_code: str) -> str:
        match = re.search(r'LEVEL\s*(\d)', pre_code, re.IGNORECASE)
        if match:
            return match.group(1)
        match = re.search(r'(?:^|\s)(\d)(?=[A-Z])', pre_code)
        if match:
            return match.group(1)
        match = re.search(
            r'(?:^|\s)(\d)(?=\s+(?:CBET|MODULAR|MODULE|CYCLE)\b)', pre_code
        )
        return match.group(1) if match else ''

    @staticmethod
    def _extract_cycle(text: str) -> str:
        match = re.search(r'(MODULAR|MODULE\s*\d+|CYCLE\s*\d*)', text, re.IGNORECASE)
        if not match:
            return ''
        return re.sub(r'\s+', ' ', match.group(1).upper()).strip()

    @staticmethod
    def _remove_subsequence(text: str, token: str) -> str:
        if not token:
            return text
        result = []
        token_index = 0
        for char in text:
            if token_index < len(token) and char == token[token_index]:
                token_index += 1
                continue
            result.append(char)
        return ''.join(result)

    @staticmethod
    def _date_token(iso_date: str) -> str:
        return f'{iso_date[8:10]}/{iso_date[5:7]}/{iso_date[0:4]}'

    @staticmethod
    def _iso_date(match) -> str:
        day, month, year = (int(match.group(i)) for i in (1, 2, 3))
        return f'{year:04d}-{month:02d}-{day:02d}'

    @staticmethod
    def _to_24h(hour, minute, ampm) -> str:
        hour = int(hour)
        if ampm and ampm.upper() == 'PM' and hour < 12:
            hour += 12
        if ampm and ampm.upper() == 'AM' and hour == 12:
            hour = 0
        return f'{hour:02d}:{int(minute):02d}'

    @staticmethod
    def _add_hours(time: str, hours: int) -> str:
        if not time:
            return ''
        hour, minute = (int(part) for part in time.split(':'))
        return f'{(hour + hours) % 24:02d}:{minute:02d}'

    @staticmethod
    def _exam_type(text: str) -> str:
        if 'PRACTICAL' in text:
            return 'practical'
        if 'MIDTERM' in text or 'MID-TERM' in text:
            return 'midterm'
        if re.search(r'\bCAT\b', text):
            return 'cat'
        return 'final'

    @staticmethod
    def _description(department: str, curriculum: str, level: str, cycle: str,
                     size: int, venues: list[tuple[str, int]], sno: int) -> str:
        parts = []
        if department:
            parts.append(f'Dept: {department}')
        if curriculum:
            parts.append(f'Curriculum: {curriculum}')
        if level:
            parts.append(f'Level {level}')
        if cycle:
            parts.append(f'Cycle: {cycle}')
        if size:
            parts.append(f'Class size {size}')
        if venues:
            parts.append('Venues: ' + '; '.join(
                f'{name} ({capacity})' for name, capacity in venues
            ))
        parts.append(f'SNO {sno}')
        return ' | '.join(parts)


class PdfExamTimetableParser:
    """Parse exam timetable PDFs, delegating per-day CBET sitting plans to PdfSittingPlanParser."""

    EXAM_TYPES = ['final', 'midterm', 'cat', 'practical']

    def parse(self, file_path: str) -> TimetableParseResult:
        result = TimetableParseResult()
        try:
            with pdfplumber.open(file_path) as pdf:
                if self._is_sitting_plan(pdf):
                    return PdfSittingPlanParser().parse_pdf(pdf)
                for page_num, page in enumerate(pdf.pages, 1):
                    self._parse_page(page, page_num, result)
        except Exception as e:
            result.errors.append(f'Failed to open exam PDF: {e}')
        return result

    @staticmethod
    def _is_sitting_plan(pdf) -> bool:
        if not pdf.pages:
            return False
        try:
            text = (pdf.pages[0].extract_text() or '').upper()
        except Exception:
            return False
        return (
            'SITTING PLAN' in text
            or ('CURRICULUM NAME' in text and 'ASSESSMENT TYPE' in text)
            or ('SNO' in text and 'UNIT NAME' in text and 'VENUE' in text)
        )

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
