#!/usr/bin/env python3
"""Bulk import teaching materials into the Notes Library.

For each file: maps it to ({subject, level, type, classId, title, description})
by filename heuristics (with an explicit override table for known files), uploads
the file to Cloudinary (folder materials/<type>) and creates a `teaching_materials`
doc in Firestore. Idempotent: skips any file whose fileName is already present.

Usage:
  CERT=<adminsdk.json> python3 notes_import.py            # imports the default list (dry-run first)
  CERT=... python3 notes_import.py --yes                  # actually upload + write
  CERT=... python3 notes_import.py --paths file1.pdf ... --yes
"""
import argparse
import datetime
import os
import re
import sys
import time
import urllib.request
import uuid

CLOUD_NAME = "dpa8tbxdj"
UPLOAD_PRESET = "Kabete_uploads"
FOLDER = "materials"

DEFAULT_PATHS = [
    "/home/sheldon/Downloads/Synchronous machines, single phase motors and special machines-1_093227.pdf",
    "/home/sheldon/Downloads/RELAYS.pdf",
    "/home/sheldon/Downloads/QUESTION PPAPER EET 400 500 J26 BELLS AND ALARMS.pdf",
    "/home/sheldon/Downloads/Practice drawing eBook (second edition) - Practice-drawing-ebook (1).pdf",
    "/home/sheldon/Downloads/QUESTION PAPER FORMATIVE 2 BELLS.pdf",
    "/home/sheldon/Downloads/PRACTICAL guide 3 solar.docx",
    "/home/sheldon/Downloads/PRACTICAL CHECKLIST PERFORM BELL AND ALARM INSTALLATION.pdf",
    "/home/sheldon/Downloads/PRACTICAL CHECKLIST PERFORM BELL AND ALARM INSTALLATION.docx",
    "/home/sheldon/Downloads/PRACTICAL ASSESSMENT 4 checklist.docx.pdf",
    "/home/sheldon/Downloads/PRACTICAL ASSESSMENT 3 candidate.docx",
    "/home/sheldon/Downloads/Maintenance of Peace, Order, and Discipline During the KAPOSA Elections and Campaign Period .pdf",
    "/home/sheldon/Downloads/machines and utilization LEC notes.pdf",
    "/home/sheldon/Downloads/Lecture notes on Zener diodes (1).pdf",
    "/home/sheldon/Downloads/Lecture notes on Transistor Biasing (1).pdf",
    "/home/sheldon/Downloads/Lecture notes on Power Supplies Module 01 (1).pdf",
    "/home/sheldon/Downloads/Lecture notes on FETs 2 (1).pdf",
    "/home/sheldon/Downloads/Lecture notes on FETs (1).pdf",
    "/home/sheldon/Downloads/Lecture notes Basic Electronics.pdf",
    "/home/sheldon/Downloads/Geometric and Engineering Drawing(1).pdf",
    "/home/sheldon/Downloads/EXTENSION OF CDACC REGISTRATION FOR JULY 2026.pdf",
    "/home/sheldon/Downloads/ELECTRONICS notes.docx",
    "/home/sheldon/Downloads/ELECTRICAL MACHINE WINDING.pdf",
    "/home/sheldon/Downloads/DOC0024.pdf",
    "/home/sheldon/Downloads/Digital Electronics-1.pdf",
    "/home/sheldon/Downloads/CONTROL SYSTEMS notes intro,block diagrams.pdf",
    "/home/sheldon/Downloads/CHECKLIST BELLS FORMATIVE 2.pdf",
    "/home/sheldon/Downloads/CDACC TT FOR JULY 2026.pdf",
    "/home/sheldon/Downloads/CBET ELECTRONICS (2).pdf",
    "/home/sheldon/Downloads/CANDIDATE PRACTICAL PERFORM BELL AND ALARM INSTALLATION.pdf",
    "/home/sheldon/Downloads/Candidate PRACTICAL ASSESSMENT 4.docx",
    "/home/sheldon/Downloads/Candidate Practical 2.docx",
    "/home/sheldon/Downloads/Candidate Practical 1.pdf",
    "/home/sheldon/Downloads/CamScanner 07-08-2026 18.00.pdf",
    "/home/sheldon/Downloads/AutoCAD 2016 For Beginners ( PDFDrive ).pdf",
    "/home/sheldon/Downloads/APPLY COMMUNICATION_SKILLS_NOTES.pdf",
    "/home/sheldon/Downloads/ANGLES.pdf",
    "/home/sheldon/Downloads/analogue electronics 2.pdf",
    "/home/sheldon/Downloads/ANALOGUE ELECTRONICS 11 COURSE OUTLINE.docx",
    "/home/sheldon/Downloads/ANALOGUE ELECTRONICS 1 COURSE OUTLINE.docx",
    "/home/sheldon/Downloads/Analogue Electronics 1, DEE 1 notes_075733.pdf",
    "/home/sheldon/Downloads/703480533-1606886007473-bells-and-alarm-circuit-1.pdf",
    "/home/sheldon/Downloads/2026m_ct.pdf",
    "/home/sheldon/Downloads/CBET ELECTRONICS (1).pdf",
]

