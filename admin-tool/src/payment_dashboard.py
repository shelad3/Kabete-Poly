# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QTableWidget, QTableWidgetItem, QComboBox, QHeaderView,
    QMessageBox, QInputDialog, QGroupBox, QGridLayout,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QFont

from firestore_client import FirestoreClient
from models import Payment


class PaymentDashboard(QWidget):
    """Admin dashboard for viewing and managing payments."""

    def __init__(self):
        super().__init__()
        self._payments: list[Payment] = []
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # Summary row
        summary_group = QGroupBox('Payment Summary')
        summary_grid = QGridLayout(summary_group)
        self._total_label = QLabel('Total: 0')
        self._completed_label = QLabel('Completed: 0')
        self._pending_label = QLabel('Pending: 0')
        self._failed_label = QLabel('Failed: 0')
        self._amount_label = QLabel('Total Amount: KES 0')
        for i, w in enumerate([self._total_label, self._completed_label, self._pending_label, self._failed_label, self._amount_label]):
            w.setStyleSheet('font-size: 14px; font-weight: bold; padding: 8px;')
            summary_grid.addWidget(w, 0, i)
        layout.addWidget(summary_group)

        # Filters
        filter_row = QHBoxLayout()
        filter_row.addWidget(QLabel('Status Filter:'))
        self._status_filter = QComboBox()
        self._status_filter.addItems(['All', 'pending', 'processing', 'completed', 'failed', 'refunded'])
        self._status_filter.currentTextChanged.connect(self._apply_filter)
        filter_row.addWidget(self._status_filter)

        filter_row.addStretch()
        self._refresh_btn = QPushButton('Refresh')
        self._refresh_btn.clicked.connect(self._load_payments)
        filter_row.addWidget(self._refresh_btn)
        layout.addLayout(filter_row)

        # Table
        self._table = QTableWidget()
        self._table.setColumnCount(9)
        self._table.setHorizontalHeaderLabels([
            'ID', 'Student', 'Booking', 'Amount (KES)', 'Method', 'Status', 'Phone', 'Transaction Ref', 'Date'
        ])
        self._table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.setAlternatingRowColors(True)
        layout.addWidget(self._table)

        # Action buttons
        action_row = QHBoxLayout()
        self._mark_btn = QPushButton('Mark as Completed')
        self._mark_btn.clicked.connect(self._mark_completed)
        self._mark_btn.setStyleSheet('background-color: #4CAF50; color: white; padding: 8px 16px;')
        action_row.addWidget(self._mark_btn)

        self._refund_btn = QPushButton('Mark as Refunded')
        self._refund_btn.clicked.connect(self._mark_refunded)
        self._refund_btn.setStyleSheet('background-color: #2196F3; color: white; padding: 8px 16px;')
        action_row.addWidget(self._refund_btn)

        action_row.addStretch()
        layout.addLayout(action_row)

    def refresh(self):
        self._load_payments()

    def _load_payments(self):
        try:
            db = FirestoreClient.get()
            self._payments = db.get_all_payments()
            self._update_summary()
            self._apply_filter()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load payments:\n{e}')

    def _update_summary(self):
        total_amount = sum(p.amount for p in self._payments)
        completed = sum(1 for p in self._payments if p.status == 'completed')
        pending = sum(1 for p in self._payments if p.status == 'pending')
        failed = sum(1 for p in self._payments if p.status == 'failed')
        self._total_label.setText(f'Total: {len(self._payments)}')
        self._completed_label.setText(f'Completed: {completed}')
        self._pending_label.setText(f'Pending: {pending}')
        self._failed_label.setText(f'Failed: {failed}')
        self._amount_label.setText(f'Total Amount: KES {total_amount:,.2f}')

    def _apply_filter(self):
        status = self._status_filter.currentText()
        filtered = self._payments if status == 'All' else [p for p in self._payments if p.status == status]
        self._populate_table(filtered)

    def _populate_table(self, payments: list[Payment]):
        self._table.setRowCount(len(payments))
        for row, p in enumerate(payments):
            items = [
                p.doc_id[:12] + '...' if len(p.doc_id) > 12 else p.doc_id,
                p.student_id[:16] + '...' if len(p.student_id) > 16 else p.student_id,
                p.booking_id[:12] + '...' if len(p.booking_id) > 12 else p.booking_id,
                f'{p.amount:.2f}',
                p.method_label,
                p.status_label,
                p.phone_number,
                p.transaction_ref or '—',
                p.initiated_at or '—',
            ]
            for col, text in enumerate(items):
                item = QTableWidgetItem(text)
                if col == 5:  # Status column
                    color = p.status_color
                    item.setBackground(QColor(color))
                    item.setForeground(QColor('#FFFFFF'))
                    item.setFont(QFont('Segoe UI', 10, QFont.Weight.Bold))
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self._table.setItem(row, col, item)

    def _selected_payment(self) -> Payment | None:
        row = self._table.currentRow()
        if row < 0:
            QMessageBox.warning(self, 'No Selection', 'Please select a payment row.')
            return None
        # Map back through filtered list
        status = self._status_filter.currentText()
        filtered = self._payments if status == 'All' else [p for p in self._payments if p.status == status]
        if row >= len(filtered):
            return None
        return filtered[row]

    def _mark_completed(self):
        payment = self._selected_payment()
        if not payment:
            return
        ref, ok = QInputDialog.getText(self, 'Transaction Reference', 'Enter transaction reference:')
        if not ok:
            return
        try:
            db = FirestoreClient.get()
            db.update_payment_status(payment.doc_id, 'completed', ref)
            QMessageBox.information(self, 'Done', 'Payment marked as completed.')
            self._load_payments()
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))

    def _mark_refunded(self):
        payment = self._selected_payment()
        if not payment:
            return
        reply = QMessageBox.question(
            self, 'Confirm Refund',
            f'Mark payment {payment.doc_id[:12]}... as refunded?',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        try:
            db = FirestoreClient.get()
            db.update_payment_status(payment.doc_id, 'refunded')
            QMessageBox.information(self, 'Done', 'Payment marked as refunded.')
            self._load_payments()
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))
