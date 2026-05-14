import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';

class ChecklistArea {
  final String id;
  final String name;
  final String simpleName;
  final IconData icon;
  final Color color;
  final String description;

  const ChecklistArea({
    required this.id,
    required this.name,
    required this.simpleName,
    required this.icon,
    required this.color,
    required this.description,
  });

  factory ChecklistArea.fromJson(Map<String, dynamic> json) {
    final hexColor = json['color'] as String? ?? '#2F855A';
    return ChecklistArea(
      id: json['id'] as String,
      name: json['name'] as String,
      simpleName: json['name'] as String,
      icon: _getIconForArea(json['id'] as String),
      color: _parseHexColor(hexColor),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    'description': description,
  };

  static Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static IconData _getIconForArea(String id) {
    switch (id) {
      case 'agriculture': return Icons.agriculture;
      case 'livestock': return Icons.pets;
      case 'maintenance': return Icons.build;
      case 'daily': return Icons.wb_sunny;
      default: return Icons.category;
    }
  }

  static List<ChecklistArea> _cachedAreas = [];
  static void setAreas(List<ChecklistArea> areas) => _cachedAreas = areas;

  static List<ChecklistArea> getAreas() {
    if (_cachedAreas.isNotEmpty) return _cachedAreas;
    return [
      const ChecklistArea(
        id: 'agriculture',
        name: 'Agricultura',
        simpleName: 'Agricultura',
        icon: Icons.agriculture,
        color: AppColors.primaryGreen,
        description: 'Checklists de plantio, colheita e manejo',
      ),
      const ChecklistArea(
        id: 'livestock',
        name: 'Pecuária',
        simpleName: 'Pecuária',
        icon: Icons.pets,
        color: AppColors.secondaryOrange,
        description: 'Checklists de gado e animais',
      ),
      const ChecklistArea(
        id: 'maintenance',
        name: 'Manutenção',
        simpleName: 'Manutenção',
        icon: Icons.build,
        color: AppColors.accentBlue,
        description: 'Manutenção de equipamentos e instalações',
      ),
      const ChecklistArea(
        id: 'daily',
        name: 'Rotina Diária',
        simpleName: 'Rotina',
        icon: Icons.wb_sunny,
        color: AppColors.accentYellow,
        description: 'Tarefas do dia a dia',
      ),
    ];
  }
}