# Exact-filename overrides: {basename: (subject, type, level, classId or None, title)}
OVERRIDES = {
    "Synchronous machines, single phase motors and special machines-1_093227.pdf": (
        "Electrical Machines", "notes", "LEVEL 6", None,
        "Synchronous Machines, Single Phase Motors and Special Machines"),
    "RELAYS.pdf": ("Electrical Machines", "notes", "LEVEL 6", None, "Relays"),
    "QUESTION PPAPER EET 400 500 J26 BELLS AND ALARMS.pdf": (
        "Bells & Alarms", "past_paper", "LEVEL 4", None,
        "Question Paper: Bells and Alarms (EET 400/500 J26)"),
    "Practice drawing eBook (second edition) - Practice-drawing-ebook (1).pdf": (
        "Engineering Drawing", "book", "LEVEL 6", None,
        "Practice Drawing eBook (Second Edition)"),
    "QUESTION PAPER FORMATIVE 2 BELLS.pdf": (
        "Bells & Alarms", "past_paper", "LEVEL 4", None,
        "Question Paper: Bells and Alarms Formative 2"),
    "PRACTICAL guide 3 solar.docx": ("Solar PV", "practical", "LEVEL 5", None,
                                     "Practical Guide 3: Solar"),
    "PRACTICAL CHECKLIST PERFORM BELL AND ALARM INSTALLATION.pdf": (
        "Bells & Alarms", "checklist", "LEVEL 4", None,
        "Practical Checklist: Bell and Alarm Installation"),
    "PRACTICAL CHECKLIST PERFORM BELL AND ALARM INSTALLATION.docx": (
        "Bells & Alarms", "checklist", "LEVEL 4", None,
        "Practical Checklist: Bell and Alarm Installation"),
    "PRACTICAL ASSESSMENT 4 checklist.docx.pdf": (
        "Bells & Alarms", "checklist", "LEVEL 4", None,
        "Practical Assessment 4 Checklist"),
    "PRACTICAL ASSESSMENT 3 candidate.docx": (
        "Bells & Alarms", "practical", "LEVEL 4", None,
        "Practical Assessment 3 (Candidate)"),
    "Maintenance of Peace, Order, and Discipline During the KAPOSA Elections and Campaign Period .pdf": (
        "Student Life & Governance", "general", "", None,
        "KAPOSA Elections: Maintenance of Peace, Order and Discipline"),
    "machines and utilization LEC notes.pdf": (
        "Electrical Machines", "notes", "LEVEL 6", None, "Machines and Utilization"),
    "Lecture notes on Zener diodes (1).pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "Zener Diodes"),
    "Lecture notes on Transistor Biasing (1).pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "Transistor Biasing"),
    "Lecture notes on Power Supplies Module 01 (1).pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "Power Supplies — Module 01"),
    "Lecture notes on FETs 2 (1).pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "FETs (Part 2)"),
    "Lecture notes on FETs (1).pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "FETs (Part 1)"),
    "Lecture notes Basic Electronics.pdf": (
        "Basic Electronics", "notes", "LEVEL 6", None, "Basic Electronics"),
    "Geometric and Engineering Drawing(1).pdf": (
        "Engineering Drawing", "notes", "LEVEL 6", None, "Geometric and Engineering Drawing"),
    "EXTENSION OF CDACC REGISTRATION FOR JULY 2026.pdf": (
        "Examinations (CDACC)", "notice", "", None,
        "Extension of CDACC Registration for July 2026"),
    "ELECTRONICS notes.docx": ("Electronics", "notes", "LEVEL 6", None, "Electronics Notes"),
    "ELECTRICAL MACHINE WINDING.pdf": (
        "Electrical Machines", "notes", "LEVEL 6", None, "Electrical Machine Winding"),
    "DOC0024.pdf": ("General", "general", "", None, "General Material"),
    "Digital Electronics-1.pdf": (
        "Digital Electronics", "notes", "LEVEL 6", None, "Digital Electronics"),
    "CONTROL SYSTEMS notes intro,block diagrams.pdf": (
        "Control Systems", "notes", "LEVEL 6", None,
        "Control Systems: Introduction and Block Diagrams"),
    "CHECKLIST BELLS FORMATIVE 2.pdf": (
        "Bells & Alarms", "checklist", "LEVEL 4", None,
        "Checklist: Bells Formative 2"),
    "CDACC TT FOR JULY 2026.pdf": (
        "Examinations (CDACC)", "timetable", "", None,
        "CDACC Timetable for July 2026"),
    "CBET ELECTRONICS (2).pdf": ("Electronics", "notes", "LEVEL 6", None, "CBET Electronics"),
    "CANDIDATE PRACTICAL PERFORM BELL AND ALARM INSTALLATION.pdf": (
        "Bells & Alarms", "practical", "LEVEL 4", None,
        "Candidate Practical: Bell and Alarm Installation"),
    "Candidate PRACTICAL ASSESSMENT 4.docx": (
        "Bells & Alarms", "practical", "LEVEL 4", None,
        "Candidate Practical Assessment 4"),
    "Candidate Practical 2.docx": (
        "Bells & Alarms", "practical", "LEVEL 4", None, "Candidate Practical 2"),
    "Candidate Practical 1.pdf": (
        "Bells & Alarms", "practical", "LEVEL 4", None, "Candidate Practical 1"),
    "CamScanner 07-08-2026 18.00.pdf": ("General", "general", "", None, None),
    "AutoCAD 2016 For Beginners ( PDFDrive ).pdf": (
        "Engineering Drawing", "book", "LEVEL 6", None, "AutoCAD 2016 for Beginners"),
    "APPLY COMMUNICATION_SKILLS_NOTES.pdf": (
        "Communication Skills", "notes", "LEVEL 6", None, "Communication Skills"),
    "ANGLES.pdf": ("Engineering Drawing", "notes", "LEVEL 6", None, "Angles"),
    "analogue electronics 2.pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None, "Analogue Electronics II"),
    "ANALOGUE ELECTRONICS 11 COURSE OUTLINE.docx": (
        "Analogue Electronics", "course_outline", "LEVEL 6", None,
        "Analogue Electronics I — Course Outline"),
    "ANALOGUE ELECTRONICS 1 COURSE OUTLINE.docx": (
        "Analogue Electronics", "course_outline", "LEVEL 6", None,
        "Analogue Electronics I — Course Outline"),
    "Analogue Electronics 1, DEE 1 notes_075733.pdf": (
        "Analogue Electronics", "notes", "LEVEL 6", None,
        "Analogue Electronics I — DEE 1 Notes"),
    "703480533-1606886007473-bells-and-alarm-circuit-1.pdf": (
        "Bells & Alarms", "notes", "LEVEL 4", None, "Bells and Alarm Circuit"),
    "2026m_ct.pdf": ("General", "general", "", None, None),
    "CBET ELECTRONICS (1).pdf": ("Electronics", "notes", "LEVEL 6", None, "CBET Electronics"),
}


