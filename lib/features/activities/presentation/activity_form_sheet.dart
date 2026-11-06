import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';

class ActivityFormSheet extends StatefulWidget {
  final Activity? activityToEdit;
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

  final List<double> _presets = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0];

  @override
  void initState() {
    super.initState();
    final a = widget.activityToEdit;
    _nameController = TextEditingController(text: a?.name ?? '');
    _category = a?.category ?? 'productive';

    // Positive coefficient magnitude
    final rawCoeff = a?.coefficient ?? 1.0;
    _coefficient = rawCoeff.abs() == 0 ? 0.0 : rawCoeff.abs();
    _coefficientController =
        TextEditingController(text: _coefficient.toStringAsFixed(1));

    _selectedColorHex = a?.colorHex ?? AppColors.activityPalette.first.toARGB32();
    _selectedIconCode = a?.iconCode ?? AppIcons.curatedIcons.first.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coefficientController.dispose();
    super.dispose();
  }

  double get _signedCoefficient {
    if (_category == 'productive') {
      return _coefficient.abs();
    } else if (_category == 'rest') {
      return -_coefficient.abs();
    } else {
      return 0.0;
    }
  }

  String _getPlainEnglishExplanation() {
    final signed = _signedCoefficient;
    final coeffStr = _coefficient.toStringAsFixed(1);
    if (_category == 'productive') {
      final pts = ScoreCalculator.formatScore(signed * 1.0);
      return '1 hour of this activity earns $pts balance points (equals $coeffStr hours of 1.0x work).';
    } else if (_category == 'rest') {
      final pts = ScoreCalculator.formatScore(signed * 1.0);
      return '1 hour of this activity costs $pts balance points (cancels 1 hour of +${coeffStr}x work, or $coeffStr hours of 1.0x work).';
    } else {
      return '0.0 balance points. Recorded for life heatmaps without shifting your work/rest equilibrium.';
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.activityToEdit != null;
    final signedCoeff = _signedCoefficient;
    final signedFormatted = ScoreCalculator.formatCoefficient(signedCoeff);
    final explanation = _getPlainEnglishExplanation();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Activity' : 'New Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Activity Name',
                hintText: 'e.g. Deep Coding, Reading, Gaming',
              ),
            ),
            const SizedBox(height: 16),

            // Category Segmented Control
            Text(
              'CATEGORY',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryButton(
                    'productive',
                    'Productive (+)',
                    AppColors.productive,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCategoryButton(
                    'rest',
                    'Rest (-)',
                    AppColors.rest,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCategoryButton(
                    'neutral',
                    'Neutral (0.0)',
                    AppColors.neutral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Coefficient Slider & Numeric Input (if not neutral)
            if (_category != 'neutral') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WEIGHT MULTIPLIER',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.forCoefficient(signedCoeff).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      signedFormatted,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.forCoefficient(signedCoeff),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick presets
              Wrap(
                spacing: 8,
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
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
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
                },
              ),
            ],

            // Plain-English explanation banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.forCoefficient(signedCoeff),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Color Palette Picker
            Text(
              'COLOR PALETTE',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: AppColors.activityPalette.map((color) {
                final isSelected = _selectedColorHex == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorHex = color.toARGB32();
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Icon Picker
            Text(
              'ICON',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: AppIcons.curatedIcons.length,
                itemBuilder: (context, index) {
                  final icon = AppIcons.curatedIcons[index];
                  final isSelected = _selectedIconCode == icon.codePoint;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _selectedIconCode = icon.codePoint;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorHex).withValues(alpha: 0.2)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Color(_selectedColorHex)
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? Color(_selectedColorHex)
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Recalculate past entries toggle (only if editing)
            if (isEditing) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Recalculate past entries?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Update historical sessions logged with this activity to use the new coefficient',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                value: _recalculatePast,
                onChanged: (val) {
                  setState(() {
                    _recalculatePast = val;
                  });
                },
              ),
              const SizedBox(height: 8),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _nameController.text.trim().isEmpty
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
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Activity',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category, String label, Color color) {
    final isSelected = _category == category;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onCategoryChanged(category),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
