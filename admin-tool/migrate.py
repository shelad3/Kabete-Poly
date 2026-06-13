"""
Upload timetable_export.json to Firestore.
Run from admin-tool/ directory.

Usage:
  source venv/bin/activate
  python migrate.py --json ../timetable_export.json --clear
"""

import argparse
import json
import sys
import os

# Ensure src/ is in the path
_src = os.path.join(os.path.dirname(__file__), 'src')
sys.path.insert(0, _src)

from config_manager import get_service_account_path, set_service_account_path, set_web_api_key
from firestore_client import FirestoreClient


def sanitize_id(name: str) -> str:
    """Firestore document IDs cannot contain slashes."""
    return name.replace('/', ' & ').replace('\\', ' & ').strip()


def migrate(json_path: str, clear_first: bool = False):
    sa_path = get_service_account_path()
    if not sa_path or not os.path.exists(sa_path):
        print('ERROR: Service account not configured or file missing.')
        print('Set it with: python -c "import config_manager; config_manager.set_service_account_path(\'/path/to/key.json\')"')
        return

    print(f'Using service account: {sa_path}')
    print('Initializing Firestore...')
    db = FirestoreClient.init_from_path(sa_path)

    with open(json_path) as f:
        cohorts = json.load(f)

    print(f'Loaded {len(cohorts)} cohorts from JSON')

    for raw_id, days in cohorts.items():
        class_id = sanitize_id(raw_id)
        changed = class_id != raw_id
        print(f'\n{class_id}...', end=' ', flush=True)
        if changed:
            print(f'(was "{raw_id}") ', end='', flush=True)

        entries = []
        for day, lessons in days.items():
            for lesson in lessons:
                entries.append({
                    'day': day,
                    'time': lesson.get('time', ''),
                    'unit': lesson.get('unit', ''),
                    'room': lesson.get('room', ''),
                    'lecturer': lesson.get('lecturer', ''),
                    'color': lesson.get('color', 4282339765),
                })

        if not entries:
            print('skipped (no entries)')
            continue

        # Ensure the class document exists (with original name stored)
        class_doc = db.db.collection('classes').document(class_id)
        if not class_doc.get().exists:
            class_doc.set({'id': class_id, '_originalName': raw_id if changed else '', 'migratedFromHardcoded': True})

        ref = class_doc.collection('timetable')

        if clear_first:
            existing = ref.list_documents()
            deleted = 0
            for doc in existing:
                doc.delete()
                deleted += 1
            if deleted:
                print(f'deleted {deleted}, ', end='')

        batch = db.db.batch()
        for entry in entries:
            batch.set(ref.document(), entry)
        batch.commit()

        print(f'uploaded {len(entries)} entries')

    print(f'\nDone! {len(cohorts)} classes processed.')


def main():
    parser = argparse.ArgumentParser(description='Migrate hardcoded timetable to Firestore')
    parser.add_argument('--json', required=True, help='Path to timetable_export.json')
    parser.add_argument('--clear', action='store_true', help='Delete existing entries before upload')
    args = parser.parse_args()

    if not os.path.exists(args.json):
        print(f'ERROR: File not found: {args.json}')
        sys.exit(1)

    migrate(args.json, clear_first=args.clear)


if __name__ == '__main__':
    main()
