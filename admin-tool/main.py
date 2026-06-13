#!/usr/bin/env python3
"""
Kabete Poly Admin Tool — grade & timetable editor for Windows.
Login via Firebase Auth, role check against Firestore users collection.
"""

import os
import sys
import json

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QTabWidget, QWidget, QVBoxLayout,
    QLabel, QPushButton, QFileDialog, QMessageBox, QStatusBar,
    QComboBox, QHBoxLayout, QLineEdit, QFormLayout, QGroupBox,
    QProgressDialog,
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from firestore_client import FirestoreClient
from firebase_auth_client import FirebaseAuthClient
from grade_editor import GradeEditor
from timetable_editor import TimetableEditor
from models import UserProfile
import config_manager


# ── One-time setup wizard ──────────────────────────────────────────

class SetupWizard(QWidget):
    """Shown on first launch: configure service account + Web API key."""

    def __init__(self, on_done):
        super().__init__()
        self.on_done = on_done
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setSpacing(12)

        title = QLabel('Kabete Poly Admin Tool — Setup')
        title.setStyleSheet('font-size: 22px; font-weight: bold; color: #1A237E;')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        layout.addSpacing(20)

        info = QLabel(
            'First-time setup. You need:\n'
            '1. A Firebase service account JSON file\n'
            '   (Console → Project Settings → Service Accounts → Generate Key)\n'
            '2. Your Firebase Web API Key\n'
            '   (Console → Project Settings → General → Web API Key)'
        )
        info.setWordWrap(True)
        info.setStyleSheet('color: #444; padding: 10px;')
        layout.addWidget(info)

        # Service account
        sa_group = QGroupBox('1. Service Account JSON')
        sa_layout = QHBoxLayout(sa_group)

        self.sa_path = QLineEdit()
        self.sa_path.setPlaceholderText('Select the JSON file...')
        self.sa_path.setReadOnly(True)
        sa_layout.addWidget(self.sa_path)

        sa_btn = QPushButton('Browse...')
        sa_btn.clicked.connect(self._browse_sa)
        sa_layout.addWidget(sa_btn)

        layout.addWidget(sa_group)

        # Web API Key
        key_group = QGroupBox('2. Web API Key')
        key_layout = QHBoxLayout(key_group)

        self.api_key_input = QLineEdit()
        self.api_key_input.setPlaceholderText('e.g. AIzaSy...')
        key_layout.addWidget(self.api_key_input)

        layout.addWidget(key_group)

        layout.addSpacing(20)

        self.save_btn = QPushButton('Save & Continue')
        self.save_btn.clicked.connect(self._save)
        self.save_btn.setStyleSheet(
            'background-color: #1A237E; color: white; padding: 12px 24px; font-size: 16px;'
        )
        layout.addWidget(self.save_btn)

    def _browse_sa(self):
        path, _ = QFileDialog.getOpenFileName(
            self, 'Select Service Account JSON', '',
            'JSON Files (*.json);;All Files (*)',
        )
        if path:
            self.sa_path.setText(path)

    def _save(self):
        sa = self.sa_path.text().strip()
        key = self.api_key_input.text().strip()

        if not sa:
            return QMessageBox.warning(self, 'Missing', 'Please select a service account file.')
        if not os.path.exists(sa):
            return QMessageBox.warning(self, 'Invalid', 'Service account file does not exist.')
        if not key:
            return QMessageBox.warning(self, 'Missing', 'Please enter the Web API Key.')

        config_manager.set_service_account_path(sa)
        config_manager.set_web_api_key(key)
        self.on_done()


# ── Login screen ───────────────────────────────────────────────────

class LoginScreen(QWidget):
    """Email/password login, validated against Firebase Auth + role check."""

    def __init__(self, on_logged_in):
        super().__init__()
        self.on_logged_in = on_logged_in
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setSpacing(16)

        title = QLabel('Kabete Poly Admin Tool')
        title.setStyleSheet('font-size: 24px; font-weight: bold; color: #1A237E;')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        subtitle = QLabel('Grade & Timetable Manager')
        subtitle.setStyleSheet('font-size: 14px; color: #666;')
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(subtitle)

        layout.addSpacing(30)

        form = QFormLayout()
        self.email_input = QLineEdit()
        self.email_input.setPlaceholderText('teacher@kabetepoly.ac.ke')
        self.email_input.setStyleSheet('padding: 8px; font-size: 14px;')
        form.addRow('Email:', self.email_input)

        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText('Password')
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setStyleSheet('padding: 8px; font-size: 14px;')
        self.password_input.returnPressed.connect(self._login)
        form.addRow('Password:', self.password_input)

        layout.addLayout(form)

        self.login_btn = QPushButton('Connect')
        self.login_btn.clicked.connect(self._login)
        self.login_btn.setStyleSheet(
            'background-color: #1A237E; color: white; padding: 12px 24px; font-size: 16px;'
        )
        layout.addWidget(self.login_btn)

        self.error_label = QLabel('')
        self.error_label.setStyleSheet('color: #F44336; font-size: 12px;')
        self.error_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.error_label)

        layout.addStretch()

    def _login(self):
        email = self.email_input.text().strip()
        password = self.password_input.text()

        if not email or not password:
            self.error_label.setText('Please enter email and password.')
            return

        self.login_btn.setEnabled(False)
        self.login_btn.setText('Connecting...')
        self.error_label.setText('')

        try:
            api_key = config_manager.get_web_api_key()
            auth_client = FirebaseAuthClient(api_key)
            result = auth_client.sign_in_with_email(email, password)

            # Check user role in Firestore
            db = FirestoreClient.get()
            user = db.get_user_by_uid(result.uid)
            if user is None:
                user = db.get_user_by_email(email)

            if user is None:
                raise ValueError('User not found in the database. Contact an administrator.')

            allowed_roles = ['Teacher', 'Official', 'Admin']
            if user.role not in allowed_roles:
                raise ValueError(
                    f'Access denied. Your role ({user.role}) does not have '
                    f'permission to use this tool.'
                )

            self.on_logged_in(user)

        except ValueError as e:
            self.error_label.setText(str(e))
            self.login_btn.setEnabled(True)
            self.login_btn.setText('Connect')
        except Exception as e:
            self.error_label.setText(f'Connection failed: {e}')
            self.login_btn.setEnabled(True)
            self.login_btn.setText('Connect')


