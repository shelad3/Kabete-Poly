import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from pdf_parser import (
    PdfExamTimetableParser,
    PdfSittingPlanParser,
    TimetableParseResult,
)


def word(text, x0, top=100.0):
    return {'text': text, 'x0': x0, 'top': top}


class FakePage:
    def __init__(self, text):
        self._text = text

    def extract_text(self):
        return self._text


class FakePdf:
    def __init__(self, text):
        self.pages = [FakePage(text)]


class DetectionTests(unittest.TestCase):
    def test_sitting_plan_title(self):
        pdf = FakePdf('MASTER TIMETABLE PER DAY SITTING PLAN')
        self.assertTrue(PdfExamTimetableParser._is_sitting_plan(pdf))

    def test_sitting_plan_headers(self):
        pdf = FakePdf('CURRICULUM NAME LEVEL ASSESSMENT TYPE VENUE')
        self.assertTrue(PdfExamTimetableParser._is_sitting_plan(pdf))

    def test_class_timetable_not_misdetected(self):
        pdf = FakePdf('ELECTRICAL DEPARTMENT TIMETABLE')
        self.assertFalse(PdfExamTimetableParser._is_sitting_plan(pdf))


class CleanCodeTests(unittest.TestCase):
    def test_separators_normalized(self):
        parser = PdfSittingPlanParser()
        self.assertEqual(parser._clean_code('DFM/600/S26'), 'DFM 600 S26')
        self.assertEqual(parser._clean_code('BCT600/M25'), 'BCT 600 M25')
        self.assertEqual(parser._clean_code('CBET BAF 605 M25'), 'BAF 605 M25')
        self.assertEqual(parser._clean_code('ICT500S26'), 'ICT 500 S26')


class RowParseTests(unittest.TestCase):
    def test_parse_row_reconstructs_interleaved_unit_and_date(self):
        parser = PdfSittingPlanParser()
        result = TimetableParseResult()
        words = [
            word('4', 40),
            word('AGRICULTURE', 100),
            word('DAIRY', 181),
            word('FARM', 200),
            word('MANAGEMENT', 220),
            word('LEVEL', 268),
            word('6', 287),
            word('MODULAR', 311),
            word('DFM', 353),
            word('600', 361),
            word('S26', 369),
            word('9CARRY', 430),
            word('OUT', 460),
            word('DAIRY', 480),
            word('YOUNG', 500),
            word('STOCK', 520),
            word('16/11/2026', 568),
            word('8.00AMSW', 618),
            word('G-GH', 704),
            word('(9)', 719),
        ]
        sno_match = re.match(r'^(\d+)([A-Z].*)?$', '4')
        entry, meta, date, session = parser._parse_row(
            words, sno_match, '2026-11-16', '08:00', 1, result
        )
        self.assertIsNotNone(entry)
        self.assertEqual(entry['class_id'], 'DFM 600 S26')
        self.assertEqual(entry['subject'], 'CARRY OUT DAIRY YOUNG STOCK')
        self.assertEqual(entry['date'], '2026-11-16')
        self.assertEqual(entry['startTime'], '08:00')
        self.assertEqual(entry['endTime'], '11:00')
        self.assertEqual(entry['room'], 'G-GH')
        self.assertEqual(entry['type'], 'final')
        self.assertEqual(meta['department'], 'AGRICULTURE')
        self.assertEqual(meta['curriculum'], 'DAIRY FARM MANAGEMENT')
        self.assertEqual(meta['level'], '6')
        self.assertEqual(meta['cycle'], 'MODULAR')
        self.assertEqual(meta['class_size'], 9)
        self.assertEqual(result.errors, [])
        self.assertEqual(date, '2026-11-16')
        self.assertEqual(session, '08:00')

    def test_parse_row_keeps_overlapping_date_out_of_unit(self):
        parser = PdfSittingPlanParser()
        result = TimetableParseResult()
        words = [
            word('6', 40),
            word('ELECTRICAL', 80),
            word('AND', 120),
            word('ELECTRONICS', 140),
            word('ENGINEERING', 165),
            word('MEDICAL', 181),
            word('ENGINEERING', 215),
            word('LEVEL', 268),
            word('6', 287),
            word('MODULAR', 311),
            word('MDE', 353),
            word('600', 361),
            word('S25', 369),
            word('30Mainten1a6n/c1e1', 430),
            word('/I2I026', 582),
            word('8.00', 618),
            word('AMSW', 629),
            word('G-1H', 704),
            word('(30)', 719),
        ]
        sno_match = re.match(r'^(\d+)([A-Z].*)?$', '6')
        entry, meta, _, _ = parser._parse_row(
            words, sno_match, '2026-11-16', '08:00', 2, result
        )
        self.assertIsNotNone(entry)
        self.assertEqual(entry['subject'], 'Maintenance II')
        self.assertEqual(entry['date'], '2026-11-16')
        self.assertEqual(meta['curriculum'], 'MEDICAL ENGINEERING')
        self.assertEqual(result.errors, [])


class LevelCycleTests(unittest.TestCase):
    def test_level(self):
        parser = PdfSittingPlanParser()
        self.assertEqual(parser._extract_level('6MODULAR'), '6')
        self.assertEqual(parser._extract_level('LEVEL 6'), '6')
        self.assertEqual(parser._extract_level('5 CBET'), '5')

    def test_cycle(self):
        parser = PdfSittingPlanParser()
        self.assertEqual(parser._extract_cycle('6CYCLE'), 'CYCLE')
        self.assertEqual(parser._extract_cycle('MODULE 4'), 'MODULE 4')
        self.assertEqual(parser._extract_cycle('LEVEL 6 MODULAR'), 'MODULAR')

    def test_placeholder_curriculums_removed(self):
        parser = PdfSittingPlanParser()
        self.assertEqual(
            parser._clean_department_curriculum('BUSINESS', 'MODULAR'),
            ('BUSINESS', ''),
        )
        self.assertEqual(
            parser._clean_department_curriculum(
                'COMPUTING AND INFORMATICS', 'KNP CBET'
            ),
            ('COMPUTING AND INFORMATICS', ''),
        )


if __name__ == '__main__':
    unittest.main()
