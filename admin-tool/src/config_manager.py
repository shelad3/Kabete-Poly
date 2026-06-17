"""
Manages local configuration — service account path and Web API key.
"""

import json
import os
from pathlib import Path

CONFIG_DIR = Path(os.environ.get('APPDATA', str(Path.home() / '.config'))) / 'KabeteAdminTool'
CONFIG_PATH = CONFIG_DIR / 'settings.json'


def _ensure_config():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps({'service_account_path': '', 'web_api_key': ''}, indent=2))


def load() -> dict:
    _ensure_config()
    with open(CONFIG_PATH) as f:
        return json.load(f)


def save(data: dict):
    _ensure_config()
    with open(CONFIG_PATH, 'w') as f:
        json.dump(data, f, indent=2)


def get_service_account_path() -> str:
    cfg = load()
    return cfg.get('service_account_path', '')


def set_service_account_path(path: str):
    cfg = load()
    cfg['service_account_path'] = path
    save(cfg)


def get_web_api_key() -> str:
    cfg = load()
    return cfg.get('web_api_key', '')


def set_web_api_key(key: str):
    cfg = load()
    cfg['web_api_key'] = key
    save(cfg)


def is_configured() -> bool:
    cfg = load()
    sa = cfg.get('service_account_path', '')
    key = cfg.get('web_api_key', '')
    return bool(sa and os.path.exists(sa) and key)