# ── Main application window ────────────────────────────────────────

class MainWindow(QMainWindow):
    def __init__(self, user: UserProfile):
        super().__init__()
        self.user = user
        self.setWindowTitle(f'Kabete Poly Admin — {user.name} ({user.role})')
        self.resize(1100, 700)

        central = QWidget()
        layout = QVBoxLayout(central)

        # Top bar with class selector
        top_bar = QHBoxLayout()
        top_label = QLabel('Select Class:')
        top_label.setStyleSheet('font-weight: bold; font-size: 14px;')

        self.class_combo = QComboBox()
        self.class_combo.setMinimumWidth(250)
        self.class_combo.currentTextChanged.connect(self._on_class_changed)
        self.class_combo.setStyleSheet('padding: 5px; font-size: 14px;')

        self.refresh_classes_btn = QPushButton('Refresh Class List')
        self.refresh_classes_btn.clicked.connect(self._refresh_classes)
        self.refresh_classes_btn.setStyleSheet('padding: 5px 10px;')

        top_bar.addWidget(top_label)
        top_bar.addWidget(self.class_combo)
        top_bar.addWidget(self.refresh_classes_btn)
        top_bar.addStretch()

        # User info label
        user_label = QLabel(f'{user.name} ({user.regNo}) — {user.role}')
        user_label.setStyleSheet('color: #666; font-size: 12px;')
        top_bar.addWidget(user_label)

        layout.addLayout(top_bar)

        # Tabs
        self.tabs = QTabWidget()
        self.grade_editor = GradeEditor()
        self.timetable_editor = TimetableEditor()
        self.tabs.addTab(self.grade_editor, 'Grade Entry')
        self.tabs.addTab(self.timetable_editor, 'Timetable Editor')
        layout.addWidget(self.tabs)

        self.setCentralWidget(central)

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage(f'Connected as {user.name} ({user.role})')

        self._refresh_classes()

    def _refresh_classes(self):
        try:
            db = FirestoreClient.get()
            classes = db.list_classes()
            current = self.class_combo.currentText()
            self.class_combo.blockSignals(True)
            self.class_combo.clear()
            self.class_combo.addItems(classes)
            if current in classes:
                self.class_combo.setCurrentText(current)
            self.class_combo.blockSignals(False)
            self.grade_editor.refresh_classes(classes)
            self.status.showMessage(f'{len(classes)} classes loaded')
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to load classes:\n{e}')

    def _on_class_changed(self, class_id: str):
        self.grade_editor.set_class(class_id)
        self.timetable_editor.set_class(class_id)
        self.status.showMessage(f'Selected: {class_id}')


# ── App entry point ────────────────────────────────────────────────

class App(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('Kabete Poly Admin Tool')
        self.resize(500, 450)

        self.stack = QWidget()
        self.stack_layout = QVBoxLayout(self.stack)
        self.setCentralWidget(self.stack)

        self._show_next()

    def _show_next(self):
        # Clear any existing widget
        while self.stack_layout.count():
            w = self.stack_layout.takeAt(0)
            if w.widget():
                w.widget().hide()

        if config_manager.is_configured():
            login = LoginScreen(self._on_logged_in)
            self.stack_layout.addWidget(login)
        else:
            setup = SetupWizard(self._on_setup_done)
            self.stack_layout.addWidget(setup)

    def _on_setup_done(self):
        # Initialize Firestore, then show login
        try:
            sa_path = config_manager.get_service_account_path()
            FirestoreClient.init_from_path(sa_path)
            self._show_next()
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to initialize Firestore:\n{e}')

    def _on_logged_in(self, user):
        self.main_window = MainWindow(user)
        self.main_window.show()
        self.close()


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')

    font = QFont('Segoe UI', 10)
    app.setFont(font)

    window = App()
    window.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