def infer(path):
    base = os.path.basename(path)
    if base in OVERRIDES:
        subject, mtype, level, cls, title = OVERRIDES[base]
        desc = ""
    else:
        up = base.upper()
        subject = "General"
        mtype = "notes"
        level = "LEVEL 6"
        cls = None
        title = None
        if re.search(r"BELL|ALARM", up): subject = "Bells & Alarms"
        if re.search(r"DRAW|AUTOCAD|GED|ANGLE", up): subject = "Engineering Drawing"
        if re.search(r"MACHINE|RELAY|MOTOR|WINDING", up): subject = "Electrical Machines"
        if re.search(r"ELECTRON", up): subject = "Electronics"
        if re.search(r"CONTROL SYSTEM", up): subject = "Control Systems"
        if re.search(r"COMMUNICATION", up): subject = "Communication Skills"
        if re.search(r"SOLAR|PV ", up): subject = "Solar PV"
        if re.search(r"CDACC|TT FOR", up): subject = "Examinations (CDACC)"
        if re.search(r"QUESTION|PPAPER|PAPER", up): mtype = "past_paper"
        if re.search(r"CHECKLIST", up): mtype = "checklist"
        if re.search(r"PRACTICAL|CANDIDATE", up): mtype = "practical"
        if re.search(r"COURSE OUTLINE", up): mtype = "course_outline"
        if re.search(r"EBOOK|FOR BEGINNERS", up): mtype = "book"
        if re.search(r"TIMETABLE|[ -]TT[ .]|FORMATIVE", up): mtype = "timetable"
        desc = ""
    # derive class code + level from filename
    m = re.search(r"([A-Z]{2,5}-?\d{3})\s+([MSJ]\d{2})", base.upper())
    if m and cls is None:
        code, cohort = m.group(1), m.group(2)
        # normalise "400/500" splits
        candidate = f"{code} {cohort}"
        lvl = "LEVEL 4" if code.endswith("400") or code.endswith("300") else \
            ("LEVEL 5" if code.endswith("500") else "LEVEL 6")
        if level == "" or level == "LEVEL 6":
            level = lvl
        cls = candidate
    if level == "LEVEL 6" and re.search(r"(EET|EIT|EOP)\s*4\d\d", base.upper()):
        level = "LEVEL 4"
    if level == "LEVEL 6" and re.search(r"(EET|EIT|EOP)\s*5\d\d", base.upper()):
        level = "LEVEL 5"
    title = title or re.sub(r"[_-]+|\(1\)|\(2\)", " ", os.path.splitext(base)[0]).strip()
    return subject, mtype, level, cls, title, desc


