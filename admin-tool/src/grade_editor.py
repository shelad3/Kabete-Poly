from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QLabel, QComboBox, QLineEdit, QHeaderView, QMessageBox,
    QProgressDialog, QGroupBox, QFormLayout, QApplication,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QBrush

from firestore_client import FirestoreClient
from models import GradeRecord, UserProfile
from csv_import_dialog import CsvImportDialog, FieldDef

TERMS = ['Term 1', 'Term 2', 'Term 3']


class GradeEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.db = FirestoreClient.get()
        self.current_class = ''
        self.students: list[UserProfile] = []
        self.existing_grades: dict[str, GradeRecord] = {}
        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)

        # Controls
        controls = QGroupBox('Grade Entry Controls')
        form = QFormLayout(controls)

        controls_row = QHBoxLayout()

        self.class_combo = QComboBox()
        self.class_combo.setMinimumWidth(200)
        self.class_combo.currentTextChanged.connect(self._on_class_changed)
        controls_row.addWidget(QLabel('Class:'))
        controls_row.addWidget(self.class_combo)

        self.subject_input = QLineEdit()
        self.subject_input.setPlaceholderText('e.g. Mathematics')
        controls_row.addWidget(QLabel('Subject:'))
        controls_row.addWidget(self.subject_input)

        self.term_combo = QComboBox()
        self.term_combo.addItems(TERMS)
        controls_row.addWidget(QLabel('Term:'))
        controls_row.addWidget(self.term_combo)

        self.year_input = QLineEdit()
        self.year_input.setPlaceholderText('e.g. 2026')
        controls_row.addWidget(QLabel('Year:'))
        controls_row.addWidget(self.year_input)

        layout.addLayout(controls_row)

        # Buttons
        btn_row = QHBoxLayout()
        self.load_btn = QPushButton('Load / Refresh')
        self.load_btn.clicked.connect(self._load_data)
        self.load_btn.setEnabled(False)

        self.import_csv_btn = QPushButton('Import CSV')
        self.import_csv_btn.clicked.connect(self._import_csv)
        self.import_csv_btn.setEnabled(False)
        self.import_csv_btn.setStyleSheet(
            'background-color: #FF8F00; color: white; padding: 8px 16px; font-weight: bold;'
        )

        self.save_btn = QPushButton('Save All Grades')
        self.save_btn.clicked.connect(self._save_all)
        self.save_btn.setEnabled(False)
        self.save_btn.setStyleSheet('background-color: #4CAF50; color: white; padding: 8px 16px;')

        btn_row.addWidget(self.load_btn)
        btn_row.addWidget(self.import_csv_btn)
        btn_row.addStretch()
        btn_row.addWidget(self.save_btn)
        layout.addLayout(btn_row)

        # Table
        self.table = QTableWidget()
        self.table.setColumnCount(10)
        self.table.setHorizontalHeaderLabels([
            'Reg No.', 'Name', 'CAT1', 'CAT1 Max',
            'CAT2', 'CAT2 Max', 'Exam', 'Exam Max',
            'Total', 'Grade',
        ])
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.table.setAlternatingRowColors(True)
        self.table.itemChanged.connect(self._on_cell_changed)
        layout.addWidget(self.table)

    # ---- Public API ----

    def refresh_classes(self, classes: list[str]):
        current = self.class_combo.currentText()
        self.class_combo.blockSignals(True)
        self.class_combo.clear()
        self.class_combo.addItems(classes)
        if current in classes:
            self.class_combo.setCurrentText(current)
        self.class_combo.blockSignals(False)

    def set_class(self, class_id: str):
        self.class_combo.setCurrentText(class_id)

    # ---- Handlers ----

    def _on_class_changed(self, class_id: str):
        self.current_class = class_id
        self.load_btn.setEnabled(bool(class_id))
        self.import_csv_btn.setEnabled(bool(class_id))

    def _load_data(self):
        if not self.current_class:
            return

        subject = self.subject_input.text().strip()
        term = self.term_combo.currentText()
        year = self.year_input.text().strip()

        if not subject:
            QMessageBox.warning(self, 'Missing Field', 'Please enter a subject name.')
            return
        if not year:
            QMessageBox.warning(self, 'Missing Field', 'Please enter the academic year.')
            return

        progress = QProgressDialog('Loading students and grades...', None, 0, 0, self)
        progress.setWindowTitle('Loading')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()  # type: ignore

        try:
            self.students = self.db.get_students_in_class(self.current_class)
            self.existing_grades = self.db.get_grades(self.current_class, subject, term, year)
            self._populate_table()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load data:\n{e}')
        finally:
            progress.close()

    def _populate_table(self):
        self.table.blockSignals(True)
        self.table.setRowCount(len(self.students))

        for row, student in enumerate(self.students):
            grade = self.existing_grades.get(student.uid)

            # Reg No
            reg_item = QTableWidgetItem(student.regNo)
            reg_item.setFlags(reg_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.setItem(row, 0, reg_item)

            # Name
            name_item = QTableWidgetItem(student.name)
            name_item.setFlags(name_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.setItem(row, 1, name_item)

            if grade:
                # CAT1
                self._set_cell(row, 2, grade.cat1Score)
                self._set_cell(row, 3, grade.cat1Max)
                # CAT2
                self._set_cell(row, 4, grade.cat2Score)
                self._set_cell(row, 5, grade.cat2Max)
                # Exam
                self._set_cell(row, 6, grade.examScore)
                self._set_cell(row, 7, grade.examMax)
                # Total (computed)
                total_item = QTableWidgetItem(f'{grade.total_score:.1f}')
                total_item.setFlags(total_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.table.setItem(row, 8, total_item)
                # Grade (computed)
                letter_item = QTableWidgetItem(grade.letter_grade)
                letter_item.setFlags(letter_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.table.setItem(row, 9, letter_item)
            else:
                # Defaults
                self._set_cell(row, 2, 0.0)
                self._set_cell(row, 3, 30.0)
                self._set_cell(row, 4, 0.0)
                self._set_cell(row, 5, 30.0)
                self._set_cell(row, 6, 0.0)
                self._set_cell(row, 7, 40.0)
                # Total
                t = QTableWidgetItem('0.0')
                t.setFlags(t.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.table.setItem(row, 8, t)
                # Grade
                g = QTableWidgetItem('')
                g.setFlags(g.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.table.setItem(row, 9, g)

            # Store student/grade data in first column item
            reg_item.setData(Qt.ItemDataRole.UserRole, student.uid)
            if grade:
                reg_item.setData(Qt.ItemDataRole.UserRole + 1, grade.doc_id)
            else:
                reg_item.setData(Qt.ItemDataRole.UserRole + 1, '')

        self.table.blockSignals(False)
        self.save_btn.setEnabled(len(self.students) > 0)

    def _set_cell(self, row: int, col: int, value: float):
        item = QTableWidgetItem(f'{value:.1f}')
        self.table.setItem(row, col, item)

    def _on_cell_changed(self, item: QTableWidgetItem):
        col = item.column()
        if col not in (2, 3, 4, 5, 6, 7):
            return
        row = item.row()
        self._recalc_row(row)

    def _recalc_row(self, row: int):
        cat1 = self._get_cell_float(row, 2)
        cat1m = self._get_cell_float(row, 3)
        cat2 = self._get_cell_float(row, 4)
        cat2m = self._get_cell_float(row, 5)
        exam = self._get_cell_float(row, 6)
        examm = self._get_cell_float(row, 7)

        total = cat1 + cat2 + exam
        total_max = cat1m + cat2m + examm
        pct = (total / total_max * 100) if total_max > 0 else 0

        total_item = self.table.item(row, 8)
        if total_item is None:
            total_item = QTableWidgetItem()
            total_item.setFlags(total_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.setItem(row, 8, total_item)
        total_item.setText(f'{total:.1f}')

        grade_item = self.table.item(row, 9)
        if grade_item is None:
            grade_item = QTableWidgetItem()
            grade_item.setFlags(grade_item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            self.table.setItem(row, 9, grade_item)

        if pct >= 80:
            grade_item.setText('A')
            grade_item.setBackground(QBrush(QColor('#4CAF50')))
        elif pct >= 70:
            grade_item.setText('B')
            grade_item.setBackground(QBrush(QColor('#8BC34A')))
        elif pct >= 60:
            grade_item.setText('C')
            grade_item.setBackground(QBrush(QColor('#FFC107')))
        elif pct >= 50:
            grade_item.setText('D')
            grade_item.setBackground(QBrush(QColor('#FF9800')))
        else:
            grade_item.setText('E')
            grade_item.setBackground(QBrush(QColor('#F44336')))

    def _get_cell_float(self, row: int, col: int) -> float:
        item = self.table.item(row, col)
        if item is None:
            return 0.0
        try:
            return float(item.text())
        except ValueError:
            return 0.0

    def _import_csv(self):
        if not self.current_class:
            return

        subject = self.subject_input.text().strip()
        term = self.term_combo.currentText()
        year = self.year_input.text().strip()

        if not subject:
            QMessageBox.warning(self, 'Missing Field', 'Please enter a subject name first.')
            return
        if not year:
            QMessageBox.warning(self, 'Missing Field', 'Please enter the academic year first.')
            return

        fields = [
            FieldDef('studentId', 'Student ID'),
            FieldDef('regNo', 'Reg No.'),
            FieldDef('studentName', 'Student Name'),
            FieldDef('cat1Score', 'CAT1', default=0.0, type_hint='float'),
            FieldDef('cat1Max', 'CAT1 Max', default=30.0, type_hint='float'),
            FieldDef('cat2Score', 'CAT2', default=0.0, type_hint='float'),
            FieldDef('cat2Max', 'CAT2 Max', default=30.0, type_hint='float'),
            FieldDef('examScore', 'Exam', default=0.0, type_hint='float'),
            FieldDef('examMax', 'Exam Max', default=40.0, type_hint='float'),
        ]

        context = {
            'classId': self.current_class,
            'subjectName': subject,
            'term': term,
            'academicYear': year,
        }

        # Pre-load students for regNo lookup
        students = self.db.get_students_in_class(self.current_class)
        reg_to_uid = {s.regNo: s.uid for s in students}
        name_to_uid = {s.name: s.uid for s in students}

        def checker(row):
            sid = row.get('studentId', '').strip()
            if not sid:
                reg = row.get('regNo', '').strip()
                sid = reg_to_uid.get(reg, '')
            if not sid:
                name = row.get('studentName', '').strip()
                sid = name_to_uid.get(name, '')
            if not sid:
                return False  # can't match, treat as new
            return self.db.grade_exists(self.current_class, subject, term, year, sid)

        def importer(rows):
            batch = []
            for r in rows:
                sid = r.get('studentId', '').strip()
                if not sid:
                    reg = r.get('regNo', '').strip()
                    sid = reg_to_uid.get(reg, '')
                if not sid:
                    name = r.get('studentName', '').strip()
                    sid = name_to_uid.get(name, '')
                if not sid:
                    continue  # skip unmatchable

                assessments = {}
                # Check for new assessments format (e.g. cat1.score, cat1.max)
                if any(k.startswith('cat') or k == 'exam' for k in r.keys() if not k.endswith('.max') and not k.endswith('.score')):
                    for key in list(r.keys()):
                        if key.endswith('.score') or key.endswith('.max'):
                            continue
                        score_key = f'{key}.score'
                        max_key = f'{key}.max'
                        if score_key in r or max_key in r:
                            assessments[key] = {
                                'score': float(r.get(score_key, 0)),
                                'max': float(r.get(max_key, 30)),
                            }
                else:
                    # Backward compat: old fixed fields
                    assessments['cat1'] = {'score': float(r.get('cat1Score', 0)), 'max': float(r.get('cat1Max', 30))}
                    assessments['cat2'] = {'score': float(r.get('cat2Score', 0)), 'max': float(r.get('cat2Max', 30))}
                    assessments['exam'] = {'score': float(r.get('examScore', 0)), 'max': float(r.get('examMax', 100))}

                batch.append({
                    'studentId': sid,
                    'studentName': r.get('studentName', ''),
                    'regNo': r.get('regNo', ''),
                    'classId': self.current_class,
                    'subjectName': subject,
                    'term': term,
                    'academicYear': year,
                    'assessments': assessments,
                    'teacherId': '',
                    'teacherName': '',
                    'comments': '',
                })

            count = self.db.import_grades_batch(batch)
            skipped = len(rows) - count
            msg = f'{skipped} row(s) skipped (could not match student).' if skipped else ''
            return count, msg

        dialog = CsvImportDialog(
            self, self.db, self.current_class, fields,
            checker, importer, context_fields=context,
            title='Import Grades CSV',
        )
        dialog.exec()

    def _build_assessments_from_row(self, row: int) -> dict:
        return {
            'cat1': {'score': self._get_cell_float(row, 2), 'max': self._get_cell_float(row, 3)},
            'cat2': {'score': self._get_cell_float(row, 4), 'max': self._get_cell_float(row, 5)},
            'exam': {'score': self._get_cell_float(row, 6), 'max': self._get_cell_float(row, 7)},
        }

    def _save_all(self):
        if not self.current_class:
            return

        subject = self.subject_input.text().strip()
        term = self.term_combo.currentText()
        year = self.year_input.text().strip()

        if not subject:
            QMessageBox.warning(self, 'Missing Field', 'Please enter a subject name.')
            return
        if not year:
            QMessageBox.warning(self, 'Missing Field', 'Please enter the academic year.')
            return

        grades = []
        for row in range(self.table.rowCount()):
            reg_item = self.table.item(row, 0)
            if reg_item is None:
                continue
            uid = reg_item.data(Qt.ItemDataRole.UserRole)
            doc_id = reg_item.data(Qt.ItemDataRole.UserRole + 1) or ''
            if not uid:
                continue

            grade = GradeRecord(
                studentId=uid,
                studentName=self.table.item(row, 1).text() if self.table.item(row, 1) else '',
                regNo=reg_item.text(),
                subjectName=subject,
                classId=self.current_class,
                term=term,
                academicYear=year,
                assessments=self._build_assessments_from_row(row),
                doc_id=doc_id,
            )
            grades.append(grade)

        if not grades:
            QMessageBox.information(self, 'Nothing to Save', 'No student data found.')
            return

        progress = QProgressDialog('Saving grades...', None, 0, 0, self)
        progress.setWindowTitle('Saving')
        progress.setModal(True)
        progress.show()
        QApplication.processEvents()  # type: ignore

        try:
            count, ids = self.db.save_grades_batch(grades)
            # Update doc_ids for next save
            for row in range(self.table.rowCount()):
                reg_item = self.table.item(row, 0)
                if reg_item and row < len(ids):
                    reg_item.setData(Qt.ItemDataRole.UserRole + 1, ids[row])

            QMessageBox.information(
                self, 'Success',
                f'{count} grades saved successfully to Firestore.',
            )
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to save grades:\n{e}')
        finally:
            progress.close()


