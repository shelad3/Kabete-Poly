# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Exam Timetable management tab for the admin tool."""

from datetime import datetime

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QTableWidget, QTableWidgetItem, QComboBox, QHeaderView,
    QMessageBox, QDialog, QFormLayout, QLineEdit, QDialogButtonBox,
    QGroupBox, QDateEdit,
)
from PyQt6.QtCore import Qt, QDate
from PyQt6.QtGui import QColor

from firestore_client import FirestoreClient
from models import ExamTimetableEntry


EXAM_TYPES = ['final', 'midterm', 'cat', 'practical']


class ExamTimetableTab(QWidget):
    """CRUD management for exam timetable entries."""

    def __init__(self):
        super().__init__()
        self._classes: list[str] = []
        self._entries: list[ExamTimetableEntry] = []
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout(self)

        # Top bar
        top = QHBoxLayout()
        top.addWidget(QLabel('Class:'))
        self._class_combo = QComboBox()
        self._class_combo.setMinimumWidth(250)
        self._class_combo.currentTextChanged.connect(self._load_entries)
        top.addWidget(self._class_combo)

        self._refresh_btn = QPushButton('Refresh')
        self._refresh_btn.clicked.connect(self._load_entries)
        top.addWidget(self._refresh_btn)

        self._add_btn = QPushButton('+ Add Entry')
        self._add_btn.clicked.connect(self._add_entry)
        self._add_btn.setStyleSheet('background-color: #4CAF50; color: white; padding: 5px 15px;')
        top.addWidget(self._add_btn)
        top.addStretch()
        layout.addLayout(top)

        # Table
        self._table = QTableWidget()
        self._table.setColumnCount(9)
        self._table.setHorizontalHeaderLabels([
            'Date', 'Subject', 'Type', 'Start', 'End', 'Room', 'Teacher', 'Description', 'Actions'
        ])
        self._table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setAlternatingRowColors(True)
        layout.addWidget(self._table)

    def refresh_classes(self, classes: list[str]):
        self._classes = classes
        current = self._class_combo.currentText()
        self._class_combo.blockSignals(True)
        self._class_combo.clear()
        self._class_combo.addItems(classes)
        if current in classes:
            self._class_combo.setCurrentText(current)
        self._class_combo.blockSignals(False)

    def set_class(self, class_id: str):
        self._class_combo.setCurrentText(class_id)

    def refresh(self):
        self._load_entries()

    def _load_entries(self):
        class_id = self._class_combo.currentText()
        if not class_id:
            return
        try:
            db = FirestoreClient.get()
            self._entries = db.get_exam_timetable(class_id)
            self._populate_table()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load exam timetable:\n{e}')

    def _populate_table(self):
        self._table.setRowCount(len(self._entries))
        for row, entry in enumerate(self._entries):
            items = [
                entry.date,
                entry.subject,
                entry.exam_type.capitalize(),
                entry.start_time,
                entry.end_time,
                entry.room,
                entry.teacher,
                entry.description[:40] + '...' if len(entry.description) > 40 else entry.description,
                '',
            ]
            for col, text in enumerate(items):
                item = QTableWidgetItem(text)
                if col == 2:  # Type column
                    color_map = {'Final': '#F44336', 'Midterm': '#FF9800', 'Cat': '#4CAF50', 'Practical': '#2196F3'}
                    c = color_map.get(text, '#9E9E9E')
                    item.setBackground(QColor(c))
                    item.setForeground(QColor('#FFFFFF'))
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self._table.setItem(row, col, item)

            # Action buttons
            edit_btn = QPushButton('Edit')
            edit_btn.setStyleSheet('background-color: #FF9800; color: white; padding: 3px 8px;')
            edit_btn.clicked.connect(lambda checked, r=row: self._edit_entry(r))
            delete_btn = QPushButton('Delete')
            delete_btn.setStyleSheet('background-color: #F44336; color: white; padding: 3px 8px;')
            delete_btn.clicked.connect(lambda checked, r=row: self._delete_entry(r))
            action_widget = QWidget()
            action_layout = QHBoxLayout(action_widget)
            action_layout.setContentsMargins(2, 2, 2, 2)
            action_layout.addWidget(edit_btn)
            action_layout.addWidget(delete_btn)
            self._table.setCellWidget(row, 8, action_widget)

    def _add_entry(self):
        class_id = self._class_combo.currentText()
        if not class_id:
            QMessageBox.warning(self, 'No Class', 'Please select a class first.')
            return
        dialog = ExamEntryDialog(self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            entry = dialog.get_entry()
            entry.class_id = class_id
            try:
                db = FirestoreClient.get()
                db.add_exam_timetable_entry(class_id, entry)
                self._load_entries()
            except Exception as e:
                QMessageBox.critical(self, 'Error', str(e))

    def _edit_entry(self, row: int):
        if row < 0 or row >= len(self._entries):
            return
        entry = self._entries[row]
        dialog = ExamEntryDialog(self, entry)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            updated = dialog.get_entry()
            updated.doc_id = entry.doc_id
            updated.class_id = entry.class_id
            try:
                db = FirestoreClient.get()
                db.update_exam_timetable_entry(entry.class_id, updated)
                self._load_entries()
            except Exception as e:
                QMessageBox.critical(self, 'Error', str(e))

    def _delete_entry(self, row: int):
        if row < 0 or row >= len(self._entries):
            return
        entry = self._entries[row]
        reply = QMessageBox.question(
            self, 'Confirm Delete',
            f'Delete exam: {entry.subject} on {entry.date}?',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        try:
            db = FirestoreClient.get()
            db.delete_exam_timetable_entry(entry.class_id, entry.doc_id)
            self._load_entries()
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))


