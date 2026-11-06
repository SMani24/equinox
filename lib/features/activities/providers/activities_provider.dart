import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/database/app_database.dart';

final activitiesStreamProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchActivities(includeArchived: false);
});

final allActivitiesStreamProvider = StreamProvider<List<Activity>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchActivities(includeArchived: true);
});

class ActivityGroups {
  final List<Activity> productive;
  final List<Activity> rest;
  final List<Activity> neutral;

  const ActivityGroups({
    required this.productive,
    required this.rest,
    required this.neutral,
  });
}

final activityGroupsProvider = Provider<ActivityGroups>((ref) {
  final activitiesAsync = ref.watch(activitiesStreamProvider);
  final activities = activitiesAsync.value ?? [];

  return ActivityGroups(
    productive: activities.where((a) => a.category == 'productive').toList(),
    rest: activities.where((a) => a.category == 'rest').toList(),
    neutral: activities.where((a) => a.category == 'neutral').toList(),
  );
});
