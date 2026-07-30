# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Preview table widget for displaying parsed timetable data with selection & grouping."""

from PyQt6.QtWidgets import (
    QTableWidget, QTableWidgetItem, QHeaderView, QCheckBox,
    QWidget, QVBoxLayout, QLabel, QHBoxLayout,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QFont


COLOR_NEW = QColor('#E8F5E9')
COLOR_DUPLICATE = QColor('#FFF3E0')
COLOR_ERROR = QColor('#FFEBEE')
COLOR_SELECTED = QColor('#E3F2FD')
COLOR_GROUP_HEADER = QColor('#1A237E')


# Columns for each mode
CLASS_COLUMNS = ['', 'Day', 'Time', 'End Time', 'Unit', 'Venue', 'Lecturer', 'Status']
EXAM_COLUMNS = ['', 'Subject', 'Date', 'Start', 'End', 'Room', 'Teacher', 'Type', 'Status']


class PreviewTableWidget(QWidget):
    """Preview table with class-grouped rows, checkboxes, and duplicate indicators."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._mode = 'class'
        self._entries: list[dict] = []
        self._selected: set[int] = set()
        self._duplicates: set[int] = set()
        self._class_groups: dict[str, list[int]] = {}
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self._summary = QLabel('')
        self._summary.setStyleSheet('font-weight: bold; padding: 4px;')
        layout.addWidget(self._summary)

        self._table = QTableWidget()
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setAlternatingRowColors(True)
        self._table.verticalHeader().setVisible(False)
        layout.addWidget(self._table)

    def set_mode(self, mode: str):
        self._mode = mode
        cols = EXAM_COLUMNS if mode == 'exam' else CLASS_COLUMNS
        self._table.setColumnCount(len(cols))
        self._table.setHorizontalHeaderLabels(cols)
        self._table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setStretchLastSection(True)

    def populate(self, entries: list[dict], duplicates: set[int] = None, class_groups: dict[str, list[int]] = None):
        self._entries = entries
        self._duplicates = duplicates or set()
        self._class_groups = class_groups or {}
        self._selected = set(range(len(entries)))  # all selected by default

        # Count groups
        if not self._class_groups:
            self._class_groups = {'All Entries': list(range(len(entries)))}

        row_count = len(entries) + len(self._class_groups)  # extra rows for group headers
        self._table.setRowCount(0)
        self._table.setRowCount(row_count)

        current_row = 0
        for group_name, indices in self._class_groups.items():
            # Group header row
            self._set_group_header(current_row, group_name, len(indices))
            current_row += 1
            for idx in indices:
                if idx >= len(entries):
                    continue
                self._populate_row(current_row, entries[idx], idx)
                current_row += 1

        self._update_summary()

    def _set_group_header(self, row: int, name: str, count: int):
        cols = EXAM_COLUMNS if self._mode == 'exam' else CLASS_COLUMNS
        self._table.setRowHeight(row, 32)
        item = QTableWidgetItem(f'  {name}  ({count} entries)')
        item.setBackground(COLOR_GROUP_HEADER)
        item.setForeground(QColor('#FFFFFF'))
        font = QFont('Segoe UI', 11, QFont.Weight.Bold)
        item.setFont(font)
        item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
        self._table.setItem(row, 0, item)
        for col in range(1, len(cols)):
            empty = QTableWidgetItem('')
            empty.setBackground(COLOR_GROUP_HEADER)
            empty.setFlags(empty.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self._table.setItem(row, col, empty)

    def _populate_row(self, row: int, entry: dict, idx: int):
        is_dup = idx in self._duplicates
        is_sel = idx in self._selected
        cols = EXAM_COLUMNS if self._mode == 'exam' else CLASS_COLUMNS

        # Checkbox
        cb = QCheckBox()
        cb.setChecked(is_sel and not is_dup)
        cb.setEnabled(not is_dup)
        cb.stateChanged.connect(lambda state, i=idx: self._toggle_selection(i, state))
        cb_widget = QWidget()
        cb_layout = QHBoxLayout(cb_widget)
        cb_layout.setContentsMargins(8, 0, 0, 0)
        cb_layout.addWidget(cb)
        cb_layout.addStretch()
        self._table.setCellWidget(row, 0, cb_widget)

        if is_dup:
            bg = COLOR_DUPLICATE
        elif is_sel:
            bg = COLOR_SELECTED
        else:
            bg = QColor('#FFFFFF')

        if self._mode == 'exam':
            row_data = [
                entry.get('subject', ''),
                entry.get('date', ''),
                entry.get('startTime', ''),
                entry.get('endTime', ''),
                entry.get('room', ''),
                entry.get('teacher', ''),
                entry.get('type', ''),
                'DUPLICATE' if is_dup else ('SELECTED' if is_sel else 'SKIPPED'),
            ]
        else:
            row_data = [
                entry.get('day', ''),
                entry.get('time', ''),
                entry.get('endTime', ''),
                entry.get('unit', ''),
                entry.get('venue', ''),
                entry.get('lecturer', ''),
                'DUPLICATE' if is_dup else ('SELECTED' if is_sel else 'SKIPPED'),
            ]

        for col, text in enumerate(row_data):
            item = QTableWidgetItem(text)
            item.setBackground(bg)
            if is_dup:
                item.setFont(QFont('Segoe UI', 10, QFont.Weight.Bold))
            item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self._table.setItem(row, col + 1, item)

    def _toggle_selection(self, idx: int, state: int):
        if state == Qt.CheckState.Checked.value:
            self._selected.add(idx)
        else:
            self._selected.discard(idx)
        self._update_summary()

    def _update_summary(self):
        total = len(self._entries)
        sel = len(self._selected)
        dups = len(self._duplicates)
        self._summary.setText(
            f'Total: {total} entries  |  Selected: {sel}  |  '
            f'Duplicates: {dups}  |  To upload: {sel - sum(1 for i in self._selected if i in self._duplicates)}'
        )

    def get_selected_entries(self) -> list[dict]:
        return [self._entries[i] for i in sorted(self._selected) if i not in self._duplicates]

    def get_all_entry_indices(self) -> list[int]:
        return list(range(len(self._entries)))

    def set_duplicates(self, dup_indices: set[int]):
        self._duplicates = dup_indices
        self._selected -= dup_indices

    def clear_data(self):
        self._entries = []
        self._selected.clear()
        self._duplicates.clear()
        self._class_groups.clear()
        self._table.setRowCount(0)
        self._summary.setText('')
