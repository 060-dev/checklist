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

  static List<ChecklistArea> getAreas() => [
    ChecklistArea(
      id: 'agriculture',
      name: 'Agricultura',
      simpleName: 'Agricultura',
      icon: Icons.agriculture,
      color: AppColors.primaryGreen,
      description: 'Checklists de plantio, colheita e manejo',
    ),
    ChecklistArea(
      id: 'livestock',
      name: 'Pecuária',
      simpleName: 'Pecuária',
      icon: Icons.pets,
      color: AppColors.secondaryOrange,
      description: 'Checklists de gado e animais',
    ),
    ChecklistArea(
      id: 'maintenance',
      name: 'Manutenção',
      simpleName: 'Manutenção',
      icon: Icons.build,
      color: AppColors.accentBlue,
      description: 'Manutenção de equipamentos e instalações',
    ),
    ChecklistArea(
      id: 'daily',
      name: 'Rotina Diária',
      simpleName: 'Rotina',
      icon: Icons.wb_sunny,
      color: AppColors.accentYellow,
      description: 'Tarefas do dia a dia',
    ),
  ];
}
