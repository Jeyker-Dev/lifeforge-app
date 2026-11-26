import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/sync/providers.dart';
import '../../areas/domain/area.dart';
import '../../areas/domain/area_defaults.dart';
import '../../auth/presentation/auth_controller.dart';

/// Default area color used by the Phase 0 quick-create dialog.
const _defaultAreaColor = '#E07A5F';

enum _AreaAction { rename, changeColor, delete }

/// Home screen listing life areas and their sync status.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncTriggerProvider);
    final areasAsync = ref.watch(areasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoy'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: areasAsync.when(
        data: (areas) => _AreasList(
          areas: areas,
          onAction: (area, action) =>
              _handleAreaAction(context, ref, area, action),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: Text(
            'No se pudieron cargar las áreas.',
            style: TextStyle(color: ForgeColors.negative),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva área',
        backgroundColor: ForgeColors.primary,
        foregroundColor: ForgeColors.onPrimary,
        onPressed: () => _showCreateAreaDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateAreaDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          const _AreaNameDialog(title: 'Nueva área', submitLabel: 'Crear'),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(areaRepositoryProvider)
        .create(name: name.trim(), color: _defaultAreaColor);
  }

  Future<void> _handleAreaAction(
    BuildContext context,
    WidgetRef ref,
    Area area,
    _AreaAction action,
  ) async {
    switch (action) {
      case _AreaAction.rename:
        final updatedName = await showDialog<String>(
          context: context,
          builder: (context) => _AreaNameDialog(
            title: 'Renombrar área',
            submitLabel: 'Guardar',
            initialName: area.name,
          ),
        );
        if (updatedName == null || updatedName == area.name) return;
        await ref
            .read(areaRepositoryProvider)
            .rename(id: area.id, name: updatedName);
      case _AreaAction.changeColor:
        final updatedColor = await showDialog<String>(
          context: context,
          builder: (context) =>
              _ChangeColorDialog(areaName: area.name, initialColor: area.color),
        );
        if (updatedColor == null ||
            updatedColor.toUpperCase() == area.color.toUpperCase()) {
          return;
        }
        await ref
            .read(areaRepositoryProvider)
            .changeColor(id: area.id, color: updatedColor);
      case _AreaAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _DeleteAreaDialog(areaName: area.name),
        );
        if (confirmed != true) return;
        await ref.read(areaRepositoryProvider).delete(area.id);
    }
  }
}

class _AreasList extends StatelessWidget {
  const _AreasList({required this.areas, required this.onAction});

  final List<Area> areas;
  final void Function(Area area, _AreaAction action) onAction;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return const Center(
        child: Text(
          'Tu día se forja aquí.',
          style: TextStyle(color: ForgeColors.onSurfaceMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: areas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final area = areas[index];
        return Container(
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 8,
              backgroundColor: parseForgeHexColor(area.color),
            ),
            title: Text(
              area.name,
              style: const TextStyle(color: ForgeColors.onSurface),
            ),
            subtitle: area.pendingSync
                ? const Text(
                    'pendiente de sincronizar',
                    style: TextStyle(color: ForgeColors.warning),
                  )
                : null,
            trailing: PopupMenuButton<_AreaAction>(
              tooltip: 'Opciones de ${area.name}',
              icon: const Icon(
                Icons.more_vert,
                color: ForgeColors.onSurfaceMuted,
              ),
              color: ForgeColors.surfaceHigh,
              onSelected: (action) => onAction(area, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AreaAction.rename,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Renombrar'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _AreaAction.changeColor,
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Cambiar color'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _AreaAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: ForgeColors.negative,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: ForgeColors.negative),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AreaNameDialog extends StatefulWidget {
  const _AreaNameDialog({
    required this.title,
    required this.submitLabel,
    this.initialName = '',
  });

  final String title;
  final String submitLabel;
  final String initialName;

  @override
  State<_AreaNameDialog> createState() => _AreaNameDialogState();
}

class _AreaNameDialogState extends State<_AreaNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: Text(
        widget.title,
        style: const TextStyle(color: ForgeColors.onSurface),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: ForgeColors.onSurfaceMuted),
          ),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

class _ChangeColorDialog extends StatefulWidget {
  const _ChangeColorDialog({
    required this.areaName,
    required this.initialColor,
  });

  final String areaName;
  final String initialColor;

  @override
  State<_ChangeColorDialog> createState() => _ChangeColorDialogState();
}

class _ChangeColorDialogState extends State<_ChangeColorDialog> {
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: Text(
        'Color de ${widget.areaName}',
        style: const TextStyle(color: ForgeColors.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in areaColorOptions)
              ListTile(
                key: ValueKey('area-color-${option.hex}'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: parseForgeHexColor(option.hex),
                ),
                title: Text(
                  option.label,
                  style: const TextStyle(color: ForgeColors.onSurface),
                ),
                trailing: _selectedColor == option.hex.toUpperCase()
                    ? const Icon(Icons.check, color: ForgeColors.primary)
                    : null,
                onTap: () => setState(() {
                  _selectedColor = option.hex.toUpperCase();
                }),
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DeleteAreaDialog extends StatelessWidget {
  const _DeleteAreaDialog({required this.areaName});

  final String areaName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surfaceHigh,
      title: const Text(
        'Eliminar área',
        style: TextStyle(color: ForgeColors.onSurface),
      ),
      content: Text(
        '¿Quieres eliminar "$areaName"? Dejará de aparecer en tu lista.',
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
