class ScoreCalculator {
  /// Calculate the score for a single time entry given duration in seconds and coefficient.
  /// Entry Score = (duration_seconds / 3600.0) * coefficient
  static double calculateScore(int durationSeconds, double coefficient) {
    if (durationSeconds <= 0) return 0.0;
    final durationHours = durationSeconds / 3600.0;
    return durationHours * coefficient;
  }

  /// Calculates gross productive score (sum of all entries where score > 0)
  static double calculateGrossProductive(Iterable<double> scores) {
    return scores.where((s) => s > 0).fold(0.0, (acc, s) => acc + s);
  }

  /// Calculates gross rest cost (sum of absolute value of all entries where score < 0)
  static double calculateGrossRestCost(Iterable<double> scores) {
    return scores.where((s) => s < 0).fold(0.0, (acc, s) => acc + s.abs());
  }

  /// Calculates net daily balance (productive score minus rest cost)
  static double calculateNetBalance(Iterable<double> scores) {
    return scores.fold(0.0, (acc, s) => acc + s);
  }

  /// Formats score as string with sign and 2 decimals (e.g., "+1.86 pts", "-3.72 pts", "0.00 pts")
  static String formatScore(double score, {bool showUnit = true}) {
    final prefix = score > 0 ? '+' : (score < 0 ? '-' : '');
    final absScore = score.abs().toStringAsFixed(2);
    final unit = showUnit ? ' pts' : '';
    return '$prefix$absScore$unit';
  }

  /// Formats coefficient as string (e.g., "+1.5x", "-2.0x", "0.0x")
  static String formatCoefficient(double coeff) {
    final prefix = coeff > 0 ? '+' : (coeff < 0 ? '-' : '');
    final abs = coeff.abs().toStringAsFixed(1);
    return '$prefix${abs}x';
  }
}
