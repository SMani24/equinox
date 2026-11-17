import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../data/database/app_database.dart';

class AutofillSuggestion {
  final List<IconData> icons;
  final IconData primaryIcon;
  final String category;
  final double coefficient;
  final int suggestedColorHex;
  final Activity? duplicateMatch;
  final String matchedKeyword;

  const AutofillSuggestion({
    required this.icons,
    required this.primaryIcon,
    required this.category,
    required this.coefficient,
    required this.suggestedColorHex,
    this.duplicateMatch,
    required this.matchedKeyword,
  });
}

class _KeywordRule {
  final List<String> keywords;
  final List<IconData> icons;
  final String category;
  final double coefficient;

  const _KeywordRule({
    required this.keywords,
    required this.icons,
    required this.category,
    required this.coefficient,
  });
}

/// Offline keyword + distinct color autofill engine supporting English and Persian/Farsi.
class ActivityAutofill {
  static const List<_KeywordRule> _rules = [
    // Deep focus, coding, engineering
    _KeywordRule(
      keywords: [
        'code', 'coding', 'program', 'dev', 'software', 'flutter', 'debug',
        'terminal', 'git', 'app', 'algorithm', 'computer', 'laptop',
        'کد', 'برنامه', 'توسعه', 'دیباگ', 'کامپیوتر', 'لپتاپ', 'نرم افزار',
      ],
      icons: [Icons.code, Icons.terminal, Icons.developer_mode, Icons.laptop_chromebook, Icons.memory],
      category: 'productive',
      coefficient: 1.5,
    ),
    _KeywordRule(
      keywords: [
        'deep', 'focus', 'work', 'project', 'task', 'research', 'design',
        'write', 'writing', 'article', 'thesis', 'office', 'freelance',
        'عمیق', 'تمرکز', 'کار', 'پروژه', 'پژوهش', 'تحقیق', 'طراحی', 'نوشتن', 'مقاله', 'پایان نامه',
      ],
      icons: [Icons.psychology, Icons.work, Icons.rocket_launch, Icons.edit_note, Icons.lightbulb],
      category: 'productive',
      coefficient: 1.5,
    ),
    // Study, education, reading
    _KeywordRule(
      keywords: [
        'study', 'read', 'reading', 'book', 'lecture', 'class', 'course',
        'exam', 'math', 'science', 'homework', 'learn', 'language', 'school', 'uni',
        'درس', 'مطالعه', 'کتاب', 'خواندن', 'کلاس', 'دوره', 'امتحان', 'ریاضی', 'تکلیف', 'یادگیری', 'زبان', 'دانشگاه',
      ],
      icons: [Icons.menu_book, Icons.auto_stories, Icons.school, Icons.calculate, Icons.science],
      category: 'productive',
      coefficient: 1.0,
    ),
    // Spiritual / Mindfulness
    _KeywordRule(
      keywords: [
        'pray', 'prayer', 'quran', 'meditate', 'meditation', 'yoga', 'mindful',
        'breathe', 'journal', 'reflect', 'walk',
        'نماز', 'قرآن', 'دعا', 'عبادت', 'مدیتیشن', 'یوگا', 'پیاده', 'تامل',
      ],
      icons: [Icons.self_improvement, Icons.auto_stories, Icons.spa, Icons.directions_walk, Icons.park],
      category: 'productive',
      coefficient: 1.0,
    ),
    // Exercise / Fitness
    _KeywordRule(
      keywords: [
        'gym', 'workout', 'exercise', 'run', 'running', 'jog', 'bike',
        'cycling', 'swim', 'pool', 'soccer', 'football', 'basketball', 'tennis', 'hike', 'sport', 'fitness',
        'ورزش', 'باشگاه', 'تمرین', 'دویدن', 'دوچرخه', 'شنا', 'فوتبال', 'کوهنوردی', 'بدنسازی',
      ],
      icons: [Icons.fitness_center, Icons.directions_run, Icons.directions_bike, Icons.pool, Icons.hiking],
      category: 'productive',
      coefficient: 1.2,
    ),
    // Chores, cleaning, trash, errands
    _KeywordRule(
      keywords: [
        'clean', 'chore', 'trash', 'garbage', 'waste', 'rubbish', 'recycle',
        'dishes', 'laundry', 'wash', 'iron', 'tidy', 'errand', 'shop', 'grocery', 'fix', 'repair',
        'نظافت', 'تمیز', 'زباله', 'آشغال', 'ظرف', 'لباس', 'خرید', 'خانه', 'مرتب', 'تعمیر',
      ],
      icons: [Icons.cleaning_services, Icons.delete, Icons.delete_outline, Icons.recycling, Icons.shopping_cart],
      category: 'productive',
      coefficient: 0.5,
    ),
    // Sleep & Night
    _KeywordRule(
      keywords: [
        'sleep', 'nap', 'bed', 'bedtime', 'rest', 'siesta',
        'خواب', 'چرت', 'استراحت', 'تخت', 'شب',
      ],
      icons: [Icons.bedtime, Icons.nights_stay, Icons.weekend],
      category: 'neutral',
      coefficient: 0.0,
    ),
    // Meals, cooking, coffee
    _KeywordRule(
      keywords: [
        'meal', 'eat', 'food', 'lunch', 'dinner', 'breakfast', 'cook', 'cooking',
        'kitchen', 'coffee', 'tea', 'cafe', 'snack', 'drink',
        'غذا', 'ناهار', 'شام', 'صبحانه', 'آشپزی', 'خوردن', 'قهوه', 'چای', 'کافه',
      ],
      icons: [Icons.restaurant, Icons.lunch_dining, Icons.coffee, Icons.kitchen, Icons.local_cafe],
      category: 'neutral',
      coefficient: 0.0,
    ),
    // Hygiene & Health
    _KeywordRule(
      keywords: [
        'hygiene', 'shower', 'bath', 'brush', 'doctor', 'health', 'medicine', 'clinic',
        'حمام', 'دوش', 'بهداشت', 'مسواک', 'دکتر', 'پزشک', 'دارو', 'سلامت',
      ],
      icons: [Icons.bathtub, Icons.wash, Icons.sanitizer, Icons.local_hospital, Icons.monitor_heart],
      category: 'neutral',
      coefficient: 0.0,
    ),
    // Commute & Travel
    _KeywordRule(
      keywords: [
        'travel', 'commute', 'drive', 'car', 'bus', 'train', 'metro', 'flight', 'taxi', 'trip',
        'مسیر', 'سفر', 'رفت و آمد', 'رانندگی', 'ماشین', 'مترو', 'قطار', 'اتوبوس', 'پرواز', 'تاکسی',
      ],
      icons: [Icons.commute, Icons.directions_car, Icons.train, Icons.flight, Icons.luggage],
      category: 'productive',
      coefficient: 0.2,
    ),
    // Entertainment: Video, YouTube, TV
    _KeywordRule(
      keywords: [
        'youtube', 'tv', 'movie', 'series', 'film', 'netflix', 'video', 'watch', 'stream', 'twitch',
        'یوتیوب', 'تلویزیون', 'فیلم', 'سریال', 'ویدیو', 'تماشا',
      ],
      icons: [Icons.tv, Icons.movie, Icons.headphones, Icons.weekend],
      category: 'rest',
      coefficient: -2.0,
    ),
    // Gaming & Doomscrolling / Social
    _KeywordRule(
      keywords: [
        'game', 'gaming', 'esport', 'playstation', 'xbox', 'scroll', 'doom',
        'instagram', 'tiktok', 'twitter', 'social', 'reel', 'shorts', 'reddit', 'wasted', 'waste', 'procrastin',
        'بازی', 'گیم', 'اینستا', 'اینستاگرام', 'تیک تاک', 'تلفن', 'تلف کردن', 'اسکرول', 'موبایل',
      ],
      icons: [Icons.sports_esports, Icons.gamepad, Icons.smartphone, Icons.delete_sweep, Icons.music_note],
      category: 'rest',
      coefficient: -3.0,
    ),
    // Audio, Music, Podcast, Creative hobbies
    _KeywordRule(
      keywords: [
        'music', 'podcast', 'listen', 'audio', 'piano', 'guitar', 'art', 'paint', 'photo', 'camera', 'hangout', 'friend', 'family', 'chat',
        'موزیک', 'موسیقی', 'پادکست', 'پیانو', 'نقاشی', 'عکاسی', 'دوستان', 'خانواده', 'گپ',
      ],
      icons: [Icons.headphones, Icons.music_note, Icons.podcasts, Icons.palette, Icons.group],
      category: 'rest',
      coefficient: -1.0,
    ),
  ];

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // Strip Arabic/Persian diacritics
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .trim();
  }

  /// Finds matching icons, category, multiplier, distinct color, and duplicate warning
  /// for an activity [name].
  static AutofillSuggestion? suggestForName(
    String name, {
    List<Activity> existingActivities = const [],
    String? editingActivityId,
  }) {
    final norm = _normalize(name);
    if (norm.length < 2) return null;

    final tokens = norm.split(RegExp(r'[\s/\-_.,]+')).where((t) => t.isNotEmpty).toList();

    _KeywordRule? bestRule;
    String matchedKeyword = '';
    int bestScore = 0;

    for (final rule in _rules) {
      int score = 0;
      String topKw = '';
      for (final kw in rule.keywords) {
        final nkw = _normalize(kw);
        for (final token in tokens) {
          if (token == nkw) {
            score += 10;
            topKw = kw;
          } else if (token.startsWith(nkw) || nkw.startsWith(token) && token.length >= 3) {
            score += 6;
            topKw = topKw.isEmpty ? kw : topKw;
          }
        }
        if (norm.contains(nkw)) {
          score += 4;
          topKw = topKw.isEmpty ? kw : topKw;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
        matchedKeyword = topKw;
      }
    }

    final duplicate = findDuplicateActivity(
      name,
      existingActivities: existingActivities,
      excludeId: editingActivityId,
    );

    if (bestRule == null || bestScore == 0) {
      if (duplicate == null) return null;
      return AutofillSuggestion(
        icons: AppIcons.curatedIcons.take(8).toList(),
        primaryIcon: AppIcons.getIconData(duplicate.iconCode),
        category: duplicate.category,
        coefficient: duplicate.coefficient.abs(),
        suggestedColorHex: duplicate.colorHex,
        duplicateMatch: duplicate,
        matchedKeyword: duplicate.name,
      );
    }

    final extraIcons = <IconData>[...bestRule.icons];
    for (final icon in AppIcons.curatedIcons) {
      if (extraIcons.length >= 8) break;
      if (!extraIcons.contains(icon)) {
        extraIcons.add(icon);
      }
    }

    final colorHex = pickDistinctColor(
      category: bestRule.category,
      existingActivities: existingActivities,
      excludeId: editingActivityId,
    );

    return AutofillSuggestion(
      icons: extraIcons,
      primaryIcon: bestRule.icons.first,
      category: bestRule.category,
      coefficient: bestRule.coefficient.abs(),
      suggestedColorHex: colorHex,
      duplicateMatch: duplicate,
      matchedKeyword: matchedKeyword,
    );
  }

  /// Picks a color from [AppColors.activityPalette] that maximizes the minimum
  /// hue distance from active activities' colors while biasing toward category hue zones.
  static int pickDistinctColor({
    required String category,
    required List<Activity> existingActivities,
    String? excludeId,
  }) {
    final usedHsl = existingActivities
        .where((a) => !a.isArchived && a.id != excludeId)
        .map((a) => HSLColor.fromColor(Color(a.colorHex)))
        .toList();

    Color bestColor = AppColors.activityPalette.first;
    double bestScore = -1.0;

    for (final candidate in AppColors.activityPalette) {
      final hsl = HSLColor.fromColor(candidate);

      double minHueDist = 180.0;
      double exactMatchPenalty = 0.0;
      for (final u in usedHsl) {
        if ((u.toColor().toARGB32() == candidate.toARGB32())) {
          exactMatchPenalty += 120.0;
        }
        double diff = (hsl.hue - u.hue).abs();
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff < minHueDist) minHueDist = diff;
      }

      // Soft category bias
      double categoryBonus = 0.0;
      if (category == 'productive' && hsl.hue >= 130 && hsl.hue <= 255) {
        categoryBonus = 18.0;
      } else if (category == 'rest' &&
          (hsl.hue <= 55 || hsl.hue >= 315)) {
        categoryBonus = 18.0;
      } else if (category == 'neutral' && (hsl.saturation < 0.45 || (hsl.hue >= 210 && hsl.hue <= 285))) {
        categoryBonus = 16.0;
      }

      final score = (usedHsl.isEmpty ? 90.0 : minHueDist) + categoryBonus - exactMatchPenalty;
      if (score > bestScore) {
        bestScore = score;
        bestColor = candidate;
      }
    }

    return bestColor.toARGB32();
  }

  /// Returns palette colors ordered by maximum distinctness from existing activities.
  static List<Color> orderedDistinctPalette({
    required String category,
    required List<Activity> existingActivities,
    String? excludeId,
  }) {
    final used = existingActivities
        .where((a) => !a.isArchived && a.id != excludeId)
        .map((a) => Color(a.colorHex))
        .toList();

    final list = List<Color>.from(AppColors.activityPalette);
    list.sort((a, b) {
      final scoreA = _colorScore(a, category, used);
      final scoreB = _colorScore(b, category, used);
      return scoreB.compareTo(scoreA);
    });
    return list;
  }

  static double _colorScore(Color candidate, String category, List<Color> used) {
    final hsl = HSLColor.fromColor(candidate);
    double minDist = 180.0;
    double penalty = 0.0;
    for (final u in used) {
      if (u.toARGB32() == candidate.toARGB32()) penalty += 120.0;
      final uh = HSLColor.fromColor(u).hue;
      double d = (hsl.hue - uh).abs();
      if (d > 180.0) d = 360.0 - d;
      if (d < minDist) minDist = d;
    }
    double bonus = 0.0;
    if (category == 'productive' && hsl.hue >= 130 && hsl.hue <= 255) bonus = 18.0;
    if (category == 'rest' && (hsl.hue <= 55 || hsl.hue >= 315)) bonus = 18.0;
    if (category == 'neutral' && hsl.saturation < 0.45) bonus = 16.0;
    return (used.isEmpty ? 90.0 : minDist) + bonus - penalty;
  }

  /// Checks whether [name] is likely a duplicate of an existing activity (Levenshtein <= 2).
  static Activity? findDuplicateActivity(
    String name, {
    required List<Activity> existingActivities,
    String? excludeId,
  }) {
    final norm = _normalize(name);
    if (norm.length < 3) return null;

    for (final act in existingActivities) {
      if (act.id == excludeId) continue;
      final actNorm = _normalize(act.name);
      if (actNorm == norm) return act;
      if (_levenshtein(norm, actNorm) <= 2) return act;
    }
    return null;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = math.min(
          math.min(curr[j] + 1, prev[j + 1] + 1),
          prev[j] + cost,
        );
      }
      for (int j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  /// Searches curated icons using both English and Persian keyword rules + basic names.
  static List<IconData> searchIcons(String query) {
    final norm = _normalize(query);
    if (norm.isEmpty) return AppIcons.curatedIcons;

    final matched = <IconData>[];
    for (final rule in _rules) {
      final hit = rule.keywords.any((k) => _normalize(k).contains(norm) || norm.contains(_normalize(k)));
      if (hit) {
        for (final icon in rule.icons) {
          if (!matched.contains(icon)) matched.add(icon);
        }
      }
    }

    // Also match general English categories for remaining curated icons
    final extraKeywords = <IconData, String>{
      Icons.delete: 'delete trash bin garbage clean remove زباله',
      Icons.delete_outline: 'delete trash bin garbage clean زباله',
      Icons.delete_sweep: 'delete sweep clean trash زباله',
      Icons.recycling: 'recycle trash waste clean بازیافت زباله',
      Icons.star: 'star favorite important ستاره',
      Icons.bolt: 'energy fast bolt focus quick برق انرژی',
      Icons.timer: 'timer clock stopwatch زمان تایمر',
      Icons.alarm: 'alarm clock wake هشدار زنگ',
      Icons.schedule: 'schedule clock time ساعت زمان',
      Icons.chat: 'chat message talk پیام گپ',
      Icons.phone_in_talk: 'call phone talk زنگ تماس',
      Icons.video_call: 'meeting video zoom تماس ویدیو',
      Icons.camera_alt: 'camera photo عکس دوربین',
      Icons.bakery_dining: 'food bakery bread نان غذا',
      Icons.fastfood: 'fast food burger فست فود غذا',
      Icons.local_pizza: 'pizza food پیتزا غذا',
      Icons.home: 'home house خانه',
      Icons.yard: 'garden plant yard حیاط باغ',
      Icons.pets: 'pet dog cat حیوان',
      Icons.translate: 'translate language ترجمه زبان',
      Icons.mic: 'mic voice record میکروفون صدا',
      Icons.build: 'build tool fix تعمیر ابزار',
      Icons.handyman: 'repair diy fix تعمیر',
      Icons.attach_money: 'money finance budget پول مالی',
      Icons.analytics: 'analytics chart graph آمار نمودار',
    };

    extraKeywords.forEach((icon, tags) {
      if (_normalize(tags).contains(norm) && !matched.contains(icon)) {
        matched.add(icon);
      }
    });

    return matched;
  }
}
