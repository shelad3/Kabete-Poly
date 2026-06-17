from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QLabel, QComboBox, QLineEdit, QHeaderView, QMessageBox,
    QColorDialog, QProgressDialog, QFormLayout, QGroupBox, QApplication,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor

from firestore_client import FirestoreClient
from models import TimetableEntry
from csv_import_dialog import CsvImportDialog, FieldDef

DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
COLORS = {
    'Indigo (default)': 0xFF1A237E,
    'Blue': 0xFF1565C0,
    'Red': 0xFFC62828,
    'Green': 0xFF2E7D32,
    'Orange': 0xFFEF6C00,
    'Purple': 0xFF6A1B9A,
    'Teal': 0xFF00695C,
}


class TimetableEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.db = FirestoreClient.get()
        self.current_class = ''
        self._entries: list[TimetableEntry] = []
        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)

        # Add Entry form
        form_group = QGroupBox('Add Timetable Entry')
        form_layout = QFormLayout(form_group)

        row1 = QHBoxLayout()
        self.day_combo = QComboBox()
        self.day_combo.addItems(DAYS)
        row1.addWidget(QLabel('Day:'))
        row1.addWidget(self.day_combo)

        self.time_input = QLineEdit()
        self.time_input.setPlaceholderText('e.g. 08:00 AM')
        row1.addWidget(QLabel('Time:'))
        row1.addWidget(self.time_input)

        layout.addLayout(row1)

        row2 = QHBoxLayout()
        self.unit_input = QLineEdit()
        self.unit_input.setPlaceholderText('e.g. Mathematics')
        row2.addWidget(QLabel('Unit:'))
        row2.addWidget(self.unit_input)

        self.room_input = QLineEdit()
        self.room_input.setPlaceholderText('e.g. Room 201')
        row2.addWidget(QLabel('Room:'))
        row2.addWidget(self.room_input)

        layout.addLayout(row2)

        row3 = QHBoxLayout()
        self.lecturer_input = QLineEdit()
        self.lecturer_input.setPlaceholderText('e.g. Dr. Smith')
        row3.addWidget(QLabel('Lecturer:'))
        row3.addWidget(self.lecturer_input)

        self.color_combo = QComboBox()
        self.color_combo.addItems(COLORS.keys())
        row3.addWidget(QLabel('Color:'))
        row3.addWidget(self.color_combo)

        row3.addStretch()
        self.add_btn = QPushButton('Add Entry')
        self.add_btn.clicked.connect(self._add_entry)
        self.add_btn.setStyleSheet('background-color: #2196F3; color: white; padding: 8px 16px;')
        row3.addWidget(self.add_btn)

        layout.addLayout(row3)
        layout.addWidget(form_group)

        # Action buttons
        btn_row = QHBoxLayout()
        self.refresh_btn = QPushButton('Refresh Entries')
        self.refresh_btn.clicked.connect(self._load_entries)
        self.refresh_btn.setEnabled(False)
        btn_row.addWidget(self.refresh_btn)

        self.import_csv_btn = QPushButton('Import CSV')
        self.import_csv_btn.clicked.connect(self._import_csv)
        self.import_csv_btn.setEnabled(False)
        self.import_csv_btn.setStyleSheet(
            'background-color: #FF8F00; color: white; padding: 8px 16px; font-weight: bold;'
        )
        btn_row.addWidget(self.import_csv_btn)

        btn_row.addStretch()
        layout.addLayout(btn_row)

        # Table
        self.table = QTableWidget()
        self.table.setColumnCount(6)
        self.table.setHorizontalHeaderLabels(['Day', 'Time', 'Unit', 'Room', 'Lecturer', 'Delete'])
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.table.setAlternatingRowColors(True)
        layout.addWidget(self.table)

    # ---- Public API ----

    def refresh_classes(self, classes: list[str]):
        self._entries.clear()
        self.table.setRowCount(0)

    def set_class(self, class_id: str):
        self.current_class = class_id
        self.refresh_btn.setEnabled(bool(class_id))
        self.import_csv_btn.setEnabled(bool(class_id))
        if class_id:
            self._load_entries()
        else:
            self._entries.clear()
            self.table.setRowCount(0)

    # ---- Handlers ----

    def _load_entries(self):
        if not self.current_class:
            return

        progress = QProgressDialog('Loading timetable...', None, 0, 0, self)
        progress.setWindowTitle('Loading')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()  # type: ignore

        try:
            self._entries = self.db.get_timetable(self.current_class)
            self._populate_table()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load timetable:\n{e}')
        finally:
            progress.close()

    def _populate_table(self):
        self.table.blockSignals(True)
        self.table.setRowCount(len(self._entries))

        for row, entry in enumerate(self._entries):
            self.table.setItem(row, 0, QTableWidgetItem(entry.day))
            self.table.setItem(row, 1, QTableWidgetItem(entry.time))
            self.table.setItem(row, 2, QTableWidgetItem(entry.unit))
            self.table.setItem(row, 3, QTableWidgetItem(entry.room))
            self.table.setItem(row, 4, QTableWidgetItem(entry.lecturer))

            # Delete button
            delete_btn = QPushButton('✕')
            delete_btn.setStyleSheet('background-color: #F44336; color: white;')
            delete_btn.clicked.connect(lambda checked, r=row: self._delete_entry(r))
            self.table.setCellWidget(row, 5, delete_btn)

            # Color strip on day cell
            day_item = self.table.item(row, 0)
            if day_item:
                color = QColor(entry.color)
                day_item.setBackground(color)
                day_item.setForeground(Qt.GlobalColor.white)

        self.table.blockSignals(False)

    def _add_entry(self):
        if not self.current_class:
            QMessageBox.warning(self, 'No Class', 'Please select a class first.')
            return

        day = self.day_combo.currentText()
        time = self.time_input.text().strip()
        unit = self.unit_input.text().strip()
        room = self.room_input.text().strip()
        lecturer = self.lecturer_input.text().strip()
        color = COLORS[self.color_combo.currentText()]

        if not time:
            QMessageBox.warning(self, 'Missing Field', 'Please enter the time.')
            return
        if not unit:
            QMessageBox.warning(self, 'Missing Field', 'Please enter the unit name.')
            return

        entry = TimetableEntry(day=day, time=time, unit=unit, room=room, lecturer=lecturer, color=color)

        progress = QProgressDialog('Saving entry...', None, 0, 0, self)
        progress.setWindowTitle('Saving')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()  # type: ignore

        try:
            self.db.add_timetable_entry(self.current_class, entry)
            self.time_input.clear()
            self.unit_input.clear()
            self.room_input.clear()
            self.lecturer_input.clear()
            self._load_entries()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to save entry:\n{e}')
        finally:
            progress.close()

    def _import_csv(self):
        if not self.current_class:
            return

        fields = [
            FieldDef('day', 'Day', required=True),
            FieldDef('time', 'Time', required=True),
            FieldDef('unit', 'Unit', required=True),
            FieldDef('room', 'Room', default=''),
            FieldDef('lecturer', 'Lecturer', default=''),
            FieldDef('color', 'Color', default=0xFF1A237E, type_hint='int'),
        ]

        def checker(row):
            return self.db.timetable_entry_exists(
                self.current_class, row['day'], row['time'], row['unit'],
            )

        def importer(rows):
            cleaned = []
            for r in rows:
                cleaned.append({
                    'day': r['day'],
                    'time': r['time'],
                    'unit': r['unit'],
                    'room': r.get('room', ''),
                    'lecturer': r.get('lecturer', ''),
                    'color': int(r.get('color', 0xFF1A237E)),
                })
            count = self.db.import_timetable_batch(self.current_class, cleaned)
            self._load_entries()
            return count, ''

        dialog = CsvImportDialog(
            self, self.db, self.current_class, fields,
            checker, importer, title='Import Timetable CSV',
        )
        dialog.exec()

    def _delete_entry(self, row: int):
        if row < 0 or row >= len(self._entries):
            return

        entry = self._entries[row]
        reply = QMessageBox.question(
            self, 'Confirm Delete',
            f'Delete "{entry.unit}" on {entry.day} at {entry.time}?',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return

        progress = QProgressDialog('Deleting entry...', None, 0, 0, self)
        progress.setWindowTitle('Deleting')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()  # type: ignore

        try:
            self.db.delete_timetable_entry(self.current_class, entry.doc_id)
            self._entries.pop(row)
            self._populate_table()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to delete entry:\n{e}')
        finally:
            progress.close()