class ExamEntryDialog(QDialog):
    """Dialog for adding/editing an exam timetable entry."""

    def __init__(self, parent=None, entry: ExamTimetableEntry | None = None):
        super().__init__(parent)
        self._entry = entry
        self.setWindowTitle('Edit Exam Entry' if entry else 'Add Exam Entry')
        self.resize(400, 350)
        self._build_ui()
        if entry:
            self._populate(entry)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self._subject = QLineEdit()
        form.addRow('Subject:', self._subject)

        self._teacher = QLineEdit()
        form.addRow('Teacher:', self._teacher)

        self._room = QLineEdit()
        form.addRow('Room:', self._room)

        self._date = QDateEdit()
        self._date.setCalendarPopup(True)
        self._date.setDate(QDate.currentDate())
        form.addRow('Date:', self._date)

        self._start_time = QLineEdit('08:00')
        form.addRow('Start Time (HH:MM):', self._start_time)

        self._end_time = QLineEdit('10:00')
        form.addRow('End Time (HH:MM):', self._end_time)

        self._type_combo = QComboBox()
        self._type_combo.addItems([t.capitalize() for t in EXAM_TYPES])
        form.addRow('Type:', self._type_combo)

        self._description = QLineEdit()
        form.addRow('Description:', self._description)

        layout.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.validate)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _populate(self, entry: ExamTimetableEntry):
        self._subject.setText(entry.subject)
        self._teacher.setText(entry.teacher)
        self._room.setText(entry.room)
        try:
            d = QDate.fromString(entry.date, 'yyyy-MM-dd')
            if d.isValid():
                self._date.setDate(d)
        except Exception:
            pass
        self._start_time.setText(entry.start_time)
        self._end_time.setText(entry.end_time)
        idx = self._type_combo.findText(entry.exam_type.capitalize())
        if idx >= 0:
            self._type_combo.setCurrentIndex(idx)
        self._description.setText(entry.description)

    def validate(self):
        if not self._subject.text().strip():
            QMessageBox.warning(self, 'Required', 'Subject is required.')
            return
        if not self._room.text().strip():
            QMessageBox.warning(self, 'Required', 'Room is required.')
            return
        self.accept()

    def get_entry(self) -> ExamTimetableEntry:
        date = self._date.date().toString('yyyy-MM-dd')
        return ExamTimetableEntry(
            class_id='',
            subject=self._subject.text().strip(),
            teacher=self._teacher.text().strip(),
            room=self._room.text().strip(),
            date=date,
            start_time=self._start_time.text().strip() or '00:00',
            end_time=self._end_time.text().strip() or '00:00',
            exam_type=self._type_combo.currentText().lower(),
            description=self._description.text().strip(),
        )
