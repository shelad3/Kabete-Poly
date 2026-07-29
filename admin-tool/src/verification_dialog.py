# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Conflict detection and resolution dialog for timetable upload."""

from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QTableWidget, QTableWidgetItem, QHeaderView, QGroupBox,
    QRadioButton, QButtonGroup, QMessageBox,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QFont


class VerificationDialog(QDialog):
    """Shows conflicts between parsed entries and existing timetable data."""

    def __init__(self, new_entries: list[dict], existing_entries: list[dict], class_id: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f'Verify Timetable — {class_id}')
        self.resize(800, 600)
        self._new_entries = new_entries
        self._existing_entries = existing_entries
        self._class_id = class_id
        self._resolution = 'merge'  # merge / overwrite / skip
        self._build_ui()
        self._analyze()

    def _build_ui(self):
        layout = QVBoxLayout(self)

        # Summary
        summary = QGroupBox('Summary')
        summary_layout = QVBoxLayout(summary)
        self._summary_label = QLabel('Analyzing...')
        self._summary_label.setStyleSheet('font-size: 14px;')
        summary_layout.addWidget(self._summary_label)
        layout.addWidget(summary)

        # Conflict table
        self._table = QTableWidget()
        self._table.setColumnCount(9)
        self._table.setHorizontalHeaderLabels([
            'Type', 'Day', 'Time', 'Unit', 'New Venue', 'Old Venue',
            'New Lecturer', 'Old Lecturer', 'Action'
        ])
        self._table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setStretchLastSection(True)
        layout.addWidget(self._table)

        # Resolution radio buttons
        resolve_group = QGroupBox('Default Resolution')
        resolve_layout = QHBoxLayout(resolve_group)
        self._resolve_group = QButtonGroup(self)
        merge_btn = QRadioButton('Merge (keep existing, add new)')
        merge_btn.setChecked(True)
        overwrite_btn = QRadioButton('Overwrite (replace existing)')
        skip_btn = QRadioButton('Skip conflicts')

        self._resolve_group.addButton(merge_btn, 1)
        self._resolve_group.addButton(overwrite_btn, 2)
        self._resolve_group.addButton(skip_btn, 3)
        self._resolve_group.buttonClicked.connect(self._on_resolution_changed)

        resolve_layout.addWidget(merge_btn)
        resolve_layout.addWidget(overwrite_btn)
        resolve_layout.addWidget(skip_btn)
        layout.addWidget(resolve_group)

        # Action buttons
        btn_row = QHBoxLayout()
        self._proceed_btn = QPushButton('Proceed to Upload')
        self._proceed_btn.setStyleSheet('background-color: #1A237E; color: white; padding: 10px 20px; font-size: 14px;')
        self._proceed_btn.clicked.connect(self.accept)
        btn_row.addStretch()
        btn_row.addWidget(self._proceed_btn)
        cancel_btn = QPushButton('Cancel')
        cancel_btn.clicked.connect(self.reject)
        btn_row.addWidget(cancel_btn)
        layout.addLayout(btn_row)

    def _analyze(self):
        """Detect conflicts between new and existing entries."""
        self._conflicts = []

        existing_map = {}  # (day, time, unit) -> [entries]
        for entry in self._existing_entries:
            key = (entry.get('day', ''), entry.get('time', ''), entry.get('unit', ''))
            existing_map.setdefault(key, []).append(entry)

        new_keys = set()
        for entry in self._new_entries:
            key = (entry.get('day', ''), entry.get('time', ''), entry.get('unit', ''))
            new_keys.add(key)

        # Check for conflicts
        duplicates = 0
        venue_conflicts = 0
        lecturer_conflicts = 0
        new_count = 0

        for entry in self._new_entries:
            key = (entry.get('day', ''), entry.get('time', ''), entry.get('unit', ''))
            existing = existing_map.get(key, [])

            if not existing and key not in {(e.get('day',''), e.get('time',''), e.get('unit','')) for e in self._new_entries}:
                new_count += 1
                continue

            conflict_type = ''
            for old in existing:
                if old.get('venue', '') != entry.get('venue', '') and old.get('venue', ''):
                    conflict_type = 'Venue conflict'
                    venue_conflicts += 1
                if old.get('lecturer', '') != entry.get('lecturer', '') and old.get('lecturer', ''):
                    conflict_type = 'Lecturer conflict'
                    lecturer_conflicts += 1
                if old.get('venue', '') == entry.get('venue', '') and old.get('lecturer', '') == entry.get('lecturer', ''):
                    conflict_type = 'Duplicate'
                    duplicates += 1

            if conflict_type:
                self._conflicts.append({
                    'type': conflict_type,
                    'day': entry.get('day', ''),
                    'time': entry.get('time', ''),
                    'unit': entry.get('unit', ''),
                    'new_venue': entry.get('venue', ''),
                    'old_venue': existing[0].get('venue', '') if existing else '',
                    'new_lecturer': entry.get('lecturer', ''),
                    'old_lecturer': existing[0].get('lecturer', '') if existing else '',
                })

        new_incoming = len(self._new_entries) - len(self._conflicts)
        self._summary_label.setText(
            f'Class: {self._class_id}  |  '
            f'New entries in file: {len(self._new_entries)}  |  '
            f'Existing: {len(self._existing_entries)}  |  '
            f'Conflicts: {len(self._conflicts)}  |  '
            f'New (no conflict): {new_incoming}  |  '
            f'Duplicates: {duplicates}'
        )

        self._populate_conflict_table()

    def _populate_conflict_table(self):
        self._table.setRowCount(len(self._conflicts))
        for row, c in enumerate(self._conflicts):
            items = [
                c['type'],
                c['day'],
                c['time'],
                c['unit'],
                c['new_venue'],
                c['old_venue'],
                c['new_lecturer'],
                c['old_lecturer'],
                'Resolve',
            ]
            for col, text in enumerate(items):
                item = QTableWidgetItem(text)
                if col == 0:
                    color_map = {'Venue conflict': '#FF9800', 'Lecturer conflict': '#F44336', 'Duplicate': '#9E9E9E'}
                    item.setBackground(QColor(color_map.get(c['type'], '#FFF')))
                    item.setForeground(QColor('#FFF'))
                    item.setFont(QFont('Segoe UI', 10, QFont.Weight.Bold))
                self._table.setItem(row, col, item)

    def _on_resolution_changed(self, btn):
        mapping = {1: 'merge', 2: 'overwrite', 3: 'skip'}
        self._resolution = mapping.get(self._resolve_group.id(btn), 'merge')

    def get_result(self) -> dict:
        return {
            'resolution': self._resolution,
            'conflicts': self._conflicts,
        }
