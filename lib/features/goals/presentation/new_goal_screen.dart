import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/sync/providers.dart';
import '../../areas/domain/area.dart';
import 'goal_formatting.dart';

/// Full-screen form to create a new goal.
class NewGoalScreen extends ConsumerStatefulWidget {
  const NewGoalScreen({super.key, this.initialAreaId});

  final String? initialAreaId;

  @override
  ConsumerState<NewGoalScreen> createState() => _NewGoalScreenState();
}

class _NewGoalScreenState extends ConsumerState<NewGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _whyController = TextEditingController();
  final _currentController = TextEditingController(text: '0');
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _hoursController = TextEditingController();

  String? _selectedAreaId;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedAreaId = widget.initialAreaId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _whyController.dispose();
    _currentController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  double? _parseNumber(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 25),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final areaId = _selectedAreaId;
    if (areaId == null) return;

    setState(() => _saving = true);
    try {
      final why = _whyController.text.trim();
      await ref
          .read(goalRepositoryProvider)
          .upsert(
            areaId: areaId,
            title: _titleController.text.trim(),
            why: why.isEmpty ? null : why,
            targetDate: _targetDate,
            metricCurrent: _parseNumber(_currentController.text) ?? 0,
            metricTarget: _parseNumber(_targetController.text)!,
            metricUnit: _unitController.text.trim(),
            weeklyHoursTarget: _parseNumber(_hoursController.text)!,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasStreamProvider).value ?? const <Area>[];
    final validAreaId = areas.any((a) => a.id == _selectedAreaId)
        ? _selectedAreaId
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva meta')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: validAreaId,
                dropdownColor: ForgeColors.surfaceHigh,
                decoration: const InputDecoration(labelText: 'Área'),
                hint: Text(
                  areas.isEmpty
                      ? 'Primero crea un área en Hoy'
                      : 'Selecciona un área',
                ),
                items: [
                  for (final area in areas)
                    DropdownMenuItem(
                      value: area.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: parseForgeHexColor(area.color),
                          ),
                          const SizedBox(width: 8),
                          Text(area.name),
                        ],
                      ),
                    ),
                ],
                onChanged: areas.isEmpty
                    ? null
                    : (value) => setState(() => _selectedAreaId = value),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Elige un área.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej. Conseguir trabajo',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un título.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whyController,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Por qué importa (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              _DatePickerField(
                targetDate: _targetDate,
                onPick: _pickDate,
                onClear: () => setState(() => _targetDate = null),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _currentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Avance actual',
                      ),
                      validator: (value) {
                        final parsed = _parseNumber(value ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Ingresa 0 o mayor.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Objetivo numérico',
                        hintText: 'Ej. 10',
                      ),
                      validator: (value) {
                        final parsed = _parseNumber(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Debe ser mayor que 0.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Unidad',
                  hintText: 'Ej. entrevistas, km, páginas',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa una unidad.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Horas por semana',
                  hintText: 'Ej. 6',
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) {
                    return 'Ingresa las horas semanales.';
                  }
                  final parsed = _parseNumber(trimmed);
                  if (parsed == null || parsed < 0) {
                    return 'Debe ser 0 o mayor.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: const Text('Guardar meta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.targetDate,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? targetDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPick,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha objetivo (opcional)',
            suffixIcon: targetDate == null
                ? const Icon(Icons.event_outlined)
                : IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
          ),
          child: Text(
            targetDate == null
                ? 'Sin fecha'
                : formatGoalTargetDate(targetDate!),
            style: TextStyle(
              color: targetDate == null
                  ? ForgeColors.onSurfaceMuted
                  : ForgeColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
