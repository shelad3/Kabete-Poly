# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Preview table widget for displaying parsed timetable data with color coding."""

from PyQt6.QtWidgets import QTableWidget, QTableWidgetItem, QHeaderView
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QFont


# Status colors
COLOR_NEW = QColor('#E8F5E9')       # green tint — new entry
COLOR_CONFLICT = QColor('#FFF3E0')   # orange tint — conflicts with existing
COLOR_ERROR = QColor('#FFEBEE')      # red tint — parse error
COLOR_UNCHANGED = QColor('#F5F5F5')  # grey tint — matches existing


class PreviewTableWidget(QTableWidget):
    """A styled read-only table showing parsed timetable entries with status indicators."""

    COLUMNS = ['Status', 'Day', 'Time', 'End Time', 'Unit', 'Venue', 'Lecturer', 'Note']

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setColumnCount(len(self.COLUMNS))
        self.setHorizontalHeaderLabels(self.COLUMNS)
        self.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.horizontalHeader().setStretchLastSection(True)
        self.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.setAlternatingRowColors(True)
        self.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)

    def populate(self, entries: list[dict], conflicts: set[str] = None):
        """Populate with entries. Conflicts is a set of 'day|time|unit' strings."""
        conflicts = conflicts or set()
        self.setRowCount(len(entries))

        for row, entry in enumerate(entries):
            key = f"{entry.get('day', '')}|{entry.get('time', '')}|{entry.get('unit', '')}"
            has_conflict = key in conflicts
            is_empty = not entry.get('day') and not entry.get('unit')

            status = '⚠ CONFLICT' if has_conflict else ('✗ SKIPPED' if is_empty else '✓ OK')
            note = 'Room/lecturer conflict' if has_conflict else ('Missing data' if is_empty else '')

            bg = COLOR_CONFLICT if has_conflict else (COLOR_ERROR if is_empty else COLOR_NEW)

            row_data = [
                status,
                entry.get('day', ''),
                entry.get('time', ''),
                entry.get('endTime', ''),
                entry.get('unit', ''),
                entry.get('venue', ''),
                entry.get('lecturer', ''),
                note,
            ]

            for col, text in enumerate(row_data):
                item = QTableWidgetItem(text)
                item.setBackground(bg)
                if has_conflict:
                    item.setFont(QFont('Segoe UI', 10, QFont.Weight.Bold))
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.setItem(row, col, item)

    def clear_data(self):
        self.setRowCount(0)
