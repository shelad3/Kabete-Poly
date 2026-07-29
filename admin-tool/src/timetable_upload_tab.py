# SPDX-License-Identifier: AGPL-3.0-or-Later
# Copyright (C) 2026 Kabete National Polytechnique

"""Timetable Upload Tab — wizard-based upload of PDF/CSV timetable files."""

import os

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFileDialog, QComboBox, QStackedWidget, QProgressBar,
    QMessageBox, QGroupBox, QGridLayout, QCheckBox,
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QFont

from firestore_client import FirestoreClient
from preview_table_widget import PreviewTableWidget
from verification_dialog import VerificationDialog


class TimetableUploadTab(QWidget):
    """Step-by-step timetable upload wizard."""

    STEPS = ['Select File', 'Parse', 'Preview', 'Verify', 'Upload']

    def __init__(self):
        super().__init__()
        self._classes: list[str] = []
        self._parsed_entries: list[dict] = []
        self._existing_entries: list[dict] = []
        self._file_path: str = ''
        self._class_id: str = ''
        self._build_ui()

    def _build_ui(self):
        outer = QVBoxLayout(self)

        # Step indicator
        self._step_label = QLabel('Step 1 of 5: Select File')
        self._step_label.setStyleSheet('font-size: 16px; font-weight: bold; color: #1A237E; padding: 8px;')
        outer.addWidget(self._step_label)

        self._progress_bar = QProgressBar()
        self._progress_bar.setMaximum(5)
        self._progress_bar.setValue(1)
        self._progress_bar.setTextVisible(True)
        self._progress_bar.setFormat('Step %v of 5')
        outer.addWidget(self._progress_bar)

        # Stack for wizard steps
        self._stack = QStackedWidget()
        outer.addWidget(self._stack)

        # Step 1: File selection
        self._step1 = self._build_step1()
        self._stack.addWidget(self._step1)

        # Step 2: Parsing (auto)
        self._step2 = self._build_step2()
        self._stack.addWidget(self._step2)

        # Step 3: Preview
        self._step3 = self._build_step3()
        self._stack.addWidget(self._step3)

        # Step 4: Verify (conflict dialog triggered separately)
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
        self._classes = classes
        self._class_combo.clear()
        self._class_combo.addItems(classes)

    # ── Step Builders ──────────────────────────────────────────────

    def _build_step1(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(QLabel('Select a timetable file (PDF or CSV):'))
        layout.addSpacing(10)

        self._file_display = QLabel('No file selected')
        self._file_display.setStyleSheet('padding: 20px; background: #f0f0f0; border: 2px dashed #ccc; font-size: 14px;')
        self._file_display.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self._file_display)

        browse_btn = QPushButton('Browse Files...')
        browse_btn.clicked.connect(self._browse_file)
        browse_btn.setStyleSheet('padding: 10px 20px; font-size: 14px;')
        layout.addWidget(browse_btn)

        layout.addSpacing(20)
        layout.addWidget(QLabel('Target Class:'))
        self._class_combo = QComboBox()
        self._class_combo.setMinimumWidth(300)
        layout.addWidget(self._class_combo)

        self._replace_cb = QCheckBox('Replace existing timetable (delete all existing entries)')
        self._replace_cb.setStyleSheet('font-size: 12px;')
        layout.addWidget(self._replace_cb)

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
        self._parse_progress.setRange(0, 0)  # indeterminate
        layout.addWidget(self._parse_progress)

        layout.addStretch()
        return w

    def _build_step3(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.addWidget(QLabel('Preview of parsed entries:'))
        self._preview_table = PreviewTableWidget()
        layout.addWidget(self._preview_table)

        self._preview_summary = QLabel('')
        self._preview_summary.setStyleSheet('font-weight: bold;')
        layout.addWidget(self._preview_summary)
        return w

    def _build_step4(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._verify_status = QLabel('Verification complete.')
        self._verify_status.setStyleSheet('font-size: 16px;')
        layout.addWidget(self._verify_status)
        self._verify_detail = QLabel('')
        layout.addWidget(self._verify_detail)
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
        self._upload_again_btn = QPushButton('Upload Another File')
        self._upload_again_btn.clicked.connect(self._reset)
        self._upload_again_btn.setStyleSheet('padding: 10px 20px;')
        layout.addWidget(self._upload_again_btn, alignment=Qt.AlignmentFlag.AlignCenter)
        layout.addStretch()
        return w

    # ── Navigation ─────────────────────────────────────────────────

    def _go_next(self):
        if self._current_step == 0:
            if not self._validate_step1():
                return
            self._start_parsing()
        elif self._current_step == 1:
            self._show_preview()
        elif self._current_step == 2:
            self._show_verification()
        elif self._current_step == 3:
            self._do_upload()

        if self._current_step < 4:
            self._current_step += 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 5: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0)
            if self._current_step == 4:
                self._next_btn.setText('Finish')
                self._next_btn.setEnabled(False)

    def _go_back(self):
        if self._current_step > 0:
            self._current_step -= 1
            self._stack.setCurrentIndex(self._current_step)
            self._progress_bar.setValue(self._current_step + 1)
            self._step_label.setText(f'Step {self._current_step + 1} of 5: {self.STEPS[self._current_step]}')
            self._back_btn.setEnabled(self._current_step > 0)
            self._next_btn.setText('Next →')
            self._next_btn.setEnabled(True)

    def _reset(self):
        self._current_step = 0
        self._parsed_entries = []
        self._existing_entries = []
        self._file_path = ''
        self._file_display.setText('No file selected')
        self._preview_table.clear_data()
        self._stack.setCurrentIndex(0)
        self._progress_bar.setValue(1)
        self._step_label.setText(f'Step 1 of 5: {self.STEPS[0]}')
        self._back_btn.setEnabled(False)
        self._next_btn.setText('Next →')
        self._next_btn.setEnabled(True)

    # ── Validation ─────────────────────────────────────────────────

    def _validate_step1(self) -> bool:
        if not self._file_path:
            QMessageBox.warning(self, 'No File', 'Please select a file first.')
            return False
        if not os.path.exists(self._file_path):
            QMessageBox.warning(self, 'Invalid File', 'Selected file does not exist.')
            return False
        self._class_id = self._class_combo.currentText()
        if not self._class_id:
            QMessageBox.warning(self, 'No Class', 'Please select a target class.')
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

    def _start_parsing(self):
        self._parse_status.setText('Parsing file...')
        self._parse_detail.setText(f'File: {os.path.basename(self._file_path)}')
        # Use a timer to allow UI to update
        QTimer.singleShot(100, self._do_parse)

    def _do_parse(self):
        try:
            ext = os.path.splitext(self._file_path)[1].lower()
            if ext == '.csv':
                from csv_parser import CsvTimetableParser
                parser = CsvTimetableParser()
                result = parser.parse(self._file_path)
            elif ext == '.pdf':
                from pdf_parser import PdfTimetableParser
                parser = PdfTimetableParser()
                result = parser.parse(self._file_path)
            else:
                self._parse_status.setText('Error: Unsupported file format.')
                return

            if result.errors:
                self._parse_status.setText('Parsing completed with errors')
                error_text = '\n'.join(result.errors[:5])
                self._parse_detail.setText(f'Errors:\n{error_text}')
                # Still proceed with what we have
            else:
                self._parse_status.setText('Parsing successful!')

            self._parsed_entries = result.entries
            self._parse_detail.setText(
                f'Found {len(result.entries)} entries, {len(result.errors)} errors\n'
                + (f'Detected class: {result.class_id}' if hasattr(result, 'class_id') and result.class_id else '')
            )

            # Enable next button to proceed
            self._next_btn.setEnabled(len(result.entries) > 0)

        except Exception as e:
            self._parse_status.setText('Parsing failed')
            self._parse_detail.setText(str(e))
            import traceback
            self._parse_detail.setText(traceback.format_exc())

    def _show_preview(self):
        self._preview_table.populate(self._parsed_entries)
        self._preview_summary.setText(f'Total: {len(self._parsed_entries)} entries parsed')
        self._next_btn.setEnabled(True)

    def _show_verification(self):
        try:
            db = FirestoreClient.get()
            self._existing_entries = db.get_existing_timetable(self._class_id)

            if not self._existing_entries:
                self._verify_status.setText('No existing timetable — no conflicts detected.')
                self._verify_detail.setText(f'Ready to upload {len(self._parsed_entries)} new entries.')
                self._next_btn.setEnabled(True)
                return

            dialog = VerificationDialog(
                self._parsed_entries, self._existing_entries, self._class_id, self,
            )
            if dialog.exec() == VerificationDialog.Accepted:
                result = dialog.get_result()
                resolution = result['resolution']
                if resolution == 'skip':
                    # Remove conflicts from entries
                    conflict_keys = {
                        (c['day'], c['time'], c['unit'])
                        for c in result['conflicts']
                    }
                    self._parsed_entries = [
                        e for e in self._parsed_entries
                        if (e.get('day', ''), e.get('time', ''), e.get('unit', '')) not in conflict_keys
                    ]
                    self._verify_status.setText(f'Skipped {len(result["conflicts"])} conflicts.')
                elif resolution == 'overwrite':
                    self._verify_status.setText(f'Will overwrite {len(result["conflicts"])} conflicting entries.')
                else:
                    self._verify_status.setText(f'Merging — keeping existing, adding new.')
                self._verify_detail.setText(f'Final upload: {len(self._parsed_entries)} entries')
                self._next_btn.setEnabled(True)
            else:
                self._verify_status.setText('Verification cancelled.')
                self._next_btn.setEnabled(False)

        except Exception as e:
            self._verify_status.setText('Verification failed')
            self._verify_detail.setText(str(e))
            import traceback
            self._verify_detail.setText(traceback.format_exc())

    def _do_upload(self):
        try:
            db = FirestoreClient.get()
            replace = self._replace_cb.isChecked()
            count = db.upload_timetable_batch(self._class_id, self._parsed_entries, replace)
            self._upload_status.setText('Upload Complete!')
            self._upload_detail.setText(
                f'{count} timetable entries uploaded to {self._class_id}\n'
                + ('(existing entries were replaced)' if replace else '(existing entries preserved)')
            )
            self._next_btn.setEnabled(False)
        except Exception as e:
            self._upload_status.setText('Upload Failed')
            self._upload_detail.setText(str(e))
            import traceback
            self._upload_detail.setText(traceback.format_exc())
