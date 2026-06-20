"""
QR Code Generator — batch generate student QR codes for attendance scanning.
Usage: python src/qr_generator.py
"""

import os
import io
import sys

sys.path.insert(0, os.path.dirname(__file__))

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QComboBox, QFileDialog, QMessageBox, QProgressDialog,
)
from PyQt6.QtCore import Qt

from firestore_client import FirestoreClient
import config_manager

try:
    import qrcode
except ImportError:
    qrcode = None

try:
    from fpdf import FPDF
except ImportError:
    FPDF = None


def _init_firestore():
    if not config_manager.is_configured():
        print('Not configured. Run the admin tool setup first.')
        return False
    try:
        FirestoreClient.init_from_path(config_manager.get_service_account_path())
        return True
    except Exception as e:
        print(f'Failed to init Firestore: {e}')
        return False


def generate_qr_pdfs(class_id: str, output_dir: str):
    """Generate a single PDF with all student QR codes for printing."""
    if qrcode is None:
        raise ImportError('qrcode package not installed. Run: pip install qrcode[pil]')
    if FPDF is None:
        raise ImportError('fpdf2 package not installed. Run: pip install fpdf2')

    db = FirestoreClient.get()
    students = db.get_students_in_class(class_id)

    if not students:
        raise ValueError(f'No students found in {class_id}')

    pdf = FPDF('P', 'mm', 'A4')
    pdf.set_auto_page_break(auto=True, margin=15)

    cards_per_page = 8  # 2 columns x 4 rows
    card_w = 90
    card_h = 60

    for i, student in enumerate(students):
        if i % cards_per_page == 0:
            pdf.add_page()
            pdf.set_fill_color(26, 35, 126)
            pdf.rect(0, 0, 210, 15, 'F')
            pdf.set_text_color(255, 255, 255)
            pdf.set_font('Helvetica', 'B', 10)
            pdf.set_y(3)
            pdf.cell(0, 8, f'KABETE POLYTECHNIC — {class_id} — Attendance QR Codes', align='C')
            pdf.set_text_color(0, 0, 0)

        col = (i % cards_per_page) % 2
        row = (i % cards_per_page) // 2
        x = 12 + col * (card_w + 8)
        y = 20 + row * (card_h + 8)

        # Card background
        pdf.set_fill_color(255, 255, 255)
        pdf.set_draw_color(200, 200, 200)
        pdf.rect(x, y, card_w, card_h, 'DF')

        # QR code
        buf = io.BytesIO()
        qr = qrcode.make(student.uid, box_size=3, border=1)
        qr.save(buf, format='PNG')
        buf.seek(0)
        pdf.image(buf, x= x + 5, y= y + 5, w=25, h=25)

        # Text
        pdf.set_xy(x + 35, y + 5)
        pdf.set_font('Helvetica', 'B', 9)
        pdf.cell(50, 5, student.name[:30])
        pdf.set_xy(x + 35, y + 12)
        pdf.set_font('Helvetica', '', 8)
        pdf.cell(50, 5, student.regNo)
        pdf.set_xy(x + 35, y + 19)
        pdf.cell(50, 5, class_id)

    output_path = os.path.join(output_dir, f'qr_codes_{class_id}.pdf')
    pdf.output(output_path)
    return output_path, len(students)


class QRGeneratorWidget(QWidget):
    """Simple widget for the admin tool or standalone."""

    def __init__(self):
        super().__init__()
        layout = QVBoxLayout(self)

        controls = QHBoxLayout()
        controls.addWidget(QLabel('Class:'))
        self.class_combo = QComboBox()
        self.class_combo.setMinimumWidth(200)
        controls.addWidget(self.class_combo)

        self.load_btn = QPushButton('Load Classes')
        self.load_btn.clicked.connect(self._load_classes)
        controls.addWidget(self.load_btn)

        self.gen_btn = QPushButton('Generate QR Codes PDF')
        self.gen_btn.clicked.connect(self._generate)
        self.gen_btn.setStyleSheet(
            'padding: 8px 20px; background-color: #1A237E; color: white; font-weight: bold;'
        )
        self.gen_btn.setEnabled(False)
        controls.addWidget(self.gen_btn)
        controls.addStretch()
        layout.addLayout(controls)

        self.info = QLabel('Select a class and generate QR codes for attendance scanning.')
        self.info.setStyleSheet('color: #666; padding: 8px;')
        layout.addWidget(self.info)

        self._load_classes()

    def _load_classes(self):
        try:
            db = FirestoreClient.get()
            classes = db.list_classes()
            self.class_combo.clear()
            self.class_combo.addItems(classes)
            self.gen_btn.setEnabled(len(classes) > 0)
            self.info.setText(f'{len(classes)} classes loaded')
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))

    def _generate(self):
        class_id = self.class_combo.currentText()
        if not class_id:
            return

        output_dir = QFileDialog.getExistingDirectory(self, 'Select Output Folder')
        if not output_dir:
            return

        try:
            path, count = generate_qr_pdfs(class_id, output_dir)
            QMessageBox.information(
                self, 'Complete',
                f'{count} QR codes generated for {class_id}.\n\nSaved to:\n{path}',
            )
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))


def main():
    from PyQt6.QtWidgets import QApplication
    app = QApplication(sys.argv)
    if not _init_firestore():
        sys.exit(1)
    w = QRGeneratorWidget()
    w.setWindowTitle('QR Code Generator')
    w.resize(500, 150)
    w.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
