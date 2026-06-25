import json
import os
from typing import Optional

import firebase_admin
from firebase_admin import credentials, firestore, storage as fb_storage

from models import GradeRecord, TimetableEntry, UserProfile


class FirestoreClient:
    _instance: Optional['FirestoreClient'] = None

    def __init__(self, service_account_path: str, storage_bucket: str = ''):
        if not os.path.exists(service_account_path):
            raise FileNotFoundError(f'Service account not found: {service_account_path}')

        cred = credentials.Certificate(service_account_path)

        if not storage_bucket:
            with open(service_account_path) as f:
                sa = json.load(f)
            storage_bucket = f'{sa["project_id"]}.appspot.com'

        firebase_admin.initialize_app(cred, {'storageBucket': storage_bucket})
        self.db = firestore.client()

    @classmethod
    def init_from_path(cls, path: str, storage_bucket: str = '') -> 'FirestoreClient':
        cls._instance = cls(path, storage_bucket)
        return cls._instance

    @classmethod
    def get(cls) -> 'FirestoreClient':
        if cls._instance is None:
            raise RuntimeError('FirestoreClient not initialized')
        return cls._instance

    # ---- Classes ----

    def list_classes(self) -> list[str]:
        docs = self.db.collection('classes').stream()
        return sorted(doc.id for doc in docs)

    # ---- Students ----

    def get_students_in_class(self, class_id: str) -> list[UserProfile]:
        users = self.db.collection('users').where('enrolledClasses', 'array_contains', class_id).stream()
        return [UserProfile.from_doc(doc) for doc in users]

    # ---- User Lookup ----

    def get_user_by_email(self, email: str) -> Optional[UserProfile]:
        users = self.db.collection('users').where('email', '==', email).limit(1).stream()
        for doc in users:
            return UserProfile.from_doc(doc)
        return None

    def get_user_by_uid(self, uid: str) -> Optional[UserProfile]:
        doc = self.db.collection('users').document(uid).get()
        if doc.exists:
            return UserProfile.from_doc(doc)
        return None

    def get_all_grades_for_class(self, class_id: str, term: str, academic_year: str) -> dict[str, list[GradeRecord]]:
        """Fetch all grades for a class in a given term/year, grouped by studentId."""
        docs = (
            self.db.collection('grades')
            .where('classId', '==', class_id)
            .stream()
        )
        result: dict[str, list[GradeRecord]] = {}
        for doc in docs:
            g = GradeRecord.from_doc(doc)
            if g.term != term or g.academicYear != academic_year:
                continue
            result.setdefault(g.studentId, []).append(g)
        return result

    # ---- Grades ----

    def get_grades(self, class_id: str, subject: str, term: str, academic_year: str) -> dict[str, GradeRecord]:
        query = (
            self.db.collection('grades')
            .where('classId', '==', class_id)
            .where('subjectName', '==', subject)
            .where('term', '==', term)
            .where('academicYear', '==', academic_year)
        )
        docs = query.stream()
        return {doc.get('studentId'): GradeRecord.from_doc(doc) for doc in docs}

    def save_grade(self, grade: GradeRecord) -> str:
        if grade.doc_id:
            self.db.collection('grades').document(grade.doc_id).set(grade.to_dict(), merge=True)
            return grade.doc_id
        else:
            doc_ref = self.db.collection('grades').document()
            doc_ref.set(grade.to_dict())
            return doc_ref.id

    def save_grades_batch(self, grades: list[GradeRecord]) -> tuple[int, list[str]]:
        batch = self.db.batch()
        ids = []
        for g in grades:
            if g.doc_id:
                ref = self.db.collection('grades').document(g.doc_id)
                batch.set(ref, g.to_dict(), merge=True)
                ids.append(g.doc_id)
            else:
                ref = self.db.collection('grades').document()
                batch.set(ref, g.to_dict())
                ids.append(ref.id)
        batch.commit()
        return len(grades), ids

    def delete_grade(self, doc_id: str):
        self.db.collection('grades').document(doc_id).delete()

    # ---- Timetable ----

    def get_timetable(self, class_id: str) -> list[TimetableEntry]:
        docs = (
            self.db.collection('classes')
            .document(class_id)
            .collection('timetable')
            .order_by('day')
            .order_by('time')
            .stream()
        )
        return [TimetableEntry.from_doc(doc) for doc in docs]

    def add_timetable_entry(self, class_id: str, entry: TimetableEntry) -> str:
        ref = (
            self.db.collection('classes')
            .document(class_id)
            .collection('timetable')
            .document()
        )
        ref.set(entry.to_dict())
        return ref.id

    def delete_timetable_entry(self, class_id: str, entry_id: str):
        (
            self.db.collection('classes')
            .document(class_id)
            .collection('timetable')
            .document(entry_id)
            .delete()
        )

    # ---- CSV Import Helpers ----

    def timetable_entry_exists(self, class_id: str, day: str, time: str, unit: str) -> bool:
        docs = (
            self.db.collection('classes')
            .document(class_id)
            .collection('timetable')
            .where('day', '==', day)
            .where('time', '==', time)
            .where('unit', '==', unit)
            .limit(1)
            .stream()
        )
        for _ in docs:
            return True
        return False

    def import_timetable_batch(self, class_id: str, entries: list[dict]) -> int:
        batch = self.db.batch()
        for entry in entries:
            ref = (
                self.db.collection('classes')
                .document(class_id)
                .collection('timetable')
                .document()
            )
            batch.set(ref, entry)
        batch.commit()
        return len(entries)

    def grade_exists(self, class_id: str, subject: str, term: str, year: str, student_id: str) -> bool:
        docs = (
            self.db.collection('grades')
            .where('classId', '==', class_id)
            .where('subjectName', '==', subject)
            .where('term', '==', term)
            .where('academicYear', '==', year)
            .where('studentId', '==', student_id)
            .limit(1)
            .stream()
        )
        for _ in docs:
            return True
        return False

    def import_grades_batch(self, grades: list[dict]) -> int:
        batch = self.db.batch()
        for g in grades:
            ref = self.db.collection('grades').document()
            batch.set(ref, g)
        batch.commit()
        return len(grades)

    # ---- Report Auto-Upload ----

    def upload_report_pdf(self, pdf_path: str, student_id: str, reg_no: str, class_id: str, term: str, year: str) -> str:
        """Upload a report card PDF to Firebase Storage and save reference in reports collection."""
        try:
            bucket = fb_storage.bucket()
            blob_name = f'reports/{class_id}/{term}_{year}/{reg_no}_{os.path.basename(pdf_path)}'
            blob = bucket.blob(blob_name)
            blob.upload_from_filename(pdf_path)
            blob.make_public()
            download_url = blob.public_url

            # Save reference in reports collection
            self.db.collection('reports').add({
                'studentId': student_id,
                'regNo': reg_no,
                'classId': class_id,
                'term': term,
                'academicYear': year,
                'downloadUrl': download_url,
                'fileName': os.path.basename(pdf_path),
                'createdAt': firestore.SERVER_TIMESTAMP,
            })
            return download_url
        except Exception as e:
            print(f'[WARN] Report upload skipped (Storage not configured): {e}')
            return ''
