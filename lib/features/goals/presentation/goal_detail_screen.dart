import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/sync/providers.dart';
import '../../areas/domain/area.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';
import 'goal_formatting.dart';
import 'new_goal_screen.dart';

enum _GoalMenuAction { toggleStatus, delete }

/// Detail view for a single [Goal], including metric updates and its action plan.
class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final Set<String> _dismissedActionIds = {};

  Future<void> _openEditGoal(BuildContext context, Goal goal) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => NewGoalScreen(goal: goal),
      ),
    );
  }

  Future<void> _toggleStatus(Goal goal) async {
    final nextStatus = goal.status == GoalStatus.active
        ? GoalStatus.completed
        : GoalStatus.active;
    await ref
        .read(goalRepositoryProvider)
        .upsert(
          id: goal.id,
          areaId: goal.areaId,
          title: goal.title,
          why: goal.why,
          targetDate: goal.targetDate,
          metricCurrent: goal.metricCurrent,
          metricTarget: goal.metricTarget,
          metricUnit: goal.metricUnit,
          weeklyHoursTarget: goal.weeklyHoursTarget,
          status: nextStatus,
        );
  }

  Future<void> _confirmAndDeleteGoal(BuildContext context, Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(
        title: 'Eliminar meta',
        message:
            '¿Quieres eliminar "${goal.title}"? También se eliminará su plan de acción.',
      ),
    );
    if (confirmed != true) return;
    await ref.read(goalRepositoryProvider).delete(goal.id);
    if (!context.mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/goals');
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showUpdateMetricDialog(BuildContext context, Goal goal) async {
    final nextValue = await showDialog<double>(
      context: context,
      builder: (context) => _UpdateMetricDialog(goal: goal),
    );
    if (nextValue == null) return;
    await ref
        .read(goalRepositoryProvider)
        .upsert(
          id: goal.id,
          areaId: goal.areaId,
          title: goal.title,
          why: goal.why,
          targetDate: goal.targetDate,
          metricCurrent: nextValue,
          metricTarget: goal.metricTarget,
          metricUnit: goal.metricUnit,
          weeklyHoursTarget: goal.weeklyHoursTarget,
          status: goal.status,
        );
  }

  Future<void> _showAddActionDialog(BuildContext context, String goalId) async {
    final result = await showDialog<({String title, GoalActionKind kind})>(
      context: context,
      builder: (context) => const _AddActionDialog(),
    );
    if (result == null) return;
    await ref
        .read(goalActionRepositoryProvider)
        .upsert(goalId: goalId, title: result.title, kind: result.kind);
  }

  Future<void> _toggleActionDone(GoalAction action) async {
    await ref
        .read(goalActionRepositoryProvider)
        .upsert(
          id: action.id,
          goalId: action.goalId,
          title: action.title,
          kind: action.kind,
          done: !action.done,
        );
  }

  Future<bool> _confirmDeleteAction(
    BuildContext context,
    GoalAction action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(
        title: 'Eliminar acción',
        message: '¿Quieres eliminar "${action.title}" del plan de acción?',
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteActionWithConfirm(
    BuildContext context,
    GoalAction action,
  ) async {
    final confirmed = await _confirmDeleteAction(context, action);
    if (!confirmed) return;
    await ref.read(goalActionRepositoryProvider).delete(action.id);
  }

  Future<void> _reorderActions(
    String goalId,
    List<GoalAction> visibleActions,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;
    final reordered = [...visibleActions];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await ref
        .read(goalActionRepositoryProvider)
        .reorder(goalId, reordered.map((a) => a.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncTriggerProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);
    final areasAsync = ref.watch(areasStreamProvider);
    final actionsAsync = ref.watch(goalActionsStreamProvider(widget.goalId));

    if (goalsAsync.hasError || areasAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meta')),
        body: const Center(
          child: Text(
            'No se pudo cargar la meta.',
            style: TextStyle(color: ForgeColors.negative),
          ),
        ),
      );
    }

    final goals = goalsAsync.value;
    final areas = areasAsync.value;
    if (goals == null || areas == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meta')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Goal? goal;
    for (final item in goals) {
      if (item.id == widget.goalId) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return const _GoalNotFoundScaffold();
    }

    Area? area;
    for (final item in areas) {
      if (item.id == goal.areaId) {
        area = item;
        break;
      }
    }

    final activeGoal = goal;
    final why = activeGoal.why?.trim();
    final isCompleted = activeGoal.status == GoalStatus.completed;

    final rawActions = actionsAsync.value;
    final visibleActions = rawActions
        ?.where((a) => !_dismissedActionIds.contains(a.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _openEditGoal(context, activeGoal),
            child: const Text('Editar'),
          ),
          PopupMenuButton<_GoalMenuAction>(
            tooltip: 'Opciones de meta',
            icon: const Icon(Icons.more_vert),
            color: ForgeColors.surfaceHigh,
            onSelected: (action) {
              switch (action) {
                case _GoalMenuAction.toggleStatus:
                  _toggleStatus(activeGoal);
                case _GoalMenuAction.delete:
                  _confirmAndDeleteGoal(context, activeGoal);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _GoalMenuAction.toggleStatus,
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.replay_outlined
                          : Icons.check_circle_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(isCompleted ? 'Reactivar' : 'Marcar cumplida'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _GoalMenuAction.delete,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: ForgeColors.negative,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Eliminar meta',
                      style: TextStyle(color: ForgeColors.negative),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GoalHeader(goal: activeGoal, area: area),
            const SizedBox(height: 16),
            _GoalMetricCard(
              goal: activeGoal,
              areaColor: parseForgeHexColor(area?.color ?? '#D4A373'),
              onUpdateMetric: () =>
                  _showUpdateMetricDialog(context, activeGoal),
            ),
            if (why != null && why.isNotEmpty) ...[
              const SizedBox(height: 24),
              _WhySection(why: why),
            ],
            const SizedBox(height: 24),
            _ActionPlanSection(
              actionsAsync: actionsAsync,
              visibleActions: visibleActions,
              onAddAction: () => _showAddActionDialog(context, activeGoal.id),
              onToggleDone: _toggleActionDone,
              onConfirmDelete: (action) =>
                  _confirmDeleteAction(context, action),
              onDismissed: (action) {
                setState(() => _dismissedActionIds.add(action.id));
                unawaited(
                  ref.read(goalActionRepositoryProvider).delete(action.id),
                );
              },
              onDeletePressed: (action) =>
                  _deleteActionWithConfirm(context, action),
              onReorder: (oldIndex, newIndex) {
                if (visibleActions == null) return;
                unawaited(
                  _reorderActions(
                    activeGoal.id,
                    visibleActions,
                    oldIndex,
                    newIndex,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalNotFoundScaffold extends StatelessWidget {
  const _GoalNotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meta')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 40,
                color: ForgeColors.onSurfaceMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Meta no encontrada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ForgeColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Es posible que haya sido eliminada.',
                style: TextStyle(
                  fontSize: 14,
                  color: ForgeColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: FilledButton(
                  onPressed: () {
                    final router = GoRouter.maybeOf(context);
                    if (router != null) {
                      router.go('/goals');
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Volver a metas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  const _GoalHeader({required this.goal, required this.area});

  final Goal goal;
  final Area? area;

  @override
  Widget build(BuildContext context) {
    final areaColor = parseForgeHexColor(area?.color ?? '#D4A373');
    final areaName = area?.name ?? 'Sin área';
    final isCompleted = goal.status == GoalStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ForgeColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: ForgeColors.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 5, backgroundColor: areaColor),
                  const SizedBox(width: 6),
                  Text(
                    areaName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ForgeColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            _GoalStatusBadge(isCompleted: isCompleted),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          goal.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ForgeColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
                    fontSize: 14,
                    color: ForgeColors.onSurfaceMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (goal.targetDate != null)
              Row(
                mainAxisSize: MainAxisSize.min,
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
                      fontSize: 14,
                      color: ForgeColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _GoalStatusBadge extends StatelessWidget {
  const _GoalStatusBadge({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? ForgeColors.positive : ForgeColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_outline : Icons.bolt_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted ? 'Meta cumplida' : 'Activa',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalMetricCard extends StatelessWidget {
  const _GoalMetricCard({
    required this.goal,
    required this.areaColor,
    required this.onUpdateMetric,
  });

  final Goal goal;
  final Color areaColor;
  final VoidCallback onUpdateMetric;

  @override
  Widget build(BuildContext context) {
    final isCompleted = goal.status == GoalStatus.completed;
    final accentColor = isCompleted ? ForgeColors.positive : areaColor;
    final ratio = goalProgressRatio(goal.metricCurrent, goal.metricTarget);
    final percent = goalProgressPercent(goal.metricCurrent, goal.metricTarget);
    final metricText =
        '${formatMetricNumber(goal.metricCurrent)} de '
        '${formatMetricNumber(goal.metricTarget)} ${goal.metricUnit}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metricText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ForgeColors.onSurface,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: ForgeColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: ForgeColors.surfaceHigh,
                foregroundColor: ForgeColors.onSurface,
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: onUpdateMetric,
              icon: const Icon(Icons.add, color: ForgeColors.primary),
              label: const Text('Registrar avance'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection({required this.why});

  final String why;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Por qué importa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ForgeColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.format_quote,
                size: 20,
                color: ForgeColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  why,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ForgeColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPlanSection extends StatelessWidget {
  const _ActionPlanSection({
    required this.actionsAsync,
    required this.visibleActions,
    required this.onAddAction,
    required this.onToggleDone,
    required this.onConfirmDelete,
    required this.onDismissed,
    required this.onDeletePressed,
    required this.onReorder,
  });

  final AsyncValue<List<GoalAction>> actionsAsync;
  final List<GoalAction>? visibleActions;
  final VoidCallback onAddAction;
  final ValueChanged<GoalAction> onToggleDone;
  final Future<bool> Function(GoalAction) onConfirmDelete;
  final ValueChanged<GoalAction> onDismissed;
  final ValueChanged<GoalAction> onDeletePressed;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Plan de acción',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ForgeColors.onSurface,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAddAction,
              icon: const Icon(Icons.add),
              label: const Text('Agregar acción'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (actionsAsync.hasError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No se pudo cargar el plan de acción.',
              style: TextStyle(color: ForgeColors.negative),
            ),
          )
        else if (visibleActions == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visibleActions!.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ForgeColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ForgeColors.outline),
            ),
            child: const Text(
              'Aún no hay acciones en este plan.',
              style: TextStyle(color: ForgeColors.onSurfaceMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: ForgeColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ForgeColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: visibleActions!.length,
              proxyDecorator: (child, index, animation) => Material(
                color: ForgeColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final action = visibleActions![index];
                return _ActionRow(
                  key: ValueKey(action.id),
                  index: index,
                  action: action,
                  showDivider: index < visibleActions!.length - 1,
                  onToggleDone: () => onToggleDone(action),
                  onConfirmDelete: () => onConfirmDelete(action),
                  onDismissed: () => onDismissed(action),
                  onDeletePressed: () => onDeletePressed(action),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.index,
    required this.action,
    required this.showDivider,
    required this.onToggleDone,
    required this.onConfirmDelete,
    required this.onDismissed,
    required this.onDeletePressed,
  });

  final int index;
  final GoalAction action;
  final bool showDivider;
  final VoidCallback onToggleDone;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onDismissed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Dismissible(
          key: ValueKey('dismiss-${action.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => onConfirmDelete(),
          onDismissed: (_) => onDismissed(),
          background: Container(
            color: ForgeColors.negative.withValues(alpha: 0.2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(
              Icons.delete_outline,
              color: ForgeColors.negative,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Checkbox(
                      value: action.done,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onChanged: (_) => onToggleDone(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: action.done
                            ? ForgeColors.onSurfaceMuted
                            : ForgeColors.onSurface,
                        decoration: action.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (action.kind == GoalActionKind.milestone) ...[
                    const SizedBox(width: 8),
                    const _MilestoneBadge(),
                  ],
                  IconButton(
                    tooltip: 'Eliminar acción',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: ForgeColors.onSurfaceMuted,
                    ),
                    onPressed: onDeletePressed,
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.drag_handle,
                        color: ForgeColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: ForgeColors.outline),
      ],
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ForgeColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Hito',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ForgeColors.primary,
        ),
      ),
    );
  }
}

class _UpdateMetricDialog extends StatefulWidget {
  const _UpdateMetricDialog({required this.goal});

  final Goal goal;

  @override
  State<_UpdateMetricDialog> createState() => _UpdateMetricDialogState();
}

class _UpdateMetricDialogState extends State<_UpdateMetricDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatMetricNumber(widget.goal.metricCurrent),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = parseGoalNumber(_controller.text);
    if (value == null || value < 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: const Text(
        'Registrar avance',
        style: TextStyle(color: ForgeColors.onSurface),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Avance actual (${widget.goal.metricUnit})',
          ),
          validator: (value) {
            final trimmed = (value ?? '').trim();
            if (trimmed.isEmpty) {
              return 'Ingresa un valor.';
            }
            final parsed = parseGoalNumber(trimmed);
            if (parsed == null || parsed < 0) {
              return 'Ingresa 0 o mayor.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: ForgeColors.onSurfaceMuted),
          ),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _AddActionDialog extends StatefulWidget {
  const _AddActionDialog();

  @override
  State<_AddActionDialog> createState() => _AddActionDialogState();
}

class _AddActionDialogState extends State<_AddActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  GoalActionKind _kind = GoalActionKind.task;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(
      context,
    ).pop((title: _titleController.text.trim(), kind: _kind));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: const Text(
        'Nueva acción',
        style: TextStyle(color: ForgeColors.onSurface),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Actualizar CV',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa un título.'
                  : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<GoalActionKind>(
              segments: const [
                ButtonSegment(value: GoalActionKind.task, label: Text('Tarea')),
                ButtonSegment(
                  value: GoalActionKind.milestone,
                  label: Text('Hito'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() => _kind = selection.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: ForgeColors.onSurfaceMuted),
          ),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: Text(title, style: const TextStyle(color: ForgeColors.onSurface)),
      content: Text(
        message,
        style: const TextStyle(color: ForgeColors.onSurfaceMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: ForgeColors.onSurfaceMuted),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ForgeColors.negative,
            foregroundColor: ForgeColors.onPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
