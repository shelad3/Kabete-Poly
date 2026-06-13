"""
Upload the exported timetable_export.json to Firestore.
Each class's timetable entries are written to classes/{classId}/timetable/{docId}.

Usage:
  source venv/bin/activate
  python -m src.migrate_timetable --json ../../timetable_export.json
"""

import argparse
import json
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from src.config_manager import get_service_account_path
from src.firestore_client import FirestoreClient


def migrate(json_path: str, clear_first: bool = False):
    sa_path = get_service_account_path()
    if not sa_path or not os.path.exists(sa_path):
        print('ERROR: Service account not configured or file missing.')
        print('Run the admin tool first to set it up, or set config/settings.json manually.')
        return

    print('Initializing Firestore...')
    db = FirestoreClient.init_from_path(sa_path)

    with open(json_path) as f:
        cohorts = json.load(f)

    print(f'Loaded {len(cohorts)} cohorts from JSON')

    for class_id, days in cohorts.items():
        print(f'\nProcessing {class_id}...')
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

        print(f'  {len(entries)} timetable entries')

        if clear_first:
            # Delete existing entries
            existing = (
                db.db.collection('classes')
                .document(class_id)
                .collection('timetable')
                .list_documents()
            )
            deleted = 0
            for doc in existing:
                doc.delete()
                deleted += 1
            if deleted:
                print(f'  Deleted {deleted} existing entries')

        # Batch write new entries
        batch = db.db.batch()
        for entry in entries:
            ref = (
                db.db.collection('classes')
                .document(class_id)
                .collection('timetable')
                .document()
            )
            batch.set(ref, entry)

        batch.commit()
        print(f'  Uploaded {len(entries)} entries')

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
