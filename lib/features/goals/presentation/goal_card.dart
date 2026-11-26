import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../areas/domain/area.dart';
import '../domain/goal.dart';
import 'goal_formatting.dart';

/// Card displaying a single [Goal] with its area label, progress metric, and
/// weekly hours target.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.area,
    this.onTap,
  });

  final Goal goal;
  final Area area;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final areaColor = parseForgeHexColor(area.color);
    final isCompleted = goal.status == GoalStatus.completed;
    final ratio = goalProgressRatio(goal.metricCurrent, goal.metricTarget);
    final percent = goalProgressPercent(goal.metricCurrent, goal.metricTarget);
    final accentColor = isCompleted ? ForgeColors.positive : areaColor;
    final metricText =
        '${formatMetricNumber(goal.metricCurrent)} de '
        '${formatMetricNumber(goal.metricTarget)} ${goal.metricUnit}';
    final why = goal.why?.trim();

    return Material(
      color: ForgeColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 5, backgroundColor: areaColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      area.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ForgeColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  if (isCompleted) const _CompletedBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                goal.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ForgeColors.onSurface,
                ),
              ),
              if (why != null && why.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  why,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ForgeColors.onSurfaceMuted,
                  ),
                ),
              ],
              if (goal.targetDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: ForgeColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Objetivo: ${formatGoalTargetDate(goal.targetDate!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ForgeColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metricText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ForgeColors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: ForgeColors.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: ForgeColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${formatWeeklyHours(goal.weeklyHoursTarget)} por semana',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ForgeColors.onSurfaceMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ForgeColors.positive.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ForgeColors.positive.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: ForgeColors.positive,
          ),
          SizedBox(width: 4),
          Text(
            'Meta cumplida',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ForgeColors.positive,
            ),
          ),
        ],
      ),
    );
  }
}
