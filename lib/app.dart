import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'core/theme/eq_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/activities/presentation/activities_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/timer/presentation/timer_screen.dart';
import 'features/timer/providers/timer_provider.dart';

class EquinoxApp extends ConsumerWidget {
  const EquinoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentPreset;

    return MaterialApp(
      title: 'Equinox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(accentPreset: accent),
      darkTheme: AppTheme.buildDarkTheme(accentPreset: accent),
      themeMode: settings.themeMode,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  StreamSubscription<String>? _notifSub;

  final List<Widget> _screens = const [
    TimerScreen(),
    AnalyticsScreen(),
    ActivitiesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _notifSub = NotificationService.actionStream.stream.listen((actionId) {
      if (actionId == 'action_pause') {
        ref.read(timerControllerProvider).pause();
      } else if (actionId == 'action_resume') {
        ref.read(timerControllerProvider).resume();
      } else if (actionId == 'action_stop') {
        if (mounted) {
          setState(() => _currentIndex = 0);
          ref.read(stopAndLogRequestedProvider.notifier).trigger();
        }
      } else if (actionId == 'open_app') {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height && size.width >= 600;

    final bodyStack = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: isLandscape
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) =>
                        setState(() => _currentIndex = index),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.timer_outlined),
                        selectedIcon: Icon(Icons.timer),
                        label: Text('Today'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights),
                        label: Text('Insights'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.category_outlined),
                        selectedIcon: Icon(Icons.category),
                        label: Text('Activities'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  VerticalDivider(width: 1, color: eq.borderSubtle),
                  Expanded(child: bodyStack),
                ],
              )
            : bodyStack,
        bottomNavigationBar: isLandscape
            ? null
            : Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: eq.borderSubtle, width: 1),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _currentIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: 'Insights',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.category_outlined),
                      selectedIcon: Icon(Icons.category),
                      label: 'Activities',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