def upload_file(path, folder):
    base = os.path.basename(path)
    public_id = re.sub(r"[^a-zA-Z0-9_-]", "_", os.path.splitext(base)[0]).rstrip("_") \
        + "_" + uuid.uuid4().hex[:6]
    bound = uuid.uuid4().hex
    with open(path, "rb") as f:
        parts = []
        def field(name, value):
            parts.append(
                f'--{bound}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        def file_field(name, filename, data):
            parts.append(
                f'--{bound}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
                f'Content-Type: application/octet-stream\r\n\r\n'.encode() + data + b"\r\n")
        field("file", "")  # placeholder replaced below
        # rebuild with actual file
        parts = []
        field("upload_preset", UPLOAD_PRESET)
        field("folder", folder or "")
        field("resource_type", "auto")
        field("public_id", public_id)
        file_field("file", base, f.read())
        parts.append(f"--{bound}--\r\n".encode())
    body = b"".join(parts)
    req = urllib.request.Request(
        f"https://api.cloudinary.com/v1_1/{CLOUD_NAME}/auto/upload",
        data=body, method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={bound}"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json_load(resp.read())


def json_load(data):
    import json
    return json.loads(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--paths", nargs="+", default=DEFAULT_PATHS)
    ap.add_argument("--yes", action="store_true", help="actually upload + write docs")
    args = ap.parse_args()

    import firebase_admin
    from firebase_admin import credentials, firestore
    cred = credentials.Certificate(os.environ["CERT"])
    app = firebase_admin.initialize_app(cred)
    db = firestore.client(app)

    ids = set(d.id for d in db.collection("classes").get())

    manifest = []
    for p in args.paths:
        if not os.path.isfile(p):
            print("MISSING:", p); continue
        subject, mtype, level, cls, title, desc = infer(p)
        if cls and cls not in ids:
            cls = None
        ext = os.path.splitext(p)[1].lstrip(".").lower()
        manifest.append({
            "path": p, "base": os.path.basename(p), "subject": subject,
            "type": mtype, "level": level, "classId": cls,
            "title": title or os.path.splitext(os.path.basename(p))[0],
            "description": desc, "ext": ext, "size": os.path.getsize(p),
        })

    # existing filenames (idempotency)
    existing = {d.get("fileName") for d in db.collection("teaching_materials").get()}
    todo = [m for m in manifest if m["base"] not in existing]
    print(f"\nFiles: {len(manifest)} | already imported: {len(manifest)-len(todo)}\n")
    for m in todo:
        print(f"  {m['base'][:60]:60} -> {m['subject']} [{m['type']}] {m['level']} clazz={m['classId']}")
    if not args.yes:
        print("\nDRY-RUN. Re-run with --yes to upload & write docs.")
        return
    if not todo:
        print("Nothing to do.")
        return

    uploaded_by = "57cakMbMecPmXxdn498uxWDAAmY2"
    ok = 0
    for m in todo:
        try:
            r = upload_file(m["path"], f"{FOLDER}/{m['type']}")
            url = r.get("secure_url") or r.get("url")
            if not url:
                print("  upload failed:", m["base"], r); continue
            db.collection("teaching_materials").add({
                "title": m["title"], "subject": m["subject"], "level": m["level"],
                "classId": m["classId"], "type": m["type"], "fileUrl": url,
                "fileName": m["base"], "fileType": m["ext"], "fileSize": m["size"],
                "description": m["description"], "uploadedBy": uploaded_by,
                "uploadedAt": firestore.SERVER_TIMESTAMP,
            })
            ok += 1
            print(f"  OK ({ok}) {m['base'][:60]}")
        except Exception as e:
            print(f"  FAIL {m['base']}: {e}")
        time.sleep(0.4)
    print(f"\nDONE. Uploaded {ok}/{len(todo)}.")


if __name__ == "__main__":
    main()