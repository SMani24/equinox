import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/activities/presentation/activities_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/timer/presentation/timer_screen.dart';
import 'features/timer/providers/timer_provider.dart';

class EquinoxApp extends StatelessWidget {
  const EquinoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Equinox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
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
          setState(() {
            _currentIndex = 0;
          });
          ref.read(stopAndLogRequestedProvider.notifier).trigger();
        }
      } else if (actionId == 'open_app') {
        if (mounted) {
          setState(() {
            _currentIndex = 0;
          });
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
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: NavigationBar(
            height: isLandscape ? 56 : null,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: 'Timer',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Analytics',
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
