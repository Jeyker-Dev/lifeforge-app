import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/sync/providers.dart';
import '../../areas/domain/area.dart';
import '../../auth/presentation/auth_controller.dart';

/// Default area color used by the Phase 0 quick-create dialog.
const _defaultAreaColor = '#E07A5F';

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
        data: (areas) => _AreasList(areas: areas),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'No se pudieron cargar las áreas.',
            style: const TextStyle(color: ForgeColors.negative),
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
      builder: (context) => const _CreateAreaDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(areaRepositoryProvider)
        .create(name: name.trim(), color: _defaultAreaColor);
  }
}

class _AreasList extends StatelessWidget {
  const _AreasList({required this.areas});

  final List<Area> areas;

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
              backgroundColor: _parseHexColor(area.color),
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
          ),
        );
      },
    );
  }

  Color _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null || cleaned.length != 6) {
      return ForgeColors.areaHealth;
    }
    return Color(0xFF000000 | value);
  }
}

class _CreateAreaDialog extends StatefulWidget {
  const _CreateAreaDialog();

  @override
  State<_CreateAreaDialog> createState() => _CreateAreaDialogState();
}

class _CreateAreaDialogState extends State<_CreateAreaDialog> {
  final _controller = TextEditingController();

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
      title: const Text(
        'Nueva área',
        style: TextStyle(color: ForgeColors.onSurface),
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
        FilledButton(onPressed: _submit, child: const Text('Crear')),
      ],
    );
  }
}
