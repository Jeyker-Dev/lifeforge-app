/// A selectable area color from the Forja cálida palette.
class AreaColorOption {
  const AreaColorOption({required this.hex, required this.label});

  final String hex;
  final String label;
}

/// The five area colors defined in `docs/areas/stitch-design.md`.
const List<AreaColorOption> areaColorOptions = [
  AreaColorOption(hex: '#E07A5F', label: 'Terracota'),
  AreaColorOption(hex: '#D4A373', label: 'Arena'),
  AreaColorOption(hex: '#81B29A', label: 'Salvia'),
  AreaColorOption(hex: '#D98C9B', label: 'Rosa'),
  AreaColorOption(hex: '#A88BD9', label: 'Lavanda'),
];

/// A default life area seeded when a user starts with zero areas (A3).
class DefaultAreaSpec {
  const DefaultAreaSpec({required this.name, required this.color});

  final String name;
  final String color;
}

/// Default life areas in display order (positions 0–4).
const List<DefaultAreaSpec> defaultLifeAreas = [
  DefaultAreaSpec(name: 'Salud', color: '#E07A5F'),
  DefaultAreaSpec(name: 'Carrera', color: '#D4A373'),
  DefaultAreaSpec(name: 'Finanzas', color: '#81B29A'),
  DefaultAreaSpec(name: 'Relaciones', color: '#D98C9B'),
  DefaultAreaSpec(name: 'Ocio', color: '#A88BD9'),
];
