import 'dart:convert';

import 'package:classsync/domain/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('summary language override metadata', () {
    test('keeps the override separate from resumable summary content', () {
      final stored = summaryPartialsWithLanguage(const [
        {'title': 'Part one', 'content': 'Notes'},
        {'title': 'Part two', 'content': 'More notes'},
      ], 'English');

      expect(summaryLanguageOverrideFromPartials(stored), 'English');
      expect(summaryContentPartials(stored), const [
        {'title': 'Part one', 'content': 'Notes'},
        {'title': 'Part two', 'content': 'More notes'},
      ]);
    });

    test('blank override restores the app default without losing content', () {
      final stored = summaryPartialsWithLanguage(const [
        {'title': 'Part one'},
      ], '   ');

      expect(summaryLanguageOverrideFromPartials(stored), isNull);
      expect(summaryContentPartials(stored), const [
        {'title': 'Part one'},
      ]);
    });

    test('SyncJob exposes a persisted transcript override', () {
      final stored = jsonEncode(
        summaryPartialsWithLanguage(const [], 'English'),
      );
      final now = DateTime.utc(2026, 9, 15);
      final job = SyncJob(
        id: 'job',
        firefliesId: 'transcript',
        title: 'Lecture',
        meetingDate: now,
        status: SyncJobStatus.queued,
        sourceType: 'fireflies:test',
        attemptCount: 0,
        discoveredAt: now,
        updatedAt: now,
        summaryPartialsJson: stored,
      );

      expect(job.summaryLanguageOverride, 'English');
    });
  });
}
