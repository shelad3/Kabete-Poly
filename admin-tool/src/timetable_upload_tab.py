# SPDX-License-Identifier: AGPL-3.0-or-Later
# Copyright (C) 2026 Kabete National Polytechnique

"""Timetable Upload Tab — wizard with mode selector, class ID mapping, parse-all, duplicate detection."""

import os
import re
import threading
from collections import defaultdict

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFileDialog, QComboBox, QStackedWidget, QProgressBar,
    QMessageBox, QGroupBox, QRadioButton, QButtonGroup,
    QCheckBox, QScrollArea, QTableWidget, QTableWidgetItem,
    QHeaderView, QFrame, QSpinBox, QTextEdit,
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QFont, QColor

from firestore_client import FirestoreClient
from preview_table_widget import PreviewTableWidget


# ── Match status colours ────────────────────────────────────────────
MATCH_EXACT = QColor('#4CAF50')    # green
MATCH_FUZZY = QColor('#FF9800')    # amber
MATCH_MISS  = QColor('#F44336')    # red


class TimetableUploadTab(QWidget):
    """Step-by-step timetable upload wizard with class ID mapping, mode select, duplicate check."""

    STEPS = ['Select Mode', 'Select File', 'Parse', 'Class ID Mapping',
             'Preview & Select', 'Verify Duplicates', 'Upload']

    def __init__(self):
        super().__init__()
        self._classes: list[str] = []
        self._mode: str = 'class'
        self._parsed_entries: list[dict] = []
        self._file_path: str = ''
        self._class_groups: dict[str, list[int]] = {}
        self._duplicate_indices: set[int] = set()
        self._available_classes: list[str] = []
        self._clear_existing: bool = False
        self._class_mapping: dict[str, str] = {}  # pdf_cohort -> firestore_class
        self._newly_created_classes: list[str] = []
        self._build_ui()

    def _build_ui(self):
        outer = QVBoxLayout(self)

        # Step indicator
        self._step_label = QLabel('Step 1 of 7: Select Mode')
        self._step_label.setStyleSheet('font-size: 16px; font-weight: bold; color: #1A237E; padding: 8px;')
        outer.addWidget(self._step_label)

        self._progress_bar = QProgressBar()
        self._progress_bar.setMaximum(7)
        self._progress_bar.setValue(1)
        self._progress_bar.setTextVisible(True)
        self._progress_bar.setFormat('Step %v of 7')
        outer.addWidget(self._progress_bar)

        # Stack for wizard steps
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self._stack = QStackedWidget()
        scroll.setWidget(self._stack)
        outer.addWidget(scroll)

        # Step 0: Mode selection
        self._stack.addWidget(self._build_step0())

        # Step 1: File selection
        self._stack.addWidget(self._build_step1())

        # Step 2: Parsing
        self._stack.addWidget(self._build_step2())

        # Step 3: Class ID Mapping
        self._stack.addWidget(self._build_step3_mapping())

        # Step 4: Preview & Select
        self._stack.addWidget(self._build_step4_preview())

        # Step 5: Verify duplicates
        self._stack.addWidget(self._build_step5_duplicates())

        # Step 6: Upload complete
        self._stack.addWidget(self._build_step6_done())

        # Navigation
        nav = QHBoxLayout()
        self._back_btn = QPushButton('← Back')
        self._back_btn.clicked.connect(self._go_back)
        self._back_btn.setEnabled(False)
        nav.addWidget(self._back_btn)
        nav.addStretch()
        self._next_btn = QPushButton('Next →')
        self._next_btn.clicked.connect(self._go_next)
        self._next_btn.setStyleSheet('background-color: #1A237E; color: white; padding: 8px 20px;')
        nav.addWidget(self._next_btn)
        outer.addLayout(nav)

        self._current_step = 0

    def refresh_classes(self, classes: list[str]):
        self._available_classes = classes

    # ── Step Builders ──────────────────────────────────────────────

    def _build_step0(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setSpacing(16)

        layout.addWidget(QLabel('What type of timetable are you uploading?'))
        layout.addSpacing(10)

        self._mode_group = QButtonGroup(self)
        class_rb = QRadioButton('Class Timetable (weekly schedule: day, time, unit, venue, lecturer)')
        class_rb.setChecked(True)
        exam_rb = QRadioButton('Exam Timetable (exam schedule: subject, date, time, room, teacher)')

        self._mode_group.addButton(class_rb, 1)
        self._mode_group.addButton(exam_rb, 2)
        self._mode_group.buttonClicked.connect(self._on_mode_changed)

        layout.addWidget(class_rb)
        layout.addWidget(exam_rb)
        layout.addSpacing(20)

        self._clear_checkbox = QCheckBox('Delete all existing timetable data before uploading (replace mode)')
        self._clear_checkbox.setStyleSheet('font-weight: bold; color: #C62828;')
        layout.addWidget(self._clear_checkbox)

        layout.addStretch()
        return w

    def _build_step1(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(QLabel('Select a timetable file:'))
        layout.addSpacing(10)

        self._mode_label = QLabel('Mode: Class Timetable')
        self._mode_label.setStyleSheet('color: #1A237E; font-weight: bold;')
        layout.addWidget(self._mode_label)

        self._file_display = QLabel('No file selected')
        self._file_display.setStyleSheet('padding: 20px; background: #f0f0f0; border: 2px dashed #ccc; font-size: 14px;')
        self._file_display.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self._file_display)

        browse_btn = QPushButton('Browse Files...')
        browse_btn.clicked.connect(self._browse_file)
        browse_btn.setStyleSheet('padding: 10px 20px; font-size: 14px;')
        layout.addWidget(browse_btn)

        layout.addWidget(QLabel(''))
        layout.addWidget(QLabel('The parser will auto-detect classes/groups from the file content.'))
        layout.addWidget(QLabel('You can map PDF class IDs to Firestore classes in the next step.'))

        self._class_hint = QLabel('')
        self._class_hint.setStyleSheet('color: #666; font-style: italic;')
        layout.addWidget(self._class_hint)

        layout.addStretch()
        return w

    def _build_step2(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self._parse_status = QLabel('Parsing file...')
        self._parse_status.setStyleSheet('font-size: 16px;')
        layout.addWidget(self._parse_status)

        self._parse_detail = QLabel('')
        self._parse_detail.setStyleSheet('color: #666;')
        layout.addWidget(self._parse_detail)

        self._parse_progress = QProgressBar()
        self._parse_progress.setRange(0, 0)
        layout.addWidget(self._parse_progress)

        layout.addStretch()
        return w

    # ── Step 3: Class ID Mapping ──────────────────────────────────

    def _build_step3_mapping(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)

        intro = QLabel(
            'Class ID Mapping — map PDF class IDs to Firestore classes.\n'
            'Green = exact match, Amber = fuzzy match, Red = not found.'
        )
        intro.setStyleSheet('font-size: 13px; color: #333; padding: 8px 0;')
        layout.addWidget(intro)

        # Summary row
        self._map_summary = QLabel('')
        self._map_summary.setStyleSheet('font-weight: bold; padding: 4px;')
        layout.addWidget(self._map_summary)

        # Mapping table
        self._map_table = QTableWidget()
        self._map_table.setColumnCount(5)
        self._map_table.setHorizontalHeaderLabels([
            'PDF Cohort ID', 'Status', 'Firestore Class', 'Action', 'Entries'
        ])
        self._map_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        self._map_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        self._map_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self._map_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        self._map_table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        self._map_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._map_table.verticalHeader().setVisible(False)
        layout.addWidget(self._map_table)

        # Buttons row
        btn_row = QHBoxLayout()
        self._create_missing_btn = QPushButton('Create All Missing Classes')
        self._create_missing_btn.clicked.connect(self._create_all_missing)
        self._create_missing_btn.setStyleSheet('background-color: #4CAF50; color: white; padding: 8px 16px; font-weight: bold;')
        btn_row.addWidget(self._create_missing_btn)

        self._refresh_mapping_btn = QPushButton('Refresh Firestore Classes')
        self._refresh_mapping_btn.clicked.connect(self._refresh_mapping)
        btn_row.addWidget(self._refresh_mapping_btn)

        btn_row.addStretch()
        layout.addLayout(btn_row)

        return w

    # ── Step 4: Preview & Select ──────────────────────────────────

    def _build_step4_preview(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.addWidget(QLabel('Preview & Select — check the entries to upload:'))

        # Class mapping controls
        mapping_row = QHBoxLayout()
        mapping_row.addWidget(QLabel('Manual class override (optional):'))
        self._class_override = QComboBox()
        self._class_override.setEditable(True)
        self._class_override.setPlaceholderText('Auto-detected...')
        mapping_row.addWidget(self._class_override)
        self._apply_class_btn = QPushButton('Apply to All')
        self._apply_class_btn.clicked.connect(self._apply_class_override)
        mapping_row.addWidget(self._apply_class_btn)
        mapping_row.addStretch()
        layout.addLayout(mapping_row)

        self._preview_table = PreviewTableWidget()
        layout.addWidget(self._preview_table)
        return w

    # ── Step 5: Verify duplicates ─────────────────────────────────

    def _build_step5_duplicates(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._dup_status = QLabel('Checking for duplicates...')
        self._dup_status.setStyleSheet('font-size: 16px;')
        layout.addWidget(self._dup_status)
        self._dup_detail = QLabel('')
        layout.addWidget(self._dup_detail)
        self._dup_progress = QProgressBar()
        self._dup_progress.setRange(0, 0)
        layout.addWidget(self._dup_progress)
        layout.addStretch()
        return w

    # ── Step 6: Upload done ───────────────────────────────────────

    def _build_step6_done(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._upload_status = QLabel('Uploading...')
        self._upload_status.setStyleSheet('font-size: 18px; font-weight: bold; color: #4CAF50;')
        layout.addWidget(self._upload_status)
        self._upload_detail = QLabel('')
        layout.addWidget(self._upload_detail)

        self._upload_progress = QProgressBar()
        self._upload_progress.setVisible(False)
        layout.addWidget(self._upload_progress)

        self._upload_again_btn = QPushButton('Upload Another File')
        self._upload_again_btn.clicked.connect(self._reset)
        self._upload_again_btn.setStyleSheet('padding: 10px 20px;')
        layout.addWidget(self._upload_again_btn, alignment=Qt.AlignmentFlag.AlignCenter)
        layout.addStretch()
        return w

    # ── Navigation ─────────────────────────────────────────────────

    def _go_next(self):
        if self._current_step == 0:
            self._on_mode_changed()
            self._clear_existing = self._clear_checkbox.isChecked()
            if self._clear_existing:
                reply = QMessageBox.warning(
                    self, 'Replace Mode',
                    'You selected REPLACE MODE: all existing timetable data for '
                    'the selected classes will be DELETED before uploading new data.\n\n'
                    'This cannot be undone. Continue?',
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                )
                if reply != QMessageBox.StandardButton.Yes:
                    self._clear_existing = False
                    self._clear_checkbox.setChecked(False)
                    return
        elif self._current_step == 1:
            if not self._validate_step1():
                return
            self._start_parsing()
        elif self._current_step == 2:
            pass  # parsing auto-advances via _on_parse_complete
        elif self._current_step == 3:
            if self._has_unmapped_classes():
                reply = QMessageBox.warning(
                    self, 'Unmapped Classes',
                    'Some PDF class IDs have no Firestore match.\n'
                    'Create missing classes or remap them before uploading.',
                    QMessageBox.StandardButton.Ok,
                )
                return
            self._apply_mapping_and_show_preview()
        elif self._current_step == 4:
            if self._clear_existing:
                self._do_upload()
                self._current_step = 6
                self._stack.setCurrentIndex(6)
                self._progress_bar.setValue(7)
                self._step_label.setText(f'Step 7 of 7: {self.STEPS[6]}')
                self._back_btn.setEnabled(False)
                self._next_btn.setText('Finish')
                self._next_btn.setEnabled(False)
                return
            else:
                self._start_dup_check()
        elif self._current_step == 5:
            self._do_upload()

        if self._current_step < 6:
            self._current_step += 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 7: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0 and self._current_step < 6)
            if self._current_step == 6:
                self._next_btn.setText('Finish')
                self._next_btn.setEnabled(False)

    def _go_back(self):
        if self._current_step > 0:
            self._current_step -= 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 7: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0 and self._current_step < 6)
            self._next_btn.setText('Next →')
            self._next_btn.setEnabled(True)

    def _reset(self):
        self._current_step = 0
        self._parsed_entries = []
        self._class_groups = {}
        self._duplicate_indices.clear()
        self._file_path = ''
        self._clear_existing = False
        self._class_mapping.clear()
        self._newly_created_classes.clear()
        self._file_display.setText('No file selected')
        self._preview_table.clear_data()
        self._stack.setCurrentIndex(0)
        self._progress_bar.setValue(1)
        self._step_label.setText(f'Step 1 of 7: {self.STEPS[0]}')
        self._back_btn.setEnabled(False)
        self._next_btn.setText('Next →')
        self._next_btn.setEnabled(True)
        self._class_override.setCurrentText('')

    # ── Mode ───────────────────────────────────────────────────────

    def _on_mode_changed(self):
        btn_id = self._mode_group.checkedId()
        self._mode = 'exam' if btn_id == 2 else 'class'
        self._mode_label.setText(f'Mode: {"Exam Timetable" if self._mode == "exam" else "Class Timetable"}')
        self._preview_table.set_mode(self._mode)

    # ── Validation ─────────────────────────────────────────────────

    def _validate_step1(self) -> bool:
        if not self._file_path:
            QMessageBox.warning(self, 'No File', 'Please select a file first.')
            return False
        if not os.path.exists(self._file_path):
            QMessageBox.warning(self, 'Invalid File', 'Selected file does not exist.')
            return False
        return True

    # ── Step Actions ───────────────────────────────────────────────

    def _browse_file(self):
        path, _ = QFileDialog.getOpenFileName(
            self, 'Select Timetable File', '',
            'Supported Files (*.pdf *.csv);;PDF Files (*.pdf);;CSV Files (*.csv);;All Files (*)',
        )
        if path:
            self._file_path = path
            name = os.path.basename(path)
            self._file_display.setText(f'\U0001f4c4 {name}')
            self._file_display.setStyleSheet(
                'padding: 20px; background: #E8F5E9; border: 2px solid #4CAF50; font-size: 14px;'
            )
            class_hint = self._detect_class_from_filename(name)
            if class_hint:
                self._class_hint.setText(f'Hint: detected class "{class_hint}" from filename')

    def _detect_class_from_filename(self, name: str) -> str:
        name_no_ext = os.path.splitext(name)[0]
        m = re.search(r'([A-Z]{2,4}\s*-?\s*\d[A-Z])', name_no_ext, re.IGNORECASE)
        if m:
            return m.group(1).upper()
        for word in re.split(r'[_\-.\s]+', name_no_ext):
            if re.match(r'^[A-Z]{2,4}\d?[A-Z]?$', word.upper()):
                return word.upper()
        return ''

    def _start_parsing(self):
        self._parse_status.setText('Parsing file...')
        self._parse_detail.setText(f'File: {os.path.basename(self._file_path)}')
        QTimer.singleShot(100, self._do_parse)

    def _do_parse(self):
        try:
            ext = os.path.splitext(self._file_path)[1].lower()
            if self._mode == 'exam':
                if ext == '.csv':
                    from csv_parser import CsvExamTimetableParser
                    parser = CsvExamTimetableParser()
                else:
                    from pdf_parser import PdfExamTimetableParser
                    parser = PdfExamTimetableParser()
            else:
                if ext == '.csv':
                    from csv_parser import CsvTimetableParser
                    parser = CsvTimetableParser()
                else:
                    from pdf_parser import PdfTimetableParser
                    parser = PdfTimetableParser()

            result = parser.parse(self._file_path)
            self._parsed_entries = result.entries
            errors = result.errors
            detected_class = getattr(result, 'class_id', '')

            self._class_groups = self._build_class_groups(result)

            detail_parts = [f'Found {len(result.entries)} entries']
            if errors:
                detail_parts.append(f', {len(errors)} errors')
            if detected_class:
                detail_parts.append(f'\nDetected class: {detected_class}')
            if self._class_groups:
                groups_summary = ', '.join(f'{k}={len(v)}' for k, v in self._class_groups.items())
                detail_parts.append(f'\nGroups: {groups_summary}')

            self._parse_detail.setText(''.join(detail_parts))

            if errors:
                self._parse_status.setText('Parsing completed with errors')
            else:
                self._parse_status.setText('Parsing successful!')

            if len(result.entries) > 0:
                # Auto-advance to class ID mapping
                self._build_mapping_from_parsed()
                self._current_step += 1
                self._stack.setCurrentIndex(self._current_step)
                self._progress_bar.setValue(self._current_step + 1)
                self._step_label.setText(f'Step {self._current_step + 1} of 7: {self.STEPS[self._current_step]}')
                self._back_btn.setEnabled(True)
                self._next_btn.setEnabled(True)
            else:
                self._next_btn.setEnabled(False)

        except Exception as e:
            self._parse_status.setText('Parsing failed')
            import traceback
            self._parse_detail.setText(traceback.format_exc())

    def _build_class_groups(self, result) -> dict[str, list[int]]:
        """Group parsed entries by detected class."""
        groups = defaultdict(list)

        has_class_ids = any(e.get('class_id') for e in self._parsed_entries)

        if has_class_ids:
            for i, entry in enumerate(self._parsed_entries):
                cls = entry.get('class_id', '').strip().upper()
                if cls:
                    groups[cls].append(i)
                else:
                    groups['Unspecified'].append(i)
            return dict(groups)

        detected_class = getattr(result, 'class_id', '') or ''

        if hasattr(result, 'headers') and result.headers:
            class_col_idx = None
            for i, h in enumerate(result.headers):
                if h.lower() in ('class', 'class id', 'classid', 'group', 'cohort'):
                    class_col_idx = i
                    break
            if class_col_idx is not None:
                from csv import reader as csv_reader
                try:
                    with open(self._file_path, 'r', encoding='utf-8-sig') as f:
                        rows = list(csv_reader(f))
                    for idx, row in enumerate(rows[1:], 1):
                        if idx - 1 < len(self._parsed_entries) and class_col_idx < len(row):
                            cls = row[class_col_idx].strip().upper()
                            if cls:
                                groups[cls].append(idx - 1)
                            else:
                                groups['Unspecified'].append(idx - 1)
                except Exception:
                    pass

        if not groups:
            if detected_class:
                groups[detected_class] = list(range(len(self._parsed_entries)))
            else:
                for i, entry in enumerate(self._parsed_entries):
                    cls = entry.get('class_id', '').strip().upper()
                    if cls:
                        groups[cls].append(i)
                if not groups:
                    name_hint = self._detect_class_from_filename(os.path.basename(self._file_path))
                    if name_hint:
                        groups[name_hint] = list(range(len(self._parsed_entries)))
                    else:
                        groups['All Entries'] = list(range(len(self._parsed_entries)))

        return dict(groups)

    # ── Class ID Mapping Logic ─────────────────────────────────────

    def _build_mapping_from_parsed(self):
        """After parsing, build mapping table comparing PDF class IDs to Firestore classes."""
        # Refresh available classes from Firestore
        try:
            db = FirestoreClient.get()
            self._available_classes = [doc.id for doc in db.db.collection('classes').stream()]
        except Exception:
            self._available_classes = list(self._classes)

        # Count entries per class
        entries_per_class: dict[str, int] = defaultdict(int)
        for entry in self._parsed_entries:
            cid = entry.get('class_id', '').strip().upper()
            if cid:
                entries_per_class[cid] += 1

        pdf_cohorts = sorted(entries_per_class.keys())
        self._class_mapping.clear()
        self._newly_created_classes.clear()

        # Build mapping
        exact = 0
        fuzzy = 0
        miss = 0
        rows_data = []

        for cohort in pdf_cohorts:
            if cohort in self._available_classes:
                self._class_mapping[cohort] = cohort
                rows_data.append((cohort, 'exact', cohort, entries_per_class[cohort]))
                exact += 1
            else:
                match = self._fuzzy_match(cohort, self._available_classes)
                if match:
                    self._class_mapping[cohort] = match
                    rows_data.append((cohort, 'fuzzy', match, entries_per_class[cohort]))
                    fuzzy += 1
                else:
                    rows_data.append((cohort, 'missing', '', entries_per_class[cohort]))
                    miss += 1

        # Populate table
        self._map_table.setRowCount(len(rows_data))
        for row_idx, (pdf_id, status, fs_class, count) in enumerate(rows_data):
            # PDF Cohort ID
            item0 = QTableWidgetItem(pdf_id)
            item0.setFlags(item0.flags() & ~Qt.ItemFlag.ItemIsEditable)
            if status == 'missing':
                item0.setForeground(MATCH_MISS)
            elif status == 'fuzzy':
                item0.setForeground(MATCH_FUZZY)
            else:
                item0.setForeground(MATCH_EXACT)
            self._map_table.setItem(row_idx, 0, item0)

            # Status badge
            if status == 'exact':
                status_text = '✅ Exact Match'
                status_color = QColor('#E8F5E9')
            elif status == 'fuzzy':
                status_text = '⚡ Fuzzy Match'
                status_color = QColor('#FFF3E0')
            else:
                status_text = '❌ Not Found'
                status_color = QColor('#FFEBEE')

            item1 = QTableWidgetItem(status_text)
            item1.setFlags(item1.flags() & ~Qt.ItemFlag.ItemIsEditable)
            item1.setBackground(status_color)
            self._map_table.setItem(row_idx, 1, item1)

            # Firestore Class (editable combo)
            combo = QComboBox()
            combo.setEditable(True)
            combo.addItem('')
            combo.addItems(sorted(self._available_classes))
            if fs_class:
                combo.setCurrentText(fs_class)
            combo.currentTextChanged.connect(lambda text, r=row_idx, p=pdf_id: self._on_mapping_changed(r, p, text))
            self._map_table.setCellWidget(row_idx, 2, combo)

            # Action column
            if status == 'missing':
                create_btn = QPushButton('Create')
                create_btn.setStyleSheet('background-color: #4CAF50; color: white; padding: 4px 8px; font-weight: bold;')
                create_btn.clicked.connect(lambda _, r=row_idx, p=pdf_id: self._create_single_class(r, p))
                action_widget = QWidget()
                action_layout = QHBoxLayout(action_widget)
                action_layout.setContentsMargins(4, 2, 4, 2)
                action_layout.addWidget(create_btn)
                self._map_table.setCellWidget(row_idx, 3, action_widget)
            else:
                item3 = QTableWidgetItem('')
                item3.setFlags(item3.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self._map_table.setItem(row_idx, 3, item3)

            # Entries count
            item4 = QTableWidgetItem(str(count))
            item4.setFlags(item4.flags() & ~Qt.ItemFlag.ItemIsEditable)
            item4.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self._map_table.setItem(row_idx, 4, item4)

        self._map_table.resizeRowsToContents()

        # Update summary
        total = len(pdf_cohorts)
        self._map_summary.setText(
            f'{total} PDF cohorts found: '
            f'{exact} exact matches, {fuzzy} fuzzy matches, {miss} not found in Firestore'
        )
        if miss > 0:
            self._map_summary.setStyleSheet('font-weight: bold; color: #C62828; padding: 4px;')
        elif fuzzy > 0:
            self._map_summary.setStyleSheet('font-weight: bold; color: #E65100; padding: 4px;')
        else:
            self._map_summary.setStyleSheet('font-weight: bold; color: #2E7D32; padding: 4px;')

        self._create_missing_btn.setEnabled(miss > 0)
        self._next_btn.setEnabled(miss == 0 or fuzzy + exact > 0)

    def _fuzzy_match(self, cohort: str, available: list[str]) -> str | None:
        """Try to find a matching Firestore class for a PDF cohort ID."""
        norm = cohort.lower().replace(' ', '').replace('&', '').replace('-', '')
        for cls in available:
            norm_cls = cls.lower().replace(' ', '').replace('&', '').replace('-', '')
            if norm == norm_cls:
                return cls
        # Partial prefix match (e.g., "ICT 500" might match "ICT 510")
        parts = cohort.split()
        if len(parts) >= 2:
            prefix = parts[0]
            for cls in available:
                cls_parts = cls.split()
                if cls_parts and cls_parts[0] == prefix:
                    # Same prefix — possible fuzzy match
                    return cls
        return None

    def _on_mapping_changed(self, row: int, pdf_cohort: str, new_class: str):
        """User manually changed a mapping via the combo box."""
        new_class = new_class.strip()
        if new_class:
            self._class_mapping[pdf_cohort] = new_class
            # Update status column
            status_item = self._map_table.item(row, 1)
            if new_class in self._available_classes:
                status_item.setText('🔄 Remapped')
                status_item.setBackground(QColor('#E3F2FD'))
            else:
                status_item.setText('🆕 New Class')
                status_item.setBackground(QColor('#F3E5F5'))
        elif pdf_cohort in self._class_mapping:
            del self._class_mapping[pdf_cohort]
            status_item = self._map_table.item(row, 1)
            status_item.setText('❌ Not Found')
            status_item.setBackground(QColor('#FFEBEE'))

    def _create_single_class(self, row: int, pdf_cohort: str):
        """Create a single missing class in Firestore and update the mapping."""
        try:
            db = FirestoreClient.get()
            db.db.collection('classes').document(pdf_cohort).set({
                'name': pdf_cohort,
                'department': 'Unknown',
                'active': True,
            })
            self._available_classes.append(pdf_cohort)
            self._class_mapping[pdf_cohort] = pdf_cohort
            self._newly_created_classes.append(pdf_cohort)

            # Update row
            status_item = self._map_table.item(row, 1)
            status_item.setText('✅ Created')
            status_item.setBackground(QColor('#E8F5E9'))
            status_item.setForeground(MATCH_EXACT)

            combo = self._map_table.cellWidget(row, 2)
            if isinstance(combo, QComboBox):
                combo.addItem(pdf_cohort)
                combo.setCurrentText(pdf_cohort)

            # Remove Create button
            action_widget = self._map_table.cellWidget(row, 3)
            if action_widget:
                action_widget.deleteLater()
                empty = QTableWidgetItem('')
                empty.setFlags(empty.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self._map_table.setItem(row, 3, empty)

            # Update summary
            self._update_mapping_summary()
            self._next_btn.setEnabled(self._has_unmapped_classes() is False)
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to create class: {e}')

    def _create_all_missing(self):
        """Create all missing classes in Firestore at once."""
        try:
            db = FirestoreClient.get()
            created = []
            for row_idx in range(self._map_table.rowCount()):
                status_item = self._map_table.item(row_idx, 1)
                if status_item and ('Not Found' in status_item.text() or '❌' in status_item.text()):
                    pdf_id_item = self._map_table.item(row_idx, 0)
                    if pdf_id_item:
                        pdf_cohort = pdf_id_item.text()
                        db.db.collection('classes').document(pdf_cohort).set({
                            'name': pdf_cohort,
                            'department': 'Unknown',
                            'active': True,
                        })
                        self._available_classes.append(pdf_cohort)
                        self._class_mapping[pdf_cohort] = pdf_cohort
                        self._newly_created_classes.append(pdf_cohort)
                        created.append(pdf_cohort)

                        # Update row
                        status_item.setText('✅ Created')
                        status_item.setBackground(QColor('#E8F5E9'))
                        status_item.setForeground(MATCH_EXACT)

                        combo = self._map_table.cellWidget(row_idx, 2)
                        if isinstance(combo, QComboBox):
                            combo.addItem(pdf_cohort)
                            combo.setCurrentText(pdf_cohort)

                        # Remove Create button
                        action_widget = self._map_table.cellWidget(row_idx, 3)
                        if action_widget:
                            action_widget.deleteLater()
                            empty = QTableWidgetItem('')
                            empty.setFlags(empty.flags() & ~Qt.ItemFlag.ItemIsEditable)
                            self._map_table.setItem(row_idx, 3, empty)

            self._update_mapping_summary()
            self._next_btn.setEnabled(True)

            if created:
                QMessageBox.information(
                    self, 'Classes Created',
                    f'Created {len(created)} new classes:\n' + '\n'.join(created[:20])
                )
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to create classes: {e}')

    def _update_mapping_summary(self):
        exact = fuzzy = miss = 0
        for row_idx in range(self._map_table.rowCount()):
            status_item = self._map_table.item(row_idx, 1)
            if status_item:
                t = status_item.text()
                if 'Exact' in t or 'Created' in t or 'Remapped' in t:
                    exact += 1
                elif 'Fuzzy' in t:
                    fuzzy += 1
                else:
                    miss += 1
        total = exact + fuzzy + miss
        self._map_summary.setText(
            f'{total} PDF cohorts: {exact} mapped, {fuzzy} fuzzy, {miss} unmapped'
        )
        if miss > 0:
            self._map_summary.setStyleSheet('font-weight: bold; color: #C62828; padding: 4px;')
        else:
            self._map_summary.setStyleSheet('font-weight: bold; color: #2E7D32; padding: 4px;')

    def _has_unmapped_classes(self) -> bool:
        """Check if any cohort has no mapping."""
        for row_idx in range(self._map_table.rowCount()):
            status_item = self._map_table.item(row_idx, 1)
            if status_item and ('Not Found' in status_item.text() or '❌' in status_item.text()):
                return True
        return False

    def _refresh_mapping(self):
        """Refresh available classes from Firestore and rebuild mapping table."""
        self._build_mapping_from_parsed()

    def _apply_mapping_and_show_preview(self):
        """Apply the class ID mapping: remap entry class_ids, then show preview."""
        # Apply mapping to entries
        for entry in self._parsed_entries:
            old_cid = entry.get('class_id', '').strip().upper()
            if old_cid and old_cid in self._class_mapping:
                entry['class_id'] = self._class_mapping[old_cid]

        # Rebuild class groups with mapped IDs
        self._class_groups = defaultdict(list)
        for i, entry in enumerate(self._parsed_entries):
            cid = entry.get('class_id', '').strip().upper()
            if cid:
                self._class_groups[cid].append(i)
            else:
                self._class_groups['Unspecified'].append(i)
        self._class_groups = dict(self._class_groups)

        self._show_preview()

    # ── Preview ────────────────────────────────────────────────────

    def _show_preview(self):
        """Populate the preview table with parsed data."""
        self._class_override.clear()
        self._class_override.addItems([''] + self._available_classes)
        self._preview_table.set_mode(self._mode)
        self._preview_table.populate(self._parsed_entries, class_groups=self._class_groups)

    def _apply_class_override(self):
        """Re-group entries under the selected class."""
        override = self._class_override.currentText().strip()
        if not override:
            return
        self._class_groups = {override: list(range(len(self._parsed_entries)))}
        self._preview_table.populate(self._parsed_entries, class_groups=self._class_groups)

    # ── Duplicate Check ────────────────────────────────────────────

    def _start_dup_check(self):
        if self._clear_existing:
            self._duplicate_indices.clear()
            self._preview_table.set_duplicates(set())
            selected = len(self._preview_table.get_selected_entries())
            self._dup_status.setText('Replace mode — duplicate check skipped')
            self._dup_detail.setText(f'{selected} entries ready to upload (existing data will be cleared)')
            self._dup_progress.setVisible(False)
            self._next_btn.setEnabled(selected > 0)
            return
        self._dup_status.setText('Checking for duplicates in Firestore...')
        self._dup_progress.setVisible(True)
        QTimer.singleShot(100, self._do_dup_check)

    def _do_dup_check(self):
        self._next_btn.setEnabled(False)
        self._dup_progress.setRange(0, 0)

        def _worker():
            try:
                db = FirestoreClient.get()
                dup_indices: set[int] = set()
                checked = 0

                for group_name, indices in self._class_groups.items():
                    class_id = group_name if group_name != 'All Entries' else (
                        self._class_override.currentText().strip() or 'Unspecified'
                    )
                    if class_id == 'All Entries' or class_id not in self._available_classes:
                        for av_cls in self._available_classes:
                            if class_id.lower() in av_cls.lower() or av_cls.lower() in class_id.lower():
                                class_id = av_cls
                                break
                    else:
                        continue

                    for idx in indices:
                        if idx >= len(self._parsed_entries):
                            continue
                        entry = self._parsed_entries[idx]
                        is_dup, _ = db.duplicate_exists(class_id, entry, self._mode)
                        if is_dup:
                            dup_indices.add(idx)
                        checked += 1

                self._dup_result = (dup_indices, checked, None)
            except Exception as e:
                self._dup_result = (set(), 0, e)

            QTimer.singleShot(0, self._on_dup_check_done)

        self._dup_result = None
        threading.Thread(target=_worker, daemon=True).start()

    def _on_dup_check_done(self):
        if self._dup_result is None:
            QTimer.singleShot(50, self._on_dup_check_done)
            return

        dup_indices, checked, error = self._dup_result

        if error:
            self._dup_status.setText('Duplicate check failed — will upload all selected')
            self._dup_detail.setText(f'Error: {error}')
            self._dup_progress.setVisible(False)
            self._next_btn.setEnabled(True)
            return

        self._duplicate_indices = dup_indices
        self._preview_table.set_duplicates(dup_indices)
        self._preview_table.populate(self._parsed_entries, duplicates=dup_indices, class_groups=self._class_groups)

        dup_count = len(dup_indices)
        selected = len(self._preview_table.get_selected_entries())
        self._dup_status.setText(
            f'Duplicate check complete — {dup_count} duplicates found, {selected} ready to upload'
        )
        self._dup_detail.setText(
            f'{checked} entries checked across {len(self._class_groups)} class group(s)\n'
            f'Duplicates (same subject+date+time for exams, or day+time+unit for classes) will be skipped.'
        )
        self._dup_progress.setVisible(False)
        self._next_btn.setEnabled(selected > 0)

    # ── Upload ─────────────────────────────────────────────────────

    def _do_upload(self):
        to_upload = self._preview_table.get_selected_entries()

        if not to_upload:
            self._upload_status.setText('Nothing to upload')
            self._upload_detail.setText('All entries were duplicates or none were selected.')
            self._next_btn.setEnabled(False)
            return

        self._upload_progress.setVisible(True)
        self._upload_progress.setMaximum(0)
        self._next_btn.setEnabled(False)

        def _worker():
            try:
                db = FirestoreClient.get()
                total = 0
                by_class: dict[str, int] = {}
                errors: list[str] = []

                for group_name, indices in self._class_groups.items():
                    class_id = group_name if group_name != 'All Entries' else (
                        self._class_override.currentText().strip() or 'Unspecified'
                    )
                    if class_id not in self._available_classes:
                        for av_cls in self._available_classes:
                            if class_id.lower() in av_cls.lower() or av_cls.lower() in class_id.lower():
                                class_id = av_cls
                                break

                    group_entries = [
                        self._parsed_entries[i] for i in indices
                        if i < len(self._parsed_entries) and i not in self._duplicate_indices
                    ]
                    if not group_entries:
                        continue

                    try:
                        if self._mode == 'exam':
                            count = db.upload_exam_timetable_batch(class_id, group_entries, replace=self._clear_existing)
                        else:
                            count = db.upload_timetable_batch(class_id, group_entries, replace=self._clear_existing)
                        by_class[class_id] = by_class.get(class_id, 0) + count
                        total += count
                    except Exception as e:
                        errors.append(f'{class_id}: {e}')

                self._upload_result = (total, by_class, errors, None)
            except Exception as e:
                self._upload_result = (0, {}, [str(e)], e)

            QTimer.singleShot(0, self._on_upload_done)

        self._upload_result = None
        threading.Thread(target=_worker, daemon=True).start()

    def _on_upload_done(self):
        if self._upload_result is None:
            QTimer.singleShot(50, self._on_upload_done)
            return

        total, by_class, errors, exception = self._upload_result
        self._upload_progress.setVisible(False)

        parts = [f'{total} entries uploaded']
        if self._clear_existing:
            parts.append(' (replaced existing data)')
        if by_class:
            parts.append(' (' + ', '.join(f'{k}: {v}' for k, v in by_class.items()) + ')')
        if self._newly_created_classes:
            parts.append(f'\nCreated {len(self._newly_created_classes)} new classes')
        if errors:
            err_text = '; '.join(errors[:5])
            parts.append(f'\nErrors: {err_text}')

        if exception:
            self._upload_status.setText('Upload Failed')
            self._upload_detail.setText(''.join(parts))
        else:
            self._upload_status.setText('Upload Complete!')
            self._upload_detail.setText(''.join(parts))
        self._next_btn.setEnabled(False)
