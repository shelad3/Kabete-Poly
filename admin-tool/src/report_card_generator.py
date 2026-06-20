"""
Report Card Generator — batch PDF generation from Firestore grades.
Tab widget for the Kabete Poly Admin Tool.
"""

import os
import datetime

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QComboBox, QLineEdit, QFileDialog, QMessageBox,
    QProgressDialog, QCheckBox, QScrollArea, QGroupBox,
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtGui import QFont

try:
    from fpdf import FPDF
except ImportError:
    FPDF = None

from firestore_client import FirestoreClient
from models import GradeRecord


class ReportCardWorker(QThread):
    progress = pyqtSignal(int, str)
    done = pyqtSignal(int, int, str)

    def __init__(self, students, grades_by_student, class_id, term, year, output_dir, subjects):
        super().__init__()
        self.students = students
        self.grades_by_student = grades_by_student
        self.class_id = class_id
        self.term = term
        self.year = year
        self.output_dir = output_dir
        self.subjects = subjects

    def run(self):
        total = len(self.students)
        errors = 0

        for i, student in enumerate(self.students):
            try:
                path = generate_pdf(
                    student, self.grades_by_student.get(student.uid, []),
                    self.class_id, self.term, self.year, self.output_dir, self.subjects,
                )
                self.progress.emit(i + 1, f'{student.regNo} - {student.name}')
            except Exception as e:
                errors += 1
                self.progress.emit(i + 1, f'ERROR: {student.regNo} - {e}')

        self.done.emit(total, errors, self.output_dir)


def generate_pdf(student, grades, class_id, term, year, output_dir, subjects):
    pdf = FPDF('P', 'mm', 'A4')
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    # ── School header ──
    pdf.set_fill_color(26, 35, 126)
    pdf.rect(0, 0, 210, 25, 'F')
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 18)
    pdf.set_y(6)
    pdf.cell(0, 10, 'KABETE POLYTECHNIC', align='C', new_x='LMARGIN')
    pdf.set_font('Helvetica', '', 11)
    pdf.cell(0, 7, 'PROGRESS REPORT CARD', align='C', new_x='LMARGIN')
    pdf.set_text_color(0, 0, 0)
    pdf.ln(12)

    # ── Student info ──
    pdf.set_font('Helvetica', '', 11)
    pdf.cell(0, 7, f'Student:  {student.name}', new_x='LMARGIN', new_y='NEXT')
    pdf.cell(0, 7, f'Reg No:   {student.regNo}', new_x='LMARGIN', new_y='NEXT')
    pdf.cell(0, 7, f'Class:    {class_id}', new_x='LMARGIN', new_y='NEXT')
    pdf.cell(0, 7, f'Term:     {term} | {year}', new_x='LMARGIN', new_y='NEXT')
    pdf.ln(5)

    # ── Build grade lookup: subject -> GradeRecord ──
    grade_map: dict[str, GradeRecord] = {}
    for g in grades:
        grade_map[g.subjectName] = g

    # ── Table ──
    col_w = [52, 22, 22, 22, 24, 20, 28]
    headers = ['Subject', 'CAT1', 'CAT2', 'Exam', 'Total', '%', 'Grade']

    # Table header
    pdf.set_fill_color(26, 35, 126)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 9)
    for j, h in enumerate(headers):
        pdf.cell(col_w[j], 8, h, border=1, align='C', fill=True)
    pdf.ln()

    pdf.set_text_color(0, 0, 0)
    pdf.set_font('Helvetica', '', 9)

    grand_total_score = 0.0
    grand_total_max = 0.0

    for subj in subjects:
        g = grade_map.get(subj)
        if g:
            ts = g.total_score
            tm = g.total_max
            pct = g.percentage
            grade = g.letter_grade
        else:
            ts = 0.0
            tm = 0.0
            pct = 0.0
            grade = '-'

        grand_total_score += ts
        grand_total_max += tm

        row = [subj[:20],
               f'{g.cat1Score:.0f}/{g.cat1Max:.0f}' if g else '-',
               f'{g.cat2Score:.0f}/{g.cat2Max:.0f}' if g else '-',
               f'{g.examScore:.0f}/{g.examMax:.0f}' if g else '-',
               f'{ts:.0f}/{tm:.0f}',
               f'{pct:.0f}' if g else '-',
               grade]

        for j, val in enumerate(row):
            pdf.cell(col_w[j], 7, str(val), border=1, align='C')
        pdf.ln()

    # Total row
    overall_pct = (grand_total_score / grand_total_max * 100) if grand_total_max > 0 else 0
    overall_grade = _letter_grade(overall_pct)
    total_row = ['TOTAL', '', '', '',
                 f'{grand_total_score:.0f}/{grand_total_max:.0f}',
                 f'{overall_pct:.0f}', overall_grade]
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_fill_color(230, 230, 250)
    for j, val in enumerate(total_row):
        pdf.cell(col_w[j], 7, str(val), border=1, align='C', fill=True)
    pdf.ln()

    # ── Key ──
    pdf.ln(5)
    pdf.set_font('Helvetica', '', 8)
    pdf.cell(
        0, 5,
        'Key: A (>=80%)  B (>=70%)  C (>=60%)  D (>=50%)  E (<50%)',
        new_x='LMARGIN', new_y='NEXT',
    )
    pdf.ln(5)

    # ── Comments ──
    pdf.set_font('Helvetica', 'B', 10)
    pdf.cell(0, 7, 'Class Teacher\'s Comments:', new_x='LMARGIN', new_y='NEXT')
    pdf.set_font('Helvetica', '', 10)
    pdf.cell(0, 20, '_____________________________________________________', new_x='LMARGIN', new_y='NEXT')

    # ── Signatures ──
    pdf.ln(5)
    pdf.set_font('Helvetica', '', 10)
    pdf.cell(63, 7, '____________________', align='C')
    pdf.cell(63, 7, '____________________', align='C')
    pdf.cell(63, 7, '____________________', align='C')
    pdf.ln()
    pdf.set_font('Helvetica', '', 8)
    pdf.cell(63, 5, 'Class Teacher', align='C')
    pdf.cell(63, 5, 'HOD', align='C')
    pdf.cell(63, 5, 'Principal', align='C')
    pdf.ln(10)

    # ── Print date ──
    pdf.set_font('Helvetica', 'I', 8)
    pdf.cell(0, 5, f'Printed: {datetime.date.today().strftime("%d-%b-%Y")}', new_x='LMARGIN', new_y='NEXT')

    # ── Save ──
    safe_name = student.regNo.replace('/', '_').replace('\\', '_').replace(' ', '_')
    pdf.output(os.path.join(output_dir, f'{safe_name}.pdf'))
    return os.path.join(output_dir, f'{safe_name}.pdf')


