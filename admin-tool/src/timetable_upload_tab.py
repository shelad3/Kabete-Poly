# SPDX-License-Identifier: AGPL-3.0-or-Later
# Copyright (C) 2026 Kabete National Polytechnique

"""Timetable Upload Tab — redesigned with mode selector, parse-all, class selection, duplicate detection."""

import os
import re
import threading
from collections import defaultdict

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFileDialog, QComboBox, QStackedWidget, QProgressBar,
    QMessageBox, QGroupBox, QRadioButton, QButtonGroup,
    QCheckBox, QScrollArea,
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QFont

from firestore_client import FirestoreClient
from preview_table_widget import PreviewTableWidget


class TimetableUploadTab(QWidget):
    """Step-by-step timetable upload wizard with mode select, class grouping, duplicate check."""

    STEPS = ['Select Mode', 'Select File', 'Parse', 'Preview & Select', 'Verify Duplicates', 'Upload']

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
        self._build_ui()

    def _build_ui(self):
        outer = QVBoxLayout(self)

        # Step indicator
        self._step_label = QLabel('Step 1 of 6: Select Mode')
        self._step_label.setStyleSheet('font-size: 16px; font-weight: bold; color: #1A237E; padding: 8px;')
        outer.addWidget(self._step_label)

        self._progress_bar = QProgressBar()
        self._progress_bar.setMaximum(6)
        self._progress_bar.setValue(1)
        self._progress_bar.setTextVisible(True)
        self._progress_bar.setFormat('Step %v of 6')
        outer.addWidget(self._progress_bar)

        # Stack for wizard steps
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self._stack = QStackedWidget()
        scroll.setWidget(self._stack)
        outer.addWidget(scroll)

        # Step 0: Mode selection
        self._step0 = self._build_step0()
        self._stack.addWidget(self._step0)

        # Step 1: File selection
        self._step1 = self._build_step1()
        self._stack.addWidget(self._step1)

        # Step 2: Parsing
        self._step2 = self._build_step2()
        self._stack.addWidget(self._step2)

        # Step 3: Preview & Select
        self._step3 = self._build_step3()
        self._stack.addWidget(self._step3)

        # Step 4: Verify duplicates
        self._step4 = self._build_step4()
        self._stack.addWidget(self._step4)

        # Step 5: Upload complete
        self._step5 = self._build_step5()
        self._stack.addWidget(self._step5)

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
        layout.addWidget(QLabel('You can select/deselect specific classes in the next step.'))

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

    def _build_step3(self) -> QWidget:
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

    def _build_step4(self) -> QWidget:
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

    def _build_step5(self) -> QWidget:
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
            self._on_mode_changed()  # ensure mode is set
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
            if self._clear_existing:
                # Replace mode: skip duplicate check, go straight to upload
                self._do_upload()
                self._current_step = 5
                self._stack.setCurrentIndex(5)
                self._progress_bar.setValue(6)
                self._step_label.setText(f'Step 6 of 6: {self.STEPS[5]}')
                self._back_btn.setEnabled(False)
                self._next_btn.setText('Finish')
                self._next_btn.setEnabled(False)
                return
            else:
                self._start_dup_check()
        elif self._current_step == 4:
            self._do_upload()

        if self._current_step < 5:
            self._current_step += 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 6: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0 and self._current_step < 5)
            if self._current_step == 5:
                self._next_btn.setText('Finish')
                self._next_btn.setEnabled(False)

    def _go_back(self):
        if self._current_step > 0:
            self._current_step -= 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 6: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0 and self._current_step < 5)
            self._next_btn.setText('Next →')
            self._next_btn.setEnabled(True)

    def _reset(self):
        self._current_step = 0
        self._parsed_entries = []
        self._class_groups = {}
        self._duplicate_indices.clear()
        self._file_path = ''
        self._clear_existing = False
        self._file_display.setText('No file selected')
        self._preview_table.clear_data()
        self._stack.setCurrentIndex(0)
        self._progress_bar.setValue(1)
        self._step_label.setText(f'Step 1 of 6: {self.STEPS[0]}')
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
            self._file_display.setText(f'📄 {name}')
            self._file_display.setStyleSheet(
                'padding: 20px; background: #E8F5E9; border: 2px solid #4CAF50; font-size: 14px;'
            )
            # Auto-detect class from filename
            class_hint = self._detect_class_from_filename(name)
            if class_hint:
                self._class_hint.setText(f'Hint: detected class "{class_hint}" from filename')
                self._class_override.setCurrentText(class_hint)

    def _detect_class_from_filename(self, name: str) -> str:
        name_no_ext = os.path.splitext(name)[0]
        # Match patterns like "ICT-1A", "DIT-2B", "EE-3A", etc.
        m = re.search(r'([A-Z]{2,4}\s*-?\s*\d[A-Z])', name_no_ext, re.IGNORECASE)
        if m:
            return m.group(1).upper()
        # Try uppercase letter/dash patterns
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

            # Build class groups from parsed data
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

            # Enable advance if we have entries
            if len(result.entries) > 0:
                # Auto-advance to preview
                self._show_preview()
                self._current_step += 1
                self._stack.setCurrentIndex(self._current_step)
                self._progress_bar.setValue(self._current_step + 1)
                self._step_label.setText(f'Step {self._current_step + 1} of 6: {self.STEPS[self._current_step]}')
                self._back_btn.setEnabled(True)
                self._next_btn.setEnabled(True)
            else:
                self._next_btn.setEnabled(False)

        except Exception as e:
            self._parse_status.setText('Parsing failed')
            self._parse_detail.setText(str(e))
            import traceback
            self._parse_detail.setText(traceback.format_exc())

    def _build_class_groups(self, result) -> dict[str, list[int]]:
        """Group parsed entries by detected class."""
        groups = defaultdict(list)

        # Check if entries have class_id from multi-cohort parser
        has_class_ids = any(e.get('class_id') for e in self._parsed_entries)

        if has_class_ids:
            # Group by class_id embedded in each entry
            for i, entry in enumerate(self._parsed_entries):
                cls = entry.get('class_id', '').strip().upper()
                if cls:
                    groups[cls].append(i)
                else:
                    groups['Unspecified'].append(i)
            return dict(groups)

        # Use class_id from result header
        detected_class = getattr(result, 'class_id', '') or ''

        # For CSV with class_id column, group by that
        if hasattr(result, 'headers') and result.headers:
            class_col_idx = None
            for i, h in enumerate(result.headers):
                if h.lower() in ('class', 'class id', 'classid', 'group', 'cohort'):
                    class_col_idx = i
                    break
            if class_col_idx is not None:
                from csv import reader as csv_reader
                from io import StringIO
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

        # If no class column grouping, use detected header or file name
        if not groups:
            if detected_class:
                groups[detected_class] = list(range(len(self._parsed_entries)))
            else:
                # Try extra class_id field on entries
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

    def _show_preview(self):
        """Populate the preview table with parsed data."""
        # Populate class override combo
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

    def _start_dup_check(self):
        if self._clear_existing:
            # Skip duplicate check in replace mode — we're deleting everything first
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
