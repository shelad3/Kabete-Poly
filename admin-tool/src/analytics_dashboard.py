"""
Analytics Dashboard — grade distribution, subject averages, pass/fail rates.
Tab widget for the Kabete Poly Admin Tool.
"""

import os
import datetime

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QComboBox, QLineEdit, QMessageBox, QGroupBox, QGridLayout,
    QScrollArea,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont, QColor, QPainter

from firestore_client import FirestoreClient
from models import GradeRecord

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    MPL_AVAILABLE = True
except ImportError:
    MPL_AVAILABLE = False


class GradeBar(QWidget):
    """Simple colored bar showing grade distribution."""

    def __init__(self, label: str, count: int, total: int, color: QColor, parent=None):
        super().__init__(parent)
        self.label = label
        self.count = count
        self.total = total
        self.bar_color = color
        self.setMinimumHeight(28)

    def paintEvent(self, event):
        p = QPainter(self)
        w = self.width()
        h = self.height()

        pct = self.count / self.total if self.total > 0 else 0
        bar_w = int(w * pct)

        # Background
        p.fillRect(0, 0, w, h, QColor(240, 240, 240))

        # Bar
        p.fillRect(0, 0, bar_w, h, self.bar_color)

        # Text
        p.setPen(QColor(0, 0, 0))
        font = QFont('Segoe UI', 9)
        p.setFont(font)
        text = f'{self.label}: {self.count} ({pct * 100:.0f}%)'
        p.drawText(4, 0, w - 4, h, Qt.AlignmentFlag.AlignVCenter, text)
        p.end()


