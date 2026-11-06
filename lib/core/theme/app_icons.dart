import 'package:flutter/material.dart';

class AppIcons {
  static const List<IconData> curatedIcons = [
    Icons.code,
    Icons.laptop_chromebook,
    Icons.terminal,
    Icons.menu_book,
    Icons.school,
    Icons.fitness_center,
    Icons.directions_run,
    Icons.directions_bike,
    Icons.cleaning_services,
    Icons.shopping_bag,
    Icons.home_repair_service,
    Icons.self_improvement,
    Icons.spa,
    Icons.nature_people,
    Icons.coffee,
    Icons.tv,
    Icons.movie,
    Icons.sports_esports,
    Icons.smartphone,
    Icons.bedtime,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.brush,
    Icons.music_note,
    Icons.headphones,
    Icons.work,
    Icons.edit_note,
    Icons.lightbulb,
    Icons.rocket_launch,
    Icons.psychology,
    Icons.star,
    Icons.favorite,
  ];

  static IconData getIconData(int codePoint) {
    for (final icon in curatedIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.star;
  }
}