def _letter_grade(pct: float) -> str:
    if pct >= 80:
        return 'A'
    if pct >= 70:
        return 'B'
    if pct >= 60:
        return 'C'
    if pct >= 50:
        return 'D'
    return 'E'


class ReportCardGenerator(QWidget):
    def __init__(self):
        super().__init__()
        self._class_id = ''
        self._subjects: list[str] = []
        self._students_cache: list = []
        self._grades_cache: dict[str, list[GradeRecord]] = {}
        self._worker: ReportCardWorker | None = None

        layout = QVBoxLayout(self)

        # ── Controls ──
        controls = QHBoxLayout()

        self.class_label = QLabel('Class:')
        self.class_combo = QComboBox()
        self.class_combo.setMinimumWidth(200)
        controls.addWidget(self.class_label)
        controls.addWidget(self.class_combo)

        self.term_combo = QComboBox()
        self.term_combo.addItems(['Term 1', 'Term 2', 'Term 3'])
        controls.addWidget(QLabel('Term:'))
        controls.addWidget(self.term_combo)

        self.year_input = QLineEdit()
        self.year_input.setPlaceholderText('e.g. 2026')
        self.year_input.setText(datetime.date.today().strftime('%Y'))
        self.year_input.setFixedWidth(80)
        controls.addWidget(QLabel('Year:'))
        controls.addWidget(self.year_input)

        self.load_btn = QPushButton('Load Data')
        self.load_btn.clicked.connect(self._load_data)
        self.load_btn.setStyleSheet('padding: 5px 15px;')
        controls.addWidget(self.load_btn)

        self.generate_btn = QPushButton('Generate All PDFs')
        self.generate_btn.clicked.connect(self._generate_all)
        self.generate_btn.setEnabled(False)
        self.generate_btn.setStyleSheet(
            'padding: 8px 20px; background-color: #1A237E; color: white; font-weight: bold;'
        )
        controls.addWidget(self.generate_btn)

        controls.addStretch()
        layout.addLayout(controls)

        # ── Info ──
        self.info_label = QLabel('Select class, term, year and click "Load Data"')
        self.info_label.setStyleSheet('color: #666; padding: 4px;')
        layout.addWidget(self.info_label)

        # ── Student list ──
        scroll = QScrollArea()
        self.student_list = QWidget()
        self._student_checkboxes: list[QCheckBox] = []
        self.student_layout = QVBoxLayout(self.student_list)
        self.student_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self.student_list)
        scroll.setWidgetResizable(True)
        layout.addWidget(scroll, stretch=1)

    def set_class(self, class_id: str):
        self.class_combo.setCurrentText(class_id)
        self._class_id = class_id

    def refresh_classes(self, classes: list[str]):
        current = self.class_combo.currentText()
        self.class_combo.blockSignals(True)
        self.class_combo.clear()
        self.class_combo.addItems(classes)
        if current in classes:
            self.class_combo.setCurrentText(current)
        self.class_combo.blockSignals(False)

    def _load_data(self):
        class_id = self.class_combo.currentText()
        term = self.term_combo.currentText()
        year = self.year_input.text().strip()

        if not class_id or not term or not year:
            QMessageBox.warning(self, 'Missing', 'Select class, term, and year.')
            return

        try:
            db = FirestoreClient.get()
            students = db.get_students_in_class(class_id)
            grades_by_student = db.get_all_grades_for_class(class_id, term, year)
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load data:\n{e}')
            return

        if not students:
            QMessageBox.information(self, 'No Students', 'No students found in this class.')
            return

        # Gather unique subjects
        subjects_set: set[str] = set()
        for glist in grades_by_student.values():
            for g in glist:
                subjects_set.add(g.subjectName)
        self._subjects = sorted(subjects_set)
        self._students_cache = students
        self._grades_cache = grades_by_student

        # Build student list with checkboxes
        for cb in self._student_checkboxes:
            self.student_layout.removeWidget(cb)
            cb.deleteLater()
        self._student_checkboxes.clear()

        select_all = QCheckBox('Select All')
        select_all.setChecked(True)
        select_all.toggled.connect(self._toggle_all)
        self.student_layout.addWidget(select_all)
        self._student_checkboxes.append(select_all)

        for s in students:
            grades = grades_by_student.get(s.uid, [])
            subj_count = len(grades)
            cb = QCheckBox(f'{s.regNo}  —  {s.name}  ({subj_count} subjects)')
            cb.setChecked(True)
            self.student_layout.addWidget(cb)
            self._student_checkboxes.append(cb)

        self.student_layout.addStretch()

        self.info_label.setText(
            f'{len(students)} students, {len(self._subjects)} subjects '
            f'({", ".join(self._subjects) if self._subjects else "none"})'
        )
        self.generate_btn.setEnabled(len(students) > 0)

    def _toggle_all(self, checked: bool):
        for cb in self._student_checkboxes[1:]:
            cb.setChecked(checked)

    def _generate_all(self):
        if self._worker and self._worker.isRunning():
            QMessageBox.warning(self, 'Busy', 'Already generating report cards.')
            return

        if not self._subjects:
            QMessageBox.warning(self, 'No Subjects', 'No subjects found. Load data first.')
            return

        selected = []
        for i, cb in enumerate(self._student_checkboxes[1:], start=1):
            if cb.isChecked() and i - 1 < len(self._students_cache):
                selected.append(self._students_cache[i - 1])

        if not selected:
            QMessageBox.warning(self, 'None Selected', 'Select at least one student.')
            return

        output_dir = QFileDialog.getExistingDirectory(self, 'Select Output Folder')
        if not output_dir:
            return

        class_id = self.class_combo.currentText()
        term = self.term_combo.currentText()
        year = self.year_input.text().strip()

        self.generate_btn.setEnabled(False)
        self.progress = QProgressDialog('Generating report cards...', None, 0, len(selected), self)
        self.progress.setWindowTitle('Report Cards')
        self.progress.setModal(True)
        self.progress.show()

        self._worker = ReportCardWorker(
            selected, self._grades_cache, class_id, term, year, output_dir, self._subjects,
        )
        self._worker.progress.connect(self._on_progress)
        self._worker.done.connect(self._on_done)
        self._worker.start()

    def _on_progress(self, value: int, text: str):
        if self.progress:
            self.progress.setLabelText(text)
            self.progress.setValue(value)

    def _on_done(self, total: int, errors: int, output_dir: str):
        self.progress.close()
        self.generate_btn.setEnabled(True)
        QMessageBox.information(
            self, 'Complete',
            f'{total} report card(s) generated.\n'
            f'{errors} error(s).\n\n'
            f'Saved to:\n{output_dir}'
        )
        self._worker = None
