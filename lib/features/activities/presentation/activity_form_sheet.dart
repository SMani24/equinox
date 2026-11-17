import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/activity_avatar.dart';
import '../../../core/ui/score_pill.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../smart/activity_autofill.dart';

class ActivityFormSheet extends StatefulWidget {
  final Activity? activityToEdit;
  final List<Activity> existingActivities;
  final void Function({
    required String name,
    required String category,
    required double coefficient,
    required int colorHex,
    required int iconCode,
    bool recalculatePast,
  }) onSave;
  final VoidCallback? onDelete;
  final void Function(bool isArchived)? onToggleArchive;

  const ActivityFormSheet({
    super.key,
    this.activityToEdit,
    this.existingActivities = const [],
    required this.onSave,
    this.onDelete,
    this.onToggleArchive,
  });

  @override
  State<ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<ActivityFormSheet> {
  late TextEditingController _nameController;
  late TextEditingController _coefficientController;
  late String _category;
  late double _coefficient;
  late int _selectedColorHex;
  late int _selectedIconCode;
  bool _recalculatePast = false;
  bool _showAllColors = false;
  bool _userPickedColor = false;
  bool _userPickedIcon = false;
  AutofillSuggestion? _autofill;

  bool _isSaving = false;
  Timer? _debounceTimer;
  Timer? _savingResetTimer;

  final List<double> _presets = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0];

