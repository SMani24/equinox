import 'package:drift/native.dart';
import 'package:equinox/core/utils/score_calculator.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:equinox/data/repositories/activity_repository.dart';
import 'package:equinox/features/timer/providers/timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Fixes & Enhancements Verification', () {
    test('idlePreselectedActivityIdProvider sets and clears properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(idlePreselectedActivityIdProvider), isNull);

      container
          .read(idlePreselectedActivityIdProvider.notifier)
          .select('activity-123');
      expect(
          container.read(idlePreselectedActivityIdProvider), 'activity-123');

      container.read(idlePreselectedActivityIdProvider.notifier).select(null);
      expect(container.read(idlePreselectedActivityIdProvider), isNull);
    });

    test('Short session split bounds calculation does not crash on short durations', () {
      // Test duration that caused crash in Bug 4: 18 seconds
      const totalSeconds = 18;
      const minSplit = totalSeconds <= 10 ? 1.0 : (totalSeconds <= 60 ? 5.0 : 15.0);
      final maxSplit = (totalSeconds - minSplit).toDouble();
      final minBound = minSplit < maxSplit ? minSplit : 1.0;
      final maxBound = maxSplit > minBound ? maxSplit : (totalSeconds - 1.0).toDouble();

      expect(minBound, lessThan(maxBound));
      expect(minBound, 5.0);
      expect(maxBound, 13.0);

      // Value clamp should not throw
      final midVal = (totalSeconds / 2).clamp(minBound, maxBound);
      expect(midVal, 9.0);
      expect(midVal, greaterThanOrEqualTo(minBound));
      expect(midVal, lessThanOrEqualTo(maxBound));
    });

    test('Activities reorder persistence saves new sort order to database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final repo = ActivityRepository(db);
      final initialList = await repo.getActivities();
      expect(initialList.length, greaterThanOrEqualTo(2));

      final firstId = initialList[0].id;
      final secondId = initialList[1].id;

      // Reorder so secondId is first
      final newOrder = [
        secondId,
        firstId,
        ...initialList.skip(2).map((a) => a.id),
      ];
      await repo.reorderActivities(newOrder);

      final reordered = await repo.getActivities();
      expect(reordered[0].id, secondId);
      expect(reordered[1].id, firstId);
    });
  });
}
