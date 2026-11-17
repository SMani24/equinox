import 'package:drift/native.dart';
import 'package:equinox/app.dart';
import 'package:equinox/core/providers/core_providers.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EquinoxApp renders navigation tabs and timer ring',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const EquinoxApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab labels exist in navigation bar
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Start Timer button exists on initial launch
    expect(find.text('Start Timer'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('Back button on secondary tabs navigates back to Today; on Today exits',
      (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const EquinoxApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial tab is Today
    expect(find.text('Start Timer'), findsOneWidget);

    // 2. Switch to Insights tab
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // 3. Press system back button
    final popHandled = await tester.binding.handlePopRoute();
    expect(popHandled, isTrue); // Intercepted by PopScope
    await tester.pumpAndSettle();

    // Should return to Today screen
    expect(find.text('Start Timer'), findsOneWidget);

    // 4. Switch to Activities tab
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();

    // Press back button again
    final popHandled2 = await tester.binding.handlePopRoute();
    expect(popHandled2, isTrue);
    await tester.pumpAndSettle();

    // Returns to Today screen
    expect(find.text('Start Timer'), findsOneWidget);

    // 5. When already on Today tab, back button allows pop to quit app
    final popHandledOnTimer = await tester.binding.handlePopRoute();
    expect(popHandledOnTimer, isFalse);

    await testDb.close();
  });
}
