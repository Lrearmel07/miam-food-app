import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'courier_deliveries_screen.dart';
import 'courier_home_screen.dart';
import 'courier_profile_screen.dart';

class CourierShell extends StatefulWidget {
  const CourierShell({super.key});

  @override
  State<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends State<CourierShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      1 => const CourierDeliveriesScreen(),
      2 => const CourierProfileScreen(),
      _ => CourierHomeScreen(onAccepted: () => setState(() => _index = 1)),
    };

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: KeyedSubtree(key: ValueKey(_index), child: page),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                _CourierNavItem(
                  icon: Icons.explore_rounded,
                  label: 'Courses',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _CourierNavItem(
                  icon: Icons.delivery_dining_rounded,
                  label: 'Livraisons',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _CourierNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourierNavItem extends StatelessWidget {
  const _CourierNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: selected ? AppColors.blue : AppColors.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.blue : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
