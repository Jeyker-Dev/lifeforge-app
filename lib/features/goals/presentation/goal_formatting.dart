/// Formats a metric number, omitting `.0` for whole numbers (e.g. `3`, `2.5`).
String formatMetricNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Computes clamped progress ratio in `[0.0, 1.0]`, returning `0.0` when
/// [target] is `<= 0`.
double goalProgressRatio(double current, double target) {
  if (target <= 0 || current <= 0) return 0;
  return (current / target).clamp(0.0, 1.0);
}

/// Computes whole-number progress percentage in `[0, 100]`.
int goalProgressPercent(double current, double target) {
  return (goalProgressRatio(current, target) * 100).round().clamp(0, 100);
}

/// Formats weekly hours as `"6 h"`, `"4 h 30 min"`, or `"30 min"`.
String formatWeeklyHours(double hours) {
  if (hours.isNaN || hours.isInfinite || hours <= 0) return '0 h';
  final totalMinutes = (hours * 60).round();
  if (totalMinutes <= 0) return '0 h';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '$h h $m min';
  if (h > 0) return '$h h';
  return '$m min';
}

const _spanishMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formats a goal target date concisely in Spanish (e.g. `"1 mar 2027"`).
String formatGoalTargetDate(DateTime date) {
  final month = _spanishMonths[date.month - 1];
  return '${date.day} $month ${date.year}';
}