class AnalyticsDashboard(QWidget):
    def __init__(self):
        super().__init__()
        self._class_id = ''
        self._students: list = []
        self._grades: dict[str, list[GradeRecord]] = {}
        self._subjects: list[str] = []

        layout = QVBoxLayout(self)

        # ── Controls ──
        controls = QHBoxLayout()

        self.class_combo = QComboBox()
        self.class_combo.setMinimumWidth(200)
        controls.addWidget(QLabel('Class:'))
        controls.addWidget(self.class_combo)

        self.term_combo = QComboBox()
        self.term_combo.addItems(['Term 1', 'Term 2', 'Term 3'])
        controls.addWidget(QLabel('Term:'))
        controls.addWidget(self.term_combo)

        self.year_input = QLineEdit()
        self.year_input.setPlaceholderText('Year')
        self.year_input.setText(datetime.date.today().strftime('%Y'))
        self.year_input.setFixedWidth(70)
        controls.addWidget(QLabel('Year:'))
        controls.addWidget(self.year_input)

        self.load_btn = QPushButton('Load Analytics')
        self.load_btn.clicked.connect(self._load_data)
        self.load_btn.setStyleSheet('padding: 5px 15px;')
        controls.addWidget(self.load_btn)
        controls.addStretch()
        layout.addLayout(controls)

        # ── Scroll area for results ──
        scroll = QScrollArea()
        self.results = QWidget()
        self.results_layout = QVBoxLayout(self.results)
        self.results_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self.results)
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

    def _clear_results(self):
        while self.results_layout.count():
            w = self.results_layout.takeAt(0)
            if w.widget():
                w.widget().deleteLater()

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

        self._students = students
        self._grades = grades_by_student

        # Gather subjects
        subjects_set: set[str] = set()
        for glist in grades_by_student.values():
            for g in glist:
                subjects_set.add(g.subjectName)
        self._subjects = sorted(subjects_set)

        self._clear_results()
        self._build_summary(class_id, term, year)

    def _build_summary(self, class_id: str, term: str, year: str):
        rows = QGridLayout()

        # ── Overall stats ──
        all_scores: list[float] = []
        total_students_with_grades = 0
        for uid, glist in self._grades.items():
            if glist:
                total_students_with_grades += 1
                total = sum(g.total_score for g in glist)
                all_scores.append(total)

        avg = sum(all_scores) / len(all_scores) if all_scores else 0
        max_score = max(all_scores) if all_scores else 0
        min_score = min(all_scores) if all_scores else 0

        # Grade distribution
        a = sum(1 for s in all_scores if s >= 80)
        b = sum(1 for s in all_scores if 70 <= s < 80)
        c = sum(1 for s in all_scores if 60 <= s < 70)
        d = sum(1 for s in all_scores if 50 <= s < 60)
        e = sum(1 for s in all_scores if s < 50)
        total = len(all_scores)

        # ── Title ──
        title = QLabel(f'{class_id} — {term} {year}')
        title.setStyleSheet('font-size: 18px; font-weight: bold; color: #1A237E; padding: 8px;')
        self.results_layout.addWidget(title)

        # ── Overview cards ──
        overview = QGroupBox('Overview')
        ol = QGridLayout(overview)
        ol.addWidget(QLabel(f'Students enrolled:'), 0, 0)
        ol.addWidget(QLabel(str(len(self._students))), 0, 1)
        ol.addWidget(QLabel(f'Students with grades:'), 1, 0)
        ol.addWidget(QLabel(str(total_students_with_grades)), 1, 1)
        ol.addWidget(QLabel(f'Subjects:'), 2, 0)
        ol.addWidget(QLabel(', '.join(self._subjects) if self._subjects else 'None'), 2, 1)
        self.results_layout.addWidget(overview)

        # ── Score stats ──
        stats = QGroupBox('Score Statistics')
        sl = QGridLayout(stats)
        sl.addWidget(QLabel(f'Average Total:'), 0, 0)
        sl.addWidget(QLabel(f'{avg:.1f}%'), 0, 1)
        sl.addWidget(QLabel(f'Highest:'), 1, 0)
        sl.addWidget(QLabel(f'{max_score:.1f}%'), 1, 1)
        sl.addWidget(QLabel(f'Lowest:'), 2, 0)
        sl.addWidget(QLabel(f'{min_score:.1f}%'), 2, 1)
        self.results_layout.addWidget(stats)

        # ── Grade distribution bars ──
        if total > 0:
            dist = QGroupBox('Grade Distribution')
            dl = QVBoxLayout(dist)
            dl.addWidget(GradeBar('A (>=80%)', a, total, QColor(76, 175, 80)))
            dl.addWidget(GradeBar('B (>=70%)', b, total, QColor(139, 195, 74)))
            dl.addWidget(GradeBar('C (>=60%)', c, total, QColor(255, 193, 7)))
            dl.addWidget(GradeBar('D (>=50%)', d, total, QColor(255, 152, 0)))
            dl.addWidget(GradeBar('E (<50%)', e, total, QColor(244, 67, 54)))
            self.results_layout.addWidget(dist)

        # ── Per-subject averages ──
        if self._subjects:
            subj_group = QGroupBox('Subject Averages')
            subj_layout = QGridLayout(subj_group)
            subj_layout.addWidget(QLabel('Subject'), 0, 0)
            subj_layout.addWidget(QLabel('Avg Score'), 0, 1)
            subj_layout.addWidget(QLabel('Avg %'), 0, 2)

            for row, subj in enumerate(self._subjects, start=1):
                scores = []
                for glist in self._grades.values():
                    for g in glist:
                        if g.subjectName == subj:
                            scores.append(g.percentage)
                avg_pct = sum(scores) / len(scores) if scores else 0
                avg_score = sum(g.total_score for g in
                    [g for glist in self._grades.values() for g in glist if g.subjectName == subj]
                ) / len(scores) if scores else 0

                subj_layout.addWidget(QLabel(subj), row, 0)
                subj_layout.addWidget(QLabel(f'{avg_score:.1f}/{g.total_max:.0f}' if scores else '-'), row, 1)
                subj_layout.addWidget(QLabel(f'{avg_pct:.1f}%' if scores else '-'), row, 2)

            self.results_layout.addWidget(subj_group)

        # ── Matplotlib chart ──
        if MPL_AVAILABLE and total > 0:
            try:
                fig, ax = plt.subplots(figsize=(5, 3))
                labels = ['A', 'B', 'C', 'D', 'E']
                counts = [a, b, c, d, e]
                colors = ['#4CAF50', '#8BC34A', '#FFC107', '#FF9800', '#F44336']
                ax.bar(labels, counts, color=colors)
                ax.set_title(f'Grade Distribution — {class_id}')
                ax.set_ylabel('Students')
                for i, v in enumerate(counts):
                    ax.text(i, v + 0.1, str(v), ha='center', fontsize=9)

                chart_path = os.path.join(
                    os.path.dirname(__file__), '..', 'config',
                    f'_chart_{class_id.replace("/", "_")}.png',
                )
                fig.savefig(chart_path, dpi=100, bbox_inches='tight')
                plt.close(fig)

                from PyQt6.QtGui import QPixmap
                chart_label = QLabel()
                pixmap = QPixmap(chart_path)
                chart_label.setPixmap(pixmap.scaledToWidth(500))
                chart_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
                self.results_layout.addWidget(chart_label)
            except Exception:
                pass

        self.results_layout.addStretch()


if __name__ == '__main__':
    import sys
    from PyQt6.QtWidgets import QApplication
    app = QApplication(sys.argv)
    w = AnalyticsDashboard()
    w.setWindowTitle('Analytics Dashboard')
    w.resize(700, 600)
    w.show()
    sys.exit(app.exec())
