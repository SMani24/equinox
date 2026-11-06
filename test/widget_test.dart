import 'package:drift/native.dart';
import 'package:equinox/app.dart';
import 'package:equinox/core/providers/core_providers.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EquinoxApp renders navigation tabs and timer dial',
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
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Start Timer button exists on initial launch
    expect(find.text('START TIMER'), findsOneWidget);
    expect(find.text("TODAY'S EQUILIBRIUM"), findsOneWidget);

    await testDb.close();
  });
}
