import 'package:flutter/material.dart';

class AppIcons {
  static const List<IconData> curatedIcons = [
    // Tech, Coding & Logic
    Icons.code,
    Icons.terminal,
    Icons.laptop_chromebook,
    Icons.desktop_windows,
    Icons.developer_mode,
    Icons.memory,
    Icons.cloud,

    // Study, Education & Science
    Icons.menu_book,
    Icons.school,
    Icons.psychology,
    Icons.science,
    Icons.auto_stories,
    Icons.calculate,
    Icons.architecture,
    Icons.biotech,

    // Movement, Sports & Fitness
    Icons.fitness_center,
    Icons.directions_run,
    Icons.directions_bike,
    Icons.directions_walk,
    Icons.pool,
    Icons.sports_soccer,
    Icons.sports_basketball,
    Icons.sports_tennis,
    Icons.sports_mma,
    Icons.hiking,
    Icons.skateboarding,
    Icons.rowing,

    // Leisure, Gaming & Creative Arts
    Icons.tv,
    Icons.movie,
    Icons.sports_esports,
    Icons.gamepad,
    Icons.headphones,
    Icons.music_note,
    Icons.piano,
    Icons.brush,
    Icons.palette,
    Icons.camera_alt,
    Icons.weekend,
    Icons.casino,
    Icons.theater_comedy,

    // Health, Wellness & Rest
    Icons.self_improvement,
    Icons.spa,
    Icons.bedtime,
    Icons.nights_stay,
    Icons.water_drop,
    Icons.favorite,
    Icons.nature_people,
    Icons.park,

    // Productivity, Work & Business
    Icons.work,
    Icons.business_center,
    Icons.lightbulb,
    Icons.rocket_launch,
    Icons.edit_note,
    Icons.analytics,
    Icons.trending_up,
    Icons.attach_money,
    Icons.schedule,
    Icons.task_alt,
    Icons.checklist,

    // Daily Life, Home & Social
    Icons.coffee,
    Icons.local_cafe,
    Icons.restaurant,
    Icons.lunch_dining,
    Icons.bakery_dining,
    Icons.kitchen,
    Icons.cleaning_services,
    Icons.local_laundry_service,
    Icons.shopping_bag,
    Icons.shopping_cart,
    Icons.home,
    Icons.home_repair_service,
    Icons.pets,
    Icons.yard,
    Icons.commute,
    Icons.directions_car,
    Icons.flight,
    Icons.smartphone,
    Icons.star,
  ];

  static IconData getIconData(int codePoint) {
    for (final icon in curatedIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.star;
  }
}
