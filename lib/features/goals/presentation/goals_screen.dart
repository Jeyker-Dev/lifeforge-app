import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/sync/providers.dart';
import '../../areas/domain/area.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/goal.dart';
import 'goal_card.dart';
import 'new_goal_screen.dart';

/// Goals screen displaying goals grouped by area with area filter chips.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  String? _selectedAreaId;

  Future<void> _openNewGoal(BuildContext context, String? initialAreaId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => NewGoalScreen(initialAreaId: initialAreaId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncTriggerProvider);
    final areasAsync = ref.watch(areasStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);

    final activeAreas = areasAsync.value ?? const <Area>[];
    final effectiveSelectedAreaId =
        activeAreas.any((a) => a.id == _selectedAreaId)
        ? _selectedAreaId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: _buildBody(
        context,
        areasAsync: areasAsync,
        goalsAsync: goalsAsync,
        selectedAreaId: effectiveSelectedAreaId,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ForgeColors.primary,
        foregroundColor: ForgeColors.onPrimary,
        onPressed: () => _openNewGoal(context, effectiveSelectedAreaId),
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<List<Area>> areasAsync,
    required AsyncValue<List<Goal>> goalsAsync,
    required String? selectedAreaId,
  }) {
    if (areasAsync.hasError || goalsAsync.hasError) {
      return const Center(
        child: Text(
          'No se pudieron cargar las metas.',
          style: TextStyle(color: ForgeColors.negative),
        ),
      );
    }
    final areas = areasAsync.value;
    final goals = goalsAsync.value;
    if (areas == null || goals == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeCount = goals
        .where((g) => g.status == GoalStatus.active)
        .length;
    final countLabel = activeCount == 1
        ? '1 meta activa'
        : '$activeCount metas activas';

    if (goals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActiveGoalsHeader(countLabel: countLabel),
          Expanded(
            child: _EmptyGoalsState(
              message: 'Aún no tienes metas',
              subtitle: 'Define a qué quieres dedicar tus horas.',
              onCreate: () => _openNewGoal(context, selectedAreaId),
            ),
          ),
        ],
      );
    }

    final filteredGoals = selectedAreaId == null
        ? goals
        : goals.where((g) => g.areaId == selectedAreaId).toList();

    final grouped = <(Area, List<Goal>)>[];
    for (final area in areas) {
      final areaGoals = filteredGoals
          .where((g) => g.areaId == area.id)
          .toList();
      if (areaGoals.isNotEmpty) {
        grouped.add((area, areaGoals));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActiveGoalsHeader(countLabel: countLabel),
        _AreaFilterChips(
          areas: areas,
          selectedAreaId: selectedAreaId,
          onSelect: (id) => setState(() => _selectedAreaId = id),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: grouped.isEmpty
              ? _EmptyGoalsState(
                  message: 'No hay metas en esta área',
                  subtitle: 'Crea una meta para empezar a avanzar aquí.',
                  onCreate: () => _openNewGoal(context, selectedAreaId),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final (area, areaGoals) = grouped[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == grouped.length - 1 ? 0 : 20,
                      ),
                      child: _AreaGoalsSection(area: area, goals: areaGoals),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActiveGoalsHeader extends StatelessWidget {
  const _ActiveGoalsHeader({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        countLabel,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ForgeColors.onSurfaceMuted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AreaFilterChips extends StatelessWidget {
  const _AreaFilterChips({
    required this.areas,
    required this.selectedAreaId,
    required this.onSelect,
  });

  final List<Area> areas;
  final String? selectedAreaId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: selectedAreaId == null,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            shape: const StadiumBorder(),
            selectedColor: ForgeColors.primary,
            backgroundColor: ForgeColors.surface,
            side: BorderSide(
              color: selectedAreaId == null
                  ? ForgeColors.primary
                  : ForgeColors.outline,
            ),
            labelStyle: TextStyle(
              color: selectedAreaId == null
                  ? ForgeColors.onPrimary
                  : ForgeColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => onSelect(null),
          ),
          for (final area in areas) ...[
            const SizedBox(width: 8),
            _AreaChip(
              area: area,
              selected: selectedAreaId == area.id,
              onSelected: () => onSelect(area.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.area,
    required this.selected,
    required this.onSelected,
  });

  final Area area;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final areaColor = parseForgeHexColor(area.color);
    return ChoiceChip(
      avatar: CircleAvatar(radius: 5, backgroundColor: areaColor),
      label: Text(area.name),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      selectedColor: areaColor.withValues(alpha: 0.22),
      backgroundColor: ForgeColors.surface,
      side: BorderSide(color: selected ? areaColor : ForgeColors.outline),
      labelStyle: TextStyle(
        color: ForgeColors.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _AreaGoalsSection extends StatelessWidget {
  const _AreaGoalsSection({required this.area, required this.goals});

  final Area area;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final areaColor = parseForgeHexColor(area.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 5, backgroundColor: areaColor),
            const SizedBox(width: 8),
            Text(
              area.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: ForgeColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < goals.length; i++) ...[
          GoalCard(goal: goals[i], area: area),
          if (i < goals.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EmptyGoalsState extends StatelessWidget {
  const _EmptyGoalsState({
    required this.message,
    required this.subtitle,
    required this.onCreate,
  });

  final String message;
  final String subtitle;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ForgeColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: ForgeColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Crear meta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