  @override
  void initState() {
    super.initState();
    final a = widget.activityToEdit;
    _nameController = TextEditingController(text: a?.name ?? '');
    _category = a?.category ?? 'productive';

    final rawCoeff = a?.coefficient ?? 1.0;
    _coefficient = rawCoeff.abs() == 0 ? 0.0 : rawCoeff.abs();
    _coefficientController =
        TextEditingController(text: _coefficient.toStringAsFixed(1));

    _selectedColorHex = a?.colorHex ??
        ActivityAutofill.pickDistinctColor(
          category: _category,
          existingActivities: widget.existingActivities,
        );
    _selectedIconCode = a?.iconCode ?? AppIcons.curatedIcons.first.codePoint;

    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final name = _nameController.text;
    final suggestion = ActivityAutofill.suggestForName(
      name,
      existingActivities: widget.existingActivities,
      editingActivityId: widget.activityToEdit?.id,
    );
    if (mounted) {
      setState(() {
        _autofill = suggestion;
      });
    }
    if (widget.activityToEdit != null) {
      _triggerAutoSave();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _savingResetTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _coefficientController.dispose();
    super.dispose();
  }

  void _applyAutofillSuggestion(AutofillSuggestion sug) {
    setState(() {
      _category = sug.category;
      _coefficient = sug.coefficient;
      _coefficientController.text = _coefficient.toStringAsFixed(1);
      if (!_userPickedIcon) {
        _selectedIconCode = sug.primaryIcon.codePoint;
      }
      if (!_userPickedColor) {
        _selectedColorHex = sug.suggestedColorHex;
      }
    });
    _triggerAutoSave(immediate: true);
  }

  void _triggerAutoSave({bool immediate = false}) {
    if (widget.activityToEdit == null) return;
    _debounceTimer?.cancel();
    if (immediate) {
      _performAutoSave();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performAutoSave();
      });
    }
  }

  void _performAutoSave() {
    if (widget.activityToEdit == null || !mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    widget.onSave(
      name: name,
      category: _category,
      coefficient: _signedCoefficient,
      colorHex: _selectedColorHex,
      iconCode: _selectedIconCode,
      recalculatePast: _recalculatePast,
    );

    if (mounted) {
      _savingResetTimer?.cancel();
      _savingResetTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      });
    }
  }

  double get _signedCoefficient {
    if (_category == 'productive') return _coefficient.abs();
    if (_category == 'rest') return -_coefficient.abs();
    return 0.0;
  }

  String _getPlainEnglishExplanation() {
    final signed = _signedCoefficient;
    final coeffStr = _coefficient.toStringAsFixed(1);
    if (_category == 'productive') {
      final pts = ScoreCalculator.formatScore(signed * 1.0);
      return '1 hour earns $pts (equals ${coeffStr}h of 1.0x work).';
    } else if (_category == 'rest') {
      final pts = ScoreCalculator.formatScore(signed * 1.0);
      return '1 hour costs $pts (balances ${coeffStr}h of 1.0x work).';
    } else {
      return '0.0 pts — tracked in timelines & heatmaps without shifting balance.';
    }
  }

  void _onCategoryChanged(String newCat) {
    setState(() {
      _category = newCat;
      if (newCat == 'neutral') {
        _coefficient = 0.0;
        _coefficientController.text = '0.0';
      } else if (_coefficient == 0.0) {
        _coefficient = 1.0;
        _coefficientController.text = '1.0';
      }
      if (widget.activityToEdit == null && !_userPickedColor) {
        _selectedColorHex = ActivityAutofill.pickDistinctColor(
          category: newCat,
          existingActivities: widget.existingActivities,
        );
      }
    });
    _triggerAutoSave(immediate: true);
  }

  void _openBrowseIconsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final eq = ctx.eq;
            final icons = q.trim().isEmpty
                ? AppIcons.curatedIcons
                : ActivityAutofill.searchIcons(q);

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.72,
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Browse icons',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (v) => setSheetState(() => q = v),
                    decoration: const InputDecoration(
                      hintText: 'Search (English or Persian, e.g. sleep, خواب, trash)…',
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Expanded(
                    child: icons.isEmpty
                        ? Center(
                            child: Text(
                              'No matching icons',
                              style: TextStyle(color: eq.textMuted),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: icons.length,
                            itemBuilder: (_, idx) {
                              final icon = icons[idx];
                              final selected = _selectedIconCode == icon.codePoint;
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _userPickedIcon = true;
                                    _selectedIconCode = icon.codePoint;
                                  });
                                  _triggerAutoSave(immediate: true);
                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Color(_selectedColorHex)
                                            .withValues(alpha: 0.2)
                                        : eq.surface2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: selected
                                        ? Border.all(
                                            color: Color(_selectedColorHex),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: selected
                                        ? Color(_selectedColorHex)
                                        : eq.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final isEditing = widget.activityToEdit != null;
    final signedCoeff = _signedCoefficient;
    final explanation = _getPlainEnglishExplanation();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;

    final distinctPalette = ActivityAutofill.orderedDistinctPalette(
      category: _category,
      existingActivities: widget.existingActivities,
      excludeId: widget.activityToEdit?.id,
    );
    final List<Color> visibleColors;
    if (_showAllColors) {
      visibleColors = distinctPalette;
    } else {
      final top8 = distinctPalette.take(8).toList();
      final selectedColor = Color(_selectedColorHex);
      if (!top8.any((c) => c.toARGB32() == _selectedColorHex)) {
        top8[top8.length - 1] = selectedColor;
      }
      visibleColors = top8;
    }

    // Build displayed 8-icon quick grid (suggested first, always keeping selected icon visible)
    final baseIcons = _autofill?.icons ?? AppIcons.curatedIcons.take(8).toList();
    final visibleIcons = <IconData>[...baseIcons.take(8)];
    final currentIcon = AppIcons.getIconData(_selectedIconCode);
    if (!visibleIcons.any((i) => i.codePoint == currentIcon.codePoint)) {
      visibleIcons[visibleIcons.length - 1] = currentIcon;
    }

    final liveName = _nameController.text.trim().isEmpty
        ? 'Activity preview'
        : _nameController.text.trim();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && isEditing) {
          _performAutoSave();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: isLandscape ? size.height * 0.96 : size.height * 0.92,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: eq.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Text(
                    isEditing ? 'Edit Activity' : 'New Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (isEditing) ...[
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: Motion.fast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _isSaving ? eq.accentSoft : eq.gainSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSaving
                                ? Icons.sync_rounded
                                : Icons.check_circle_rounded,
                            size: 13,
                            color: _isSaving ? eq.accent : eq.gain,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSaving ? 'Saving...' : 'Auto-saved',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isSaving ? eq.accent : eq.gain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (isEditing) _performAutoSave();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: Space.md),

              // Live Activity Preview
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: eq.surface2,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  children: [
                    ActivityAvatar(
                      iconCode: _selectedIconCode,
                      colorHex: _selectedColorHex,
                      size: 42,
                      iconSize: 20,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _nameController.text.trim().isEmpty
                                  ? eq.textMuted
                                  : eq.textPrimary,
                            ),
                          ),
                          Text(
                            explanation,
                            style: TextStyle(fontSize: 11.5, color: eq.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    ScorePill(score: signedCoeff, compact: true),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),

              // Name Input
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Activity Name',
                  hintText: 'e.g. Deep Coding, Reading, خواب, YouTube',
                ),
              ),

              // Smart Autofill Suggestion Banner & Duplicate Guard
              if (_autofill != null) ...[
                const SizedBox(height: Space.sm),
                if (_autofill!.duplicateMatch != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: eq.spendSoft,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: eq.spend),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Similar activity exists: "${_autofill!.duplicateMatch!.name}"',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: eq.spend,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: eq.accentSoft,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _autofill!.primaryIcon,
                        size: 18,
                        color: Color(_autofill!.suggestedColorHex),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          'Suggested: ${_autofill!.category} (${ScoreCalculator.formatCoefficient(_autofill!.category == 'rest' ? -_autofill!.coefficient : _autofill!.coefficient)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: eq.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _applyAutofillSuggestion(_autofill!),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),

              // Category Control
              Text(
                'Category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryButton(
                      'productive',
                      'Productive (+)',
                      eq.gain,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _buildCategoryButton(
                      'rest',
                      'Rest (-)',
                      eq.spend,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _buildCategoryButton(
                      'neutral',
                      'Neutral (0.0)',
                      eq.neutral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),

              // Weight multiplier presets + slider
              if (_category != 'neutral') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weight multiplier',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      ScoreCalculator.formatCoefficient(signedCoeff),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: eq.forCoefficient(signedCoeff),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  children: _presets.map((preset) {
                    final isSelected = (_coefficient - preset).abs() < 0.05;
                    return ChoiceChip(
                      label: Text('${preset}x'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _coefficient = preset;
                          _coefficientController.text = preset.toStringAsFixed(1);
                        });
                        _triggerAutoSave(immediate: true);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: Space.xs),
                Slider(
                  value: _coefficient.clamp(0.1, 5.0),
                  min: 0.1,
                  max: 5.0,
                  divisions: 49,
                  label: '${_coefficient.toStringAsFixed(1)}x',
                  onChanged: (val) {
                    setState(() {
                      _coefficient = double.parse(val.toStringAsFixed(1));
                      _coefficientController.text = _coefficient.toStringAsFixed(1);
                    });
                    _triggerAutoSave();
                  },
                  onChangeEnd: (_) => _triggerAutoSave(immediate: true),
                ),
              ],
              const SizedBox(height: Space.md),

              // Distinct Color Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        setState(() => _showAllColors = !_showAllColors),
                    child: Text(_showAllColors ? 'Show fewer' : 'More colors'),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: visibleColors.map((color) {
                  final isSelected = _selectedColorHex == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _userPickedColor = true;
                        _selectedColorHex = color.toARGB32();
                      });
                      _triggerAutoSave(immediate: true);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? eq.textPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Space.lg),

              // Suggested Icons + Browse All button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Icon',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _openBrowseIconsDialog,
                    icon: const Icon(Icons.apps_rounded, size: 16),
                    label: const Text('Browse all'),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: visibleIcons.length,
                itemBuilder: (context, index) {
                  final icon = visibleIcons[index];
                  final isSelected = _selectedIconCode == icon.codePoint;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _userPickedIcon = true;
                        _selectedIconCode = icon.codePoint;
                      });
                      _triggerAutoSave(immediate: true);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorHex).withValues(alpha: 0.2)
                            : eq.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: Color(_selectedColorHex),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? Color(_selectedColorHex)
                            : eq.textSecondary,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: Space.md),

              if (isEditing) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Recalculate past entries?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Update historical sessions logged with this activity to use the new coefficient',
                    style: TextStyle(fontSize: 11.5, color: eq.textMuted),
                  ),
                  value: _recalculatePast,
                  onChanged: (val) {
                    setState(() => _recalculatePast = val);
                    _triggerAutoSave(immediate: true);
                  },
                ),
                const SizedBox(height: Space.sm),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isEditing
                      ? () {
                          _performAutoSave();
                          Navigator.of(context).pop();
                        }
                      : _nameController.text.trim().isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onSave(
                                name: _nameController.text.trim(),
                                category: _category,
                                coefficient: signedCoeff,
                                colorHex: _selectedColorHex,
                                iconCode: _selectedIconCode,
                                recalculatePast: _recalculatePast,
                              );
                            },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isEditing) ...[
                        const Icon(Icons.check_rounded, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        isEditing ? 'Done' : 'Create Activity',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'All adjustments are saved automatically',
                    style: TextStyle(
                      fontSize: 11,
                      color: eq.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category, String label, Color color) {
    final eq = context.eq;
    final isSelected = _category == category;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () => _onCategoryChanged(category),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : eq.surface2,
          borderRadius: BorderRadius.circular(Radii.md),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : eq.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
