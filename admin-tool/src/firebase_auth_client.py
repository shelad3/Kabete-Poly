"""
Firebase Auth REST API client for email/password sign-in.
No client SDK needed — uses the Firebase Auth REST endpoint.
"""

import json
from dataclasses import dataclass
from typing import Optional

import requests


@dataclass
class AuthResult:
    uid: str
    email: str
    id_token: str
    refresh_token: str
    local_id: str


class FirebaseAuthClient:
    BASE_URL = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'

    def __init__(self, web_api_key: str):
        self.web_api_key = web_api_key

    def sign_in_with_email(self, email: str, password: str) -> Optional[AuthResult]:
        """Authenticate with Firebase Auth using email/password."""
        url = f'{self.BASE_URL}?key={self.web_api_key}'
        payload = {
            'email': email,
            'password': password,
            'returnSecureToken': True,
        }
        try:
            resp = requests.post(url, json=payload, timeout=10)
            data = resp.json()

            if resp.status_code != 200:
                error_msg = data.get('error', {}).get('message', 'Unknown error')
                raise ValueError(f'Authentication failed: {error_msg}')

            return AuthResult(
                uid=data.get('localId', ''),
                email=data.get('email', ''),
                id_token=data.get('idToken', ''),
                refresh_token=data.get('refreshToken', ''),
                local_id=data.get('localId', ''),
            )
        except requests.RequestException as e:
            raise ValueError(f'Network error: {e}')
