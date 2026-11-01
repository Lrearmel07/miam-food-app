import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_restaurants_screen.dart';
import 'admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      1 => const AdminOrdersScreen(),
      2 => const AdminUsersScreen(),
      3 => const AdminRestaurantsScreen(),
      4 => const AdminProfileScreen(),
      _ => AdminDashboardScreen(
        onOpenOrders: () => _go(1),
        onOpenUsers: () => _go(2),
      ),
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
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Row(
              children: [
                _AdminNavItem(
                  key: const ValueKey('admin-nav-dashboard'),
                  icon: Icons.space_dashboard_rounded,
                  label: 'Pilotage',
                  selected: _index == 0,
                  onTap: () => _go(0),
                ),
                _AdminNavItem(
                  key: const ValueKey('admin-nav-orders'),
                  icon: Icons.receipt_long_rounded,
                  label: 'Commandes',
                  selected: _index == 1,
                  onTap: () => _go(1),
                ),
                _AdminNavItem(
                  key: const ValueKey('admin-nav-users'),
                  icon: Icons.people_alt_rounded,
                  label: 'Users',
                  selected: _index == 2,
                  onTap: () => _go(2),
                ),
                _AdminNavItem(
                  key: const ValueKey('admin-nav-restaurants'),
                  icon: Icons.storefront_rounded,
                  label: 'Restos',
                  selected: _index == 3,
                  onTap: () => _go(3),
                ),
                _AdminNavItem(
                  key: const ValueKey('admin-nav-profile'),
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  selected: _index == 4,
                  onTap: () => _go(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    super.key,
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.ink.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
