# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Kabete National Polytechnique

"""Feature Flag management tab for the admin tool."""

from datetime import datetime

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QTableWidget, QTableWidgetItem, QHeaderView,
    QMessageBox, QDialog, QFormLayout, QLineEdit,
    QCheckBox, QDialogButtonBox, QDateTimeEdit, QTextEdit,
    QGroupBox,
)
from PyQt6.QtCore import Qt, QDateTime
from PyQt6.QtGui import QColor, QFont

from firestore_client import FirestoreClient
from models import FeatureFlag, DEFAULT_FEATURE_FLAGS


class FeatureFlagManager(QWidget):
    """Admin tool tab for managing feature toggles."""

    def __init__(self):
        super().__init__()
        self._flags: list[FeatureFlag] = []
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout(self)

        # Header
        header = QHBoxLayout()
        header.addWidget(QLabel('Feature Flag Management'))
        header.addStretch()

        self._refresh_btn = QPushButton('Refresh')
        self._refresh_btn.clicked.connect(self._load_flags)
        header.addWidget(self._refresh_btn)

        self._seed_btn = QPushButton('Seed Defaults')
        self._seed_btn.clicked.connect(self._seed_defaults)
        self._seed_btn.setStyleSheet('background-color: #FF9800; color: white; padding: 5px 15px;')
        header.addWidget(self._seed_btn)
        layout.addLayout(header)

        # Table
        self._table = QTableWidget()
        self._table.setColumnCount(7)
        self._table.setHorizontalHeaderLabels([
            'Flag', 'Display Name', 'Enabled', 'Schedule', 'Description',
            'Allowed Roles', 'Actions'
        ])
        self._table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setAlternatingRowColors(True)
        layout.addWidget(self._table)

    def refresh(self):
        self._load_flags()

    def _load_flags(self):
        try:
            db = FirestoreClient.get()
            self._flags = db.get_all_feature_flags()
            self._populate_table()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load feature flags:\n{e}')

    def _populate_table(self):
        self._table.setRowCount(len(self._flags))
        for row, flag in enumerate(self._flags):
            schedule_parts = []
            if flag.auto_disable_at:
                schedule_parts.append(f'Auto-off: {flag.auto_disable_at}')
            if flag.auto_enable_at:
                schedule_parts.append(f'Auto-on: {flag.auto_enable_at}')

            enabled_text = 'ON' if flag.enabled else 'OFF'
            schedule_text = '; '.join(schedule_parts) if schedule_parts else '—'
            roles_text = ', '.join(flag.allowed_roles) if flag.allowed_roles else 'All'

            items = [
                flag.name,
                flag.display_name,
                enabled_text,
                schedule_text,
                flag.description[:50] + '...' if len(flag.description) > 50 else flag.description,
                roles_text,
                '',
            ]
            for col, text in enumerate(items):
                item = QTableWidgetItem(text)
                if col == 2:
                    if flag.enabled:
                        item.setBackground(QColor('#4CAF50'))
                        item.setForeground(QColor('#FFFFFF'))
                    else:
                        item.setBackground(QColor('#F44336'))
                        item.setForeground(QColor('#FFFFFF'))
                    item.setFont(QFont('Segoe UI', 10, QFont.Weight.Bold))
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self._table.setItem(row, col, item)

            # Toggle button
            toggle_btn = QPushButton('Toggle' if flag.enabled else 'Toggle')
            toggle_btn.setStyleSheet(
                'background-color: #FF9800; color: white; padding: 3px 10px;'
            )
            toggle_btn.clicked.connect(lambda checked, r=row: self._toggle_flag(r))

            edit_btn = QPushButton('Edit')
            edit_btn.setStyleSheet('padding: 3px 10px;')
            edit_btn.clicked.connect(lambda checked, r=row: self._edit_flag(r))

            action_widget = QWidget()
            action_layout = QHBoxLayout(action_widget)
            action_layout.setContentsMargins(2, 2, 2, 2)
            action_layout.addWidget(toggle_btn)
            action_layout.addWidget(edit_btn)
            self._table.setCellWidget(row, 6, action_widget)

    def _toggle_flag(self, row: int):
        if row < 0 or row >= len(self._flags):
            return
        flag = self._flags[row]
        flag.enabled = not flag.enabled
        try:
            db = FirestoreClient.get()
            db.update_feature_flag(flag)
            self._load_flags()
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))

    def _edit_flag(self, row: int):
        if row < 0 or row >= len(self._flags):
            return
        flag = self._flags[row]
        dialog = FeatureFlagDialog(self, flag)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            updated = dialog.get_flag()
            updated.doc_id = flag.doc_id
            try:
                db = FirestoreClient.get()
                db.update_feature_flag(updated)
                self._load_flags()
            except Exception as e:
                QMessageBox.critical(self, 'Error', str(e))

    def _seed_defaults(self):
        reply = QMessageBox.question(
            self, 'Confirm Seed',
            'Create default feature flags for any that are missing?\n\n'
            'Existing flags will NOT be overwritten.',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        try:
            db = FirestoreClient.get()
            count = db.seed_feature_flags()
            if count:
                QMessageBox.information(self, 'Done', f'{count} default flags created.')
            else:
                QMessageBox.information(self, 'Done', 'All default flags already exist.')
            self._load_flags()
        except Exception as e:
            QMessageBox.critical(self, 'Error', str(e))


class FeatureFlagDialog(QDialog):
    """Edit a single feature flag."""

    def __init__(self, parent=None, flag: FeatureFlag | None = None):
        super().__init__(parent)
        self._flag = flag
        self.setWindowTitle(f'Edit Flag: {flag.name}' if flag else 'New Flag')
        self.resize(500, 400)
        self._build_ui()
        if flag:
            self._populate(flag)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self._name = QLineEdit()
        self._name.setPlaceholderText('e.g. hostel_booking')
        form.addRow('Name:', self._name)

        self._display_name = QLineEdit()
        self._display_name.setPlaceholderText('e.g. Hostel Booking')
        form.addRow('Display Name:', self._display_name)

        self._enabled = QCheckBox('Enabled')
        form.addRow('', self._enabled)

        self._description = QTextEdit()
        self._description.setMaximumHeight(60)
        form.addRow('Description:', self._description)

        self._disabled_msg = QLineEdit()
        form.addRow('Disabled Message:', self._disabled_msg)

        self._auto_disable = QDateTimeEdit()
        self._auto_disable.setCalendarPopup(True)
        self._auto_disable.setDateTime(QDateTime.currentDateTime())
        form.addRow('Auto-Disable At:', self._auto_disable)

        self._auto_enable = QDateTimeEdit()
        self._auto_enable.setCalendarPopup(True)
        self._auto_enable.setDateTime(QDateTime.currentDateTime())
        form.addRow('Auto-Enable At:', self._auto_enable)

        self._allowed_roles = QLineEdit()
        self._allowed_roles.setPlaceholderText('Comma-separated: Student, Teacher, Official')
        form.addRow('Allowed Roles:', self._allowed_roles)

        layout.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _populate(self, flag: FeatureFlag):
        self._name.setText(flag.name)
        self._display_name.setText(flag.display_name)
        self._enabled.setChecked(flag.enabled)
        self._description.setText(flag.description)
        self._disabled_msg.setText(flag.disabled_message)
        roles = ', '.join(flag.allowed_roles)
        self._allowed_roles.setText(roles)

    def get_flag(self) -> FeatureFlag:
        roles_str = self._allowed_roles.text().strip()
        roles = [r.strip() for r in roles_str.split(',') if r.strip()]
        return FeatureFlag(
            doc_id=self._flag.doc_id if self._flag else '',
            name=self._name.text().strip(),
            display_name=self._display_name.text().strip(),
            enabled=self._enabled.isChecked(),
            description=self._description.toPlainText().strip(),
            auto_disable_at=self._auto_disable.dateTime().toString(Qt.DateFormat.ISODate),
            auto_enable_at=self._auto_enable.dateTime().toString(Qt.DateFormat.ISODate),
            disabled_message=self._disabled_msg.text().strip(),
            allowed_roles=roles,
        )
