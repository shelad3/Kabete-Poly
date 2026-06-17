"""
CSV Import Dialog — column mapping + duplicate detection preview.
Works for both grades and timetable imports.
"""

import csv
from typing import Any, Callable

from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QLabel, QComboBox, QHeaderView, QMessageBox,
    QProgressDialog, QFileDialog, QApplication, QGroupBox, QFormLayout,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QBrush


class FieldDef:
    def __init__(self, name: str, label: str, required: bool = False,
                 default: Any = '', type_hint: str = 'str'):
        self.name = name
        self.label = label
        self.required = required
        self.default = default
        self.type_hint = type_hint


class CsvImportDialog(QDialog):
    """
    Generic CSV import dialog.
    - Loads CSV, shows preview with column mapping
    - Checks duplicates row-by-row
    - Returns selected rows via get_selected_data()

    Args:
        fields: FieldDef list describing Firestore fields
        duplicate_checker: callable(row_dict) -> True if duplicate
        importer: callable(rows_list) -> (count, success_message)
        context_fields: dict of field->value applied to every row (e.g. classId)
    """

    def __init__(self, parent, db, class_id: str,
                 fields: list[FieldDef],
                 duplicate_checker: Callable[[dict], bool],
                 importer: Callable[[list[dict]], tuple[int, str]],
                 context_fields: dict[str, Any] | None = None,
                 title: str = 'Import CSV'):
        super().__init__(parent)
        self.db = db
        self.class_id = class_id
        self.fields = fields
        self.duplicate_checker = duplicate_checker
        self.importer = importer
        self.context_fields = context_fields or {}

        self.rows: list[dict] = []
        self.column_names: list[str] = []
        self.mappings: dict[str, int] = {}
        self.duplicates: list[bool] = []
        self.checked: list[bool] = []

        self.setWindowTitle(title)
        self.resize(1000, 650)
        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)

        # ── File selection ──
        file_row = QHBoxLayout()
        self.file_label = QLabel('No file selected')
        self.file_label.setStyleSheet('color: #666;')
        browse_btn = QPushButton('Browse CSV...')
        browse_btn.clicked.connect(self._browse)
        file_row.addWidget(browse_btn)
        file_row.addWidget(self.file_label)
        file_row.addStretch()
        layout.addLayout(file_row)

        # ── Context info ──
        if self.context_fields:
            ctx = ' | '.join(f'{k}={v}' for k, v in self.context_fields.items())
            info = QLabel(f'Context: {ctx}')
            info.setStyleSheet('color: #1A237E; font-weight: bold; padding: 4px;')
            layout.addWidget(info)

        # ── Column mapping ──
        map_group = QGroupBox('Column Mapping')
        map_layout = QFormLayout(map_group)
        self.mapping_combos: dict[str, QComboBox] = {}
        for field in self.fields:
            if field.name in self.context_fields:
                continue
            combo = QComboBox()
            combo.addItem(f'-- Skip (default: {field.default}) --', -1)
            combo.currentIndexChanged.connect(self._update_preview)
            self.mapping_combos[field.name] = combo
            label = field.label + ' *' if field.required else field.label
            map_layout.addRow(label + ':', combo)
        layout.addWidget(map_group)

        # ── Summary ──
        self.summary_label = QLabel('')
        self.summary_label.setStyleSheet('font-weight: bold; padding: 4px;')
        layout.addWidget(self.summary_label)

        # ── Preview table ──
        self.table = QTableWidget()
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.setAlternatingRowColors(True)
        layout.addWidget(self.table)

        # ── Action buttons ──
        btn_row = QHBoxLayout()

        self.check_all_btn = QPushButton('Check All')
        self.check_all_btn.clicked.connect(self._check_all)
        self.check_all_btn.setEnabled(False)

        self.uncheck_duplicates_btn = QPushButton('Uncheck Duplicates')
        self.uncheck_duplicates_btn.clicked.connect(self._uncheck_duplicates)
        self.uncheck_duplicates_btn.setEnabled(False)

        self.import_btn = QPushButton('Import Selected')
        self.import_btn.clicked.connect(self._do_import)
        self.import_btn.setEnabled(False)
        self.import_btn.setStyleSheet(
            'background-color: #4CAF50; color: white; padding: 8px 20px; font-weight: bold;'
        )

        btn_row.addWidget(self.check_all_btn)
        btn_row.addWidget(self.uncheck_duplicates_btn)
        btn_row.addStretch()
        btn_row.addWidget(self.import_btn)
        layout.addLayout(btn_row)

    # ── CSV loading ──

    def _browse(self):
        path, _ = QFileDialog.getOpenFileName(
            self, 'Select CSV File', '', 'CSV Files (*.csv);;All Files (*)',
        )
        if not path:
            return
        self.file_label.setText(path)
        self._load_csv(path)

    def _load_csv(self, path: str):
        try:
            with open(path, 'r', encoding='utf-8-sig') as f:
                reader = csv.reader(f)
                raw = list(reader)
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to read CSV:\n{e}')
            return

        if not raw:
            QMessageBox.warning(self, 'Empty', 'CSV file is empty.')
            return

        self.column_names = raw[0]
        self.rows = []
        for row in raw[1:]:
            d = {}
            for i, val in enumerate(row):
                if i < len(self.column_names):
                    d[self.column_names[i]] = val.strip()
            # Only add non-empty rows
            if any(v for v in d.values()):
                self.rows.append(d)

        if not self.rows:
            QMessageBox.warning(self, 'Empty', 'No data rows found after header.')
            return

        # Populate mapping combos
        for field in self.fields:
            if field.name in self.context_fields:
                continue
            combo = self.mapping_combos[field.name]
            combo.blockSignals(True)
            while combo.count() > 1:
                combo.removeItem(1)
            for col_name in self.column_names:
                combo.addItem(col_name, self.column_names.index(col_name))
            combo.blockSignals(False)

        self._auto_map()
        self._update_preview()

    def _auto_map(self):
        col_lower = [c.lower().strip() for c in self.column_names]

        synonyms = {
            'reg': 'regNo', 'reg no': 'regNo', 'registration': 'regNo',
            'adm': 'regNo', 'admission': 'regNo', 'admission no': 'regNo',
            'name': 'studentName', 'student': 'studentName', 'full name': 'studentName',
            'student name': 'studentName',
            'subject': 'subjectName', 'unit': 'unit', 'unit name': 'unit',
            'subject name': 'subjectName',
            'cat 1': 'cat1Score', 'cat1': 'cat1Score', 'cat1 score': 'cat1Score',
            'cat 1 max': 'cat1Max', 'cat1 max': 'cat1Max',
            'cat 2': 'cat2Score', 'cat2': 'cat2Score', 'cat2 score': 'cat2Score',
            'cat 2 max': 'cat2Max', 'cat2 max': 'cat2Max',
            'exam': 'examScore', 'exam score': 'examScore',
            'exam max': 'examMax',
            'day': 'day', 'days': 'day',
            'time': 'time', 'period': 'time', 'start': 'time', 'start time': 'time',
            'room': 'room', 'venue': 'room', 'classroom': 'room', 'location': 'room',
            'lecturer': 'lecturer', 'teacher': 'lecturer', 'instructor': 'lecturer',
            'staff': 'lecturer', 'facilitator': 'lecturer',
            'term': 'term',
            'year': 'academicYear', 'academic year': 'academicYear',
            'student id': 'studentId', 'studentid': 'studentId',
            'uid': 'studentId',
            'color': 'color', 'colour': 'color',
            'score': 'cat1Score', 'marks': 'cat1Score',
            'cat 1 marks': 'cat1Score', 'cat1 marks': 'cat1Score',
            'cat 2 marks': 'cat2Score', 'cat2 marks': 'cat2Score',
            'exam marks': 'examScore',
        }

        mapped = set()
        for i, col in enumerate(col_lower):
            if col in synonyms:
                target = synonyms[col]
                if target in self.mapping_combos:
                    combo = self.mapping_combos[target]
                    if combo.currentData() < 0:
                        combo.setCurrentIndex(combo.findData(i))
                        mapped.add(target)

        # Second pass: partial character overlap for remaining fields
        for field in self.fields:
            if field.name in self.context_fields or field.name in mapped:
                continue
            combo = self.mapping_combos[field.name]
            if combo.currentData() >= 0:
                continue
            fset = set(field.name.lower().replace('_', '').replace(' ', ''))
            for i, col in enumerate(col_lower):
                cset = set(col.replace('_', '').replace(' ', ''))
                if not fset or not cset:
                    continue
                overlap = len(fset & cset)
                if overlap >= min(len(fset), len(cset)) * 0.6:
                    combo.setCurrentIndex(combo.findData(i))
                    break

    # ── Preview ──

    def _build_mapping(self):
        mapping = {}
        for field in self.fields:
            if field.name in self.context_fields:
                continue
            combo = self.mapping_combos[field.name]
            col_idx = combo.currentData()
            if col_idx >= 0:
                mapping[field.name] = col_idx
        return mapping

    def _convert_type(self, val: str, field: FieldDef):
        val = val.strip()
        if not val:
            return field.default
        if field.type_hint == 'float':
            try:
                return float(val)
            except ValueError:
                return field.default
        if field.type_hint == 'int':
            try:
                return int(val)
            except ValueError:
                return field.default
        return val

    def _build_data(self):
        """Build fully-mapped list of dicts from CSV rows + context."""
        mapping = self._build_mapping()
        result = []
        for row_dict in self.rows:
            mapped = dict(self.context_fields)
            for field in self.fields:
                if field.name in mapped:
                    continue
                if field.name in mapping:
                    col_idx = mapping[field.name]
                    col_name = self.column_names[col_idx]
                    val = row_dict.get(col_name, '').strip()
                    mapped[field.name] = self._convert_type(val, field)
                else:
                    mapped[field.name] = field.default
            result.append(mapped)
        return result

    def _update_preview(self):
        if not self.rows:
            return

        data = self._build_data()

        # Validate required fields
        missing = [f.label for f in self.fields
                   if f.required and f.name not in self.context_fields
                   and f.name not in self._build_mapping()]
        if missing:
            self.summary_label.setText(f'⚠ Map all required fields: {", ".join(missing)}')
            self.summary_label.setStyleSheet('font-weight: bold; padding: 4px; color: #F44336;')
            self.table.setRowCount(0)
            self.import_btn.setEnabled(False)
            self.check_all_btn.setEnabled(False)
            self.uncheck_duplicates_btn.setEnabled(False)
            return

        # Check duplicates
        progress = QProgressDialog('Checking for duplicates...', None, 0, 0, self)
        progress.setWindowTitle('Checking')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()

        try:
            self.duplicates = [self.duplicate_checker(row) for row in data]
        except Exception as e:
            progress.close()
            QMessageBox.critical(self, 'Error', f'Duplicate check failed:\n{e}')
            return
        finally:
            progress.close()

        self.checked = [not d for d in self.duplicates]

        # Summary
        total = len(data)
        dup = sum(self.duplicates)
        checked = sum(self.checked)
        if dup:
            self.summary_label.setText(
                f'{total} rows | {total - dup} new | {dup} duplicate (auto-unchecked) | {checked} selected'
            )
            self.summary_label.setStyleSheet('font-weight: bold; padding: 4px; color: #FF8F00;')
        else:
            self.summary_label.setText(f'{total} rows | all new | {checked} selected')
            self.summary_label.setStyleSheet('font-weight: bold; padding: 4px; color: #4CAF50;')

        # Visible columns: checkbox + mapped fields + status
        mapped_field_names = list(self._build_mapping().keys())
        if self.context_fields:
            mapped_field_names = [f for f in mapped_field_names
                                  if f not in self.context_fields]
        visible_fields = [f for f in self.fields if f.name in mapped_field_names]
        cols = [''] + [f.label for f in visible_fields] + ['Status']
        self.table.setColumnCount(len(cols))
        self.table.setHorizontalHeaderLabels(cols)

        self.table.setRowCount(len(data))
        self.table.blockSignals(True)

        for ri, row_data in enumerate(data):
            # Checkbox
            chk = QTableWidgetItem()
            chk.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
            chk.setCheckState(Qt.CheckState.Checked if self.checked[ri] else Qt.CheckState.Unchecked)
            chk.setData(Qt.ItemDataRole.UserRole, ri)
            self.table.setItem(ri, 0, chk)

            is_dup = self.duplicates[ri]
            bg = QColor('#FFCDD2') if is_dup else QColor('#C8E6C9')

            for ci, f in enumerate(visible_fields):
                item = QTableWidgetItem(str(row_data.get(f.name, '')))
                item.setBackground(QBrush(bg))
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.table.setItem(ri, ci + 1, item)

            # Status
            st = QTableWidgetItem('DUPLICATE' if is_dup else 'NEW')
            st.setFlags(st.flags() & ~Qt.ItemFlag.ItemIsEditable)
            st.setBackground(QBrush(QColor('#F44336') if is_dup else QColor('#4CAF50')))
            st.setForeground(QBrush(QColor('white')))
            self.table.setItem(ri, len(cols) - 1, st)

        self.table.blockSignals(False)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.table.itemChanged.connect(self._on_check_changed)

        self.import_btn.setEnabled(checked > 0)
        self.check_all_btn.setEnabled(total > 0)
        self.uncheck_duplicates_btn.setEnabled(dup > 0)

    def _on_check_changed(self, item):
        if item.column() != 0:
            return
        ri = item.data(Qt.ItemDataRole.UserRole)
        if ri is None:
            return
        self.checked[ri] = (item.checkState() == Qt.CheckState.Checked)
        self.import_btn.setEnabled(sum(self.checked) > 0)

    def _check_all(self):
        self.table.blockSignals(True)
        for ri in range(len(self.checked)):
            self.checked[ri] = True
            it = self.table.item(ri, 0)
            if it:
                it.setCheckState(Qt.CheckState.Checked)
        self.table.blockSignals(False)
        self.import_btn.setEnabled(sum(self.checked) > 0)

    def _uncheck_duplicates(self):
        self.table.blockSignals(True)
        for ri in range(len(self.checked)):
            if self.duplicates[ri]:
                self.checked[ri] = False
                it = self.table.item(ri, 0)
                if it:
                    it.setCheckState(Qt.CheckState.Unchecked)
        self.table.blockSignals(False)
        self.import_btn.setEnabled(sum(self.checked) > 0)

    # ── Import ──

    def get_selected_data(self) -> list[dict]:
        data = self._build_data()
        return [data[i] for i in range(len(data)) if self.checked[i]]

    def _do_import(self):
        selected = self.get_selected_data()
        if not selected:
            QMessageBox.information(self, 'Nothing Selected',
                                    'Check at least one row to import.')
            return

        confirm = QMessageBox.question(
            self, 'Confirm Import',
            f'Import {len(selected)} row(s) to Firestore?\n\n'
            f'This cannot be undone.',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if confirm != QMessageBox.StandardButton.Yes:
            return

        progress = QProgressDialog('Importing...', None, 0, 0, self)
        progress.setWindowTitle('Import')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()

        try:
            count, msg = self.importer(selected)
            progress.close()
            QMessageBox.information(self, 'Import Complete',
                                    f'{count} row(s) imported successfully.\n{msg}')
            self.accept()
        except Exception as e:
            progress.close()
            QMessageBox.critical(self, 'Import Failed', str(e))
