// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'lesson.dart';
import 'schedule_item.dart';

class FeedItem {
  final String id;
  final DateTime date;
  final String type;
  final Lesson? lesson;
  final ScheduleItem? schedule;

  FeedItem.lesson(Lesson l)
    : id = l.id,
      date = l.date,
      type = 'lesson',
      lesson = l,
      schedule = null;

  FeedItem.schedule(ScheduleItem s)
    : id = s.id,
      date = s.date,
      type = 'schedule',
      lesson = null,
      schedule = s;
}
